
class SensorReading {
  final double? dustDensity;
  final double? mq4;
  final double? mq9;
  final double? mq135;
  final double? mg811Value;
  final double? sound;
  final double? humidity;
  final double? tempC;
  final String? sdStatus;

  SensorReading({
    this.dustDensity,
    this.mq4,
    this.mq9,
    this.mq135,
    this.mg811Value,
    this.sound,
    this.humidity,
    this.tempC,
    this.sdStatus,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse doubles from various types (int, double, string)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return SensorReading(
      dustDensity: parseDouble(json['dustDensity']),
      mq4: parseDouble(json['mq4']),
      mq9: parseDouble(json['mq9']),
      mq135: parseDouble(json['mq135']),
      mg811Value: parseDouble(json['mg811Value']),
      sound: parseDouble(json['sound']),
      humidity: parseDouble(json['humidity']),
      tempC: parseDouble(json['tempC']),
      sdStatus: json['sdStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dustDensity': dustDensity,
      'mq4': mq4,
      'mq9': mq9,
      'mq135': mq135,
      'mg811Value': mg811Value,
      'sound': sound,
      'humidity': humidity,
      'tempC': tempC,
      'sdStatus': sdStatus,
    };
  }

  // Get raw value by key
  double? getValueByKey(String key) {
    switch (key) {
      case 'dustDensity': return dustDensity;
      case 'mq4': return mq4;
      case 'mq9': return mq9;
      case 'mq135': return mq135;
      case 'mg811Value': return mg811Value;
      case 'sound': return sound;
      case 'humidity': return humidity;
      case 'tempC': return tempC;
      default: return null;
    }
  }
}
