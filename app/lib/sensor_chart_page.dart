import 'dart:async';
import 'constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'models/sensor_reading.dart';

class SensorChartPage extends StatefulWidget {
  final String sensorName;
  final String sensorKey;
  final List<double> initialValues;
  final Stream<SensorReading> dataStream; // Updated type

  const SensorChartPage({
    super.key,
    required this.sensorName,
    required this.sensorKey,
    required this.initialValues,
    required this.dataStream,
  });

  @override
  State<SensorChartPage> createState() => _SensorChartPageState();
}

class _SensorChartPageState extends State<SensorChartPage> {
  late List<FlSpot> chartData;
  late List<double> valueHistory;
  final int maxHistoryLength = 30;
  StreamSubscription<SensorReading>? _dataSubscription;

  // Track latest value for display
  double? _latestValue;

  @override
  void initState() {
    super.initState();
    valueHistory = List.from(widget.initialValues);
    if (valueHistory.isNotEmpty) {
      _latestValue = valueHistory.last;
    }
    
    _trimHistory();
    chartData = _generateSpots(valueHistory);

    _dataSubscription = widget.dataStream.listen((reading) {
      // Use the helper method on SensorReading
      double? newVal = reading.getValueByKey(widget.sensorKey);
      if (newVal != null) {
        _updateChart(newVal);
      }
    });
  }

  void _trimHistory() {
    if (valueHistory.length > maxHistoryLength) {
      valueHistory = valueHistory.sublist(valueHistory.length - maxHistoryLength);
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  List<FlSpot> _generateSpots(List<double> values) {
    return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
  }

  void _updateChart(double newValue) {
    if (!mounted) return;
    setState(() {
      if (valueHistory.length >= maxHistoryLength) {
        valueHistory.removeAt(0);
      }
      valueHistory.add(newValue);
      _latestValue = newValue;
      chartData = _generateSpots(valueHistory);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    double minVal = valueHistory.isEmpty ? 0 : valueHistory.reduce((a, b) => a < b ? a : b);
    double maxVal = valueHistory.isEmpty ? 100 : valueHistory.reduce((a, b) => a > b ? a : b);
    double avgVal = valueHistory.isEmpty ? 0 : valueHistory.reduce((a, b) => a + b) / valueHistory.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.sensorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kAppPurple.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kDarkBackground, Color(0xFF2C2C2C)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 110, 16, 16),
        child: Column(
          children: [
            // Current Value Card
            _buildCurrentValueCard(),
            const SizedBox(height: 16),
            
            // Chart Container
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.only(right: 16, left: 0, top: 24, bottom: 12),
                decoration: BoxDecoration(
                  color: kCardBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: LineChart(
                  _mainData(minVal, maxVal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Statistics Grid (Min/Max/Avg)
            Row(
              children: [
                Expanded(child: _buildStatCard("Min", minVal.toStringAsFixed(1), Colors.blueAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Avg", avgVal.toStringAsFixed(1), Colors.orangeAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Max", maxVal.toStringAsFixed(1), Colors.redAccent)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentValueCard() {
     return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAppPurple.withValues(alpha: 0.2),
            kCardBackground,
          ],
        ),
        border: Border.all(color: kAppPurple.withValues(alpha: 0.3)),
        boxShadow: [
           BoxShadow(color: kAppPurple.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
           Text(
            "Current Reading",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _latestValue?.toStringAsFixed(1) ?? "--",
            style: const TextStyle(
              fontSize: 48, 
              fontWeight: FontWeight.bold, 
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  LineChartData _mainData(double minVal, double maxVal) {
    double yMin = minVal - (minVal * 0.1); // Add padding
    double yMax = maxVal + (maxVal * 0.1); 
    if (yMin < 0) yMin = 0;
    
    // Safety check if min == max
    if (yMin == yMax) {
      yMax += 10;
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (yMax - yMin) / 5,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            reservedSize: 35,
            interval: (yMax - yMin) / 5,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (maxHistoryLength - 1).toDouble(),
      minY: yMin,
      maxY: yMax,
      lineBarsData: [
        LineChartBarData(
          spots: chartData,
          isCurved: true,
          gradient: const LinearGradient(
            colors: [kAppPurpleLight, kAppPurple],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                kAppPurple.withValues(alpha: 0.3),
                kAppPurple.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
