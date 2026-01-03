import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/sensor_reading.dart';
import 'services/api_service.dart';
import 'sensor_chart_page.dart';
import 'constants.dart';
import 'about_page.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air360',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAppPurple,
          brightness: Brightness.dark,
          surface: kCardBackground,
          // Removed background as it is deprecated in newer Flutter versions, using canvasColor/scaffoldBackgroundColor instead
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: kDarkBackground,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SensorDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SensorDashboard extends StatefulWidget {
  const SensorDashboard({super.key});

  @override
  State<SensorDashboard> createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  final ApiService _apiService = ApiService();
  final Queue<SensorReading> _sensorHistory = ListQueue();
  Timer? _timer;
  bool _isFetching = false;

  // Current state
  SensorReading? _latestReading;

  // Stream for chart page - Now typed as SensorReading
  final _sensorDataStreamController =
      StreamController<SensorReading>.broadcast();

  // Sensor definitions
  final List<Map<String, dynamic>> _sensors = [
    {
      'name': 'Dust Level',
      'unit': 'mg/m³',
      'key': 'dustDensity',
      'icon': Icons.grain,
    },
    {
      'name': 'CH₄ Level',
      'unit': 'ppm',
      'key': 'mq4',
      'icon': Icons.local_fire_department,
    },
    {'name': 'CO Level', 'unit': 'ppm', 'key': 'mq9', 'icon': Icons.cloud},
    {
      'name': 'SOx/NOx Level',
      'unit': 'AQI',
      'key': 'mq135',
      'icon': Icons.science,
    },
    {'name': 'CO₂ Level', 'unit': '', 'key': 'mg811Value', 'icon': Icons.co2},
    {
      'name': 'Noise Level',
      'unit': 'dB',
      'key': 'sound',
      'icon': Icons.volume_up,
    },
    {
      'name': 'Humidity',
      'unit': '%',
      'key': 'humidity',
      'icon': Icons.water_drop,
    },
    {
      'name': 'Temperature',
      'unit': '°C',
      'key': 'tempC',
      'icon': Icons.thermostat,
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchData());
    _fetchData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorDataStreamController.close();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final reading = await _apiService.fetchSensorData();

      setState(() {
        _latestReading = reading;

        _sensorHistory.addLast(reading);
        if (_sensorHistory.length > 100) _sensorHistory.removeFirst();

        _sensorDataStreamController.add(reading);
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      } else {
        _isFetching = false;
      }
    }
  }

  // Get history as doubles for a specific key
  List<double> _getHistoryValues(String key) {
    return _sensorHistory.map((r) => r.getValueByKey(key) ?? 0.0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sdStatus = _latestReading?.sdStatus ?? "Unknown";
    final sdColor = sdStatus == "Inserted"
        ? Colors.greenAccent
        : Colors.redAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Air360 Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        excludeHeaderSemantics: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kAppPurple.withValues(alpha: 0.9), Colors.transparent],
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
        padding: const EdgeInsets.fromLTRB(
          16,
          120,
          16,
          16,
        ), // Top padding for extended AppBar
        child: Column(
          children: [
            // Status Indicators
            _buildStatusHeader(sdStatus, sdColor),
            const SizedBox(height: 16),

            // Grid
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                ),
                itemCount: _sensors.length,
                itemBuilder: (context, index) {
                  final sensor = _sensors[index];
                  final valDouble = _latestReading?.getValueByKey(
                    sensor['key'],
                  );
                  final valueStr = valDouble?.toStringAsFixed(1) ?? '--';

                  return _buildSensorCard(
                    name: sensor['name'],
                    value: valueStr,
                    unit: sensor['unit'],
                    icon: sensor['icon'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SensorChartPage(
                            sensorName: sensor['name'],
                            sensorKey: sensor['key'],
                            initialValues: _getHistoryValues(sensor['key']),
                            dataStream: _sensorDataStreamController.stream,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.sd_storage_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                "SD Card: $status",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_isFetching)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kAppPurpleLight,
              ),
            )
          else
            const Icon(Icons.cloud_done, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required String name,
    required String value,
    required String unit,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: kAppPurple.withValues(alpha: 0.2),
        highlightColor: kAppPurple.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            color: kCardBackground.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kAppPurple.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: kAppPurpleLight, size: 22),
                    ),
                    IndicatorLight(isActive: value != '--'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: value,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          TextSpan(
                            text: unit.isNotEmpty ? ' $unit' : '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IndicatorLight extends StatelessWidget {
  final bool isActive;
  const IndicatorLight({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00E676) : Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isActive ? const Color(0xFF00E676) : Colors.red).withValues(
              alpha: 0.4,
            ),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
