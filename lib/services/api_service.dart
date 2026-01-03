import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client = http.Client();

  // Default to the ESP8266 AP IP logic
  ApiService({this.baseUrl = 'http://192.168.4.1/data'});

  Future<SensorReading> fetchSensorData() async {
    try {
      final response = await _client
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        return SensorReading.fromJson(decoded);
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }
}
