import 'package:intl/intl.dart';

class WeatherData {
  final double temperature;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final String weatherCode;
  final DateTime time;
  final double? soilMoisture;
  final double? soilTemperature;
  final double? airQualityIndex;
  final double? solarRadiation;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
    required this.time,
    this.soilMoisture,
    this.soilTemperature,
    this.airQualityIndex,
    this.solarRadiation,
  });

  factory WeatherData.fromOpenMeteo(Map<String, dynamic> data, DateTime time) {
    return WeatherData(
      temperature: data['temperature_2m']?.toDouble() ?? 0.0,
      humidity: data['relative_humidity_2m']?.toDouble() ?? 0.0,
      precipitation: data['precipitation']?.toDouble() ?? 0.0,
      windSpeed: data['wind_speed_10m']?.toDouble() ?? 0.0,
      weatherCode: data['weather_code']?.toString() ?? '0',
      time: time,
    );
  }

  factory WeatherData.fromNASAPower(Map<String, dynamic> data, DateTime date) {
    return WeatherData(
      temperature: data['T2M']?.toDouble() ?? 0.0,
      humidity: data['RH2M']?.toDouble() ?? 0.0,
      precipitation: data['PRECTOTCORR']?.toDouble() ?? 0.0,
      windSpeed: data['WS2M']?.toDouble() ?? 0.0,
      weatherCode: '0',
      time: date,
      soilMoisture: data['GWETROOT'] != null ? data['GWETROOT'].toDouble() * 100 : null,
      soilTemperature: data['TS']?.toDouble() ?? 0.0,
      solarRadiation: data['ALLSKY_SFC_SW_DWN']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'precipitation': precipitation,
      'windSpeed': windSpeed,
      'weatherCode': weatherCode,
      'time': time.toIso8601String(),
      'soilMoisture': soilMoisture,
      'soilTemperature': soilTemperature,
      'airQualityIndex': airQualityIndex,
      'solarRadiation': solarRadiation,
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      humidity: json['humidity']?.toDouble() ?? 0.0,
      precipitation: json['precipitation']?.toDouble() ?? 0.0,
      windSpeed: json['windSpeed']?.toDouble() ?? 0.0,
      weatherCode: json['weatherCode'] ?? '0',
      time: DateTime.parse(json['time']),
      soilMoisture: json['soilMoisture']?.toDouble(),
      soilTemperature: json['soilTemperature']?.toDouble(),
      airQualityIndex: json['airQualityIndex']?.toDouble(),
      solarRadiation: json['solarRadiation']?.toDouble(),
    );
  }

  String formattedDate() {
    return DateFormat('EEE, MMM d').format(time);
  }

  String formattedTime() {
    return DateFormat('h:mm a').format(time);
  }
}

class CropRequirement {
  final String name;
  final String scientificName;
  final double minTemp;
  final double maxTemp;
  final double minRainfall;
  final double maxRainfall;
  final double optimalSoilMoisture;
  final double optimalSoilTemp;
  final double optimalSolarRadiation;
  final List<String> soilTypes;
  final int growthDays;
  final String season;
  final double waterRequirement;
  final List<String> nutrients;
  final String? faoCategory;

  CropRequirement({
    required this.name,
    required this.scientificName,
    required this.minTemp,
    required this.maxTemp,
    required this.minRainfall,
    required this.maxRainfall,
    required this.optimalSoilMoisture,
    required this.optimalSoilTemp,
    required this.optimalSolarRadiation,
    required this.soilTypes,
    required this.growthDays,
    required this.season,
    required this.waterRequirement,
    required this.nutrients,
    this.faoCategory
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientificName': scientificName,
      'minTemp': minTemp,
      'maxTemp': maxTemp,
      'minRainfall': minRainfall,
      'maxRainfall': maxRainfall,
      'optimalSoilMoisture': optimalSoilMoisture,
      'optimalSoilTemp': optimalSoilTemp,
      'optimalSolarRadiation': optimalSolarRadiation,
      'soilTypes': soilTypes,
      'growthDays': growthDays,
      'season': season,
      'waterRequirement': waterRequirement,
      'nutrients': nutrients,
      'faoCategory': faoCategory,
    };
  }

  factory CropRequirement.fromJson(Map<String, dynamic> json) {
    return CropRequirement(
      name: json['name'],
      scientificName: json['scientificName'],
      minTemp: json['minTemp']?.toDouble() ?? 0.0,
      maxTemp: json['maxTemp']?.toDouble() ?? 0.0,
      minRainfall: json['minRainfall']?.toDouble() ?? 0.0,
      maxRainfall: json['maxRainfall']?.toDouble() ?? 0.0,
      optimalSoilMoisture: json['optimalSoilMoisture']?.toDouble() ?? 0.0,
      optimalSoilTemp: json['optimalSoilTemp']?.toDouble() ?? 0.0,
      optimalSolarRadiation: json['optimalSolarRadiation']?.toDouble() ?? 0.0,
      soilTypes: List<String>.from(json['soilTypes'] ?? []),
      growthDays: json['growthDays'] ?? 0,
      season: json['season'],
      waterRequirement: json['waterRequirement']?.toDouble() ?? 0.0,
      nutrients: List<String>.from(json['nutrients'] ?? []),
      faoCategory: json['faoCategory'],
    );
  }

  String getWaterRequirementText() {
    if (waterRequirement < 500) return 'Low';
    if (waterRequirement < 1000) return 'Moderate';
    if (waterRequirement < 2000) return 'High';
    return 'Very High';
  }
}

class Advisory {
  final String title;
  final String message;
  final AdvisoryType type;
  final DateTime issuedAt;
  final DateTime? validUntil;
  final List<String> affectedCrops;
  final SeverityLevel severity;

  Advisory({
    required this.title,
    required this.message,
    required this.type,
    required this.issuedAt,
    this.validUntil,
    this.affectedCrops = const [],
    this.severity = SeverityLevel.info,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'type': type.toString(),
      'issuedAt': issuedAt.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'affectedCrops': affectedCrops,
      'severity': severity.toString(),
    };
  }

  factory Advisory.fromJson(Map<String, dynamic> json) {
    return Advisory(
      title: json['title'],
      message: json['message'],
      type: AdvisoryType.values.firstWhere(
            (e) => e.toString() == json['type'],
        orElse: () => AdvisoryType.general,
      ),
      issuedAt: DateTime.parse(json['issuedAt']),
      validUntil: json['validUntil'] != null ? DateTime.parse(json['validUntil']) : null,
      affectedCrops: List<String>.from(json['affectedCrops'] ?? []),
      severity: SeverityLevel.values.firstWhere(
            (e) => e.toString() == json['severity'],
        orElse: () => SeverityLevel.info,
      ),
    );
  }
}

enum AdvisoryType {
  weather,
  soil,
  irrigation,
  pest,
  disease,
  harvest,
  general,
}

enum SeverityLevel {
  info,
  warning,
  alert,
  critical,
}