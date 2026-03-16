// soil_api_models.dart
import '../models/soil_data.dart';

// Typedef to avoid circular dependency
typedef SoilDataFetchFunction = Future<SoilData> Function(
    Object service,
    double lat,
    double lon,
    int depth,
    );

class SoilDataSource {
  final String name;
  final int priority;
  final SoilDataFetchFunction fetch;

  SoilDataSource({
    required this.name,
    required this.priority,
    required this.fetch,
  });
}

class ApiSourceResult {
  final String name;
  final bool success;
  final int? parametersFound;
  final String? error;
  final Duration? responseTime;

  ApiSourceResult({
    required this.name,
    required this.success,
    this.parametersFound,
    this.error,
    this.responseTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'success': success,
      'parameters_found': parametersFound,
      'error': error,
      'response_time_ms': responseTime?.inMilliseconds,
    };
  }
}

class DepthProfileData {
  final String property;
  final List<int> depths;
  final List<double> values;
  final String source;

  DepthProfileData({
    required this.property,
    required this.depths,
    required this.values,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'property': property,
      'depths': depths,
      'values': values,
      'source': source,
    };
  }
}

class SoilHealthData {
  final double score;
  final String rating;
  final Map<String, dynamic> metrics;
  final DateTime date;

  SoilHealthData({
    required this.score,
    required this.rating,
    required this.metrics,
    required this.date,
  });

  factory SoilHealthData.fromJson(Map<String, dynamic> json) {
    return SoilHealthData(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rating: json['rating'] as String? ?? 'Unknown',
      metrics: json['metrics'] as Map<String, dynamic>? ?? {},
      date: json['date'] != null
          ? DateTime.parse(json['date'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'rating': rating,
      'metrics': metrics,
      'date': date.toIso8601String(),
    };
  }
}

class SoilNutrientResponse {
  final DateTime date;
  final String? location;
  final double? pH;
  final double? nitrogen; // mg/kg
  final double? phosphorus; // mg/kg
  final double? potassium; // mg/kg
  final double? magnesium; // mg/kg
  final double? calcium; // mg/kg
  final double? organicMatter; // %
  final double? salinity; // dS/m
  final double? cec; // Cation Exchange Capacity (cmolc/kg)
  final double? baseSaturation; // %
  final String? soilType;
  final String? textureClass;
  final String? source;
  final String? notes;

  SoilNutrientResponse({
    required this.date,
    this.location,
    this.pH,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.magnesium,
    this.calcium,
    this.organicMatter,
    this.salinity,
    this.cec,
    this.baseSaturation,
    this.soilType,
    this.textureClass,
    this.source,
    this.notes,
  });

  // Factory constructor from JSON - FIXED VERSION
  factory SoilNutrientResponse.fromJson(Map<String, dynamic> json) {
    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // FIX: Always returns DateTime, never DateTime?
    DateTime _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      if (value is num) {
        // Handle timestamp (assuming seconds since epoch)
        return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
      }
      // Default to current time
      return DateTime.now();
    }

    return SoilNutrientResponse(
      date: _parseDate(json['date']),
      location: json['location'] as String?,
      pH: _parseDouble(json['pH']),
      nitrogen: _parseDouble(json['nitrogen']),
      phosphorus: _parseDouble(json['phosphorus']),
      potassium: _parseDouble(json['potassium']),
      magnesium: _parseDouble(json['magnesium']),
      calcium: _parseDouble(json['calcium']),
      organicMatter: _parseDouble(json['organicMatter']),
      salinity: _parseDouble(json['salinity']),
      cec: _parseDouble(json['cec']),
      baseSaturation: _parseDouble(json['baseSaturation']),
      soilType: json['soilType'] as String?,
      textureClass: json['textureClass'] as String?,
      source: json['source'] as String?,
      notes: json['notes'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      if (location != null) 'location': location,
      if (pH != null) 'pH': pH,
      if (nitrogen != null) 'nitrogen': nitrogen,
      if (phosphorus != null) 'phosphorus': phosphorus,
      if (potassium != null) 'potassium': potassium,
      if (magnesium != null) 'magnesium': magnesium,
      if (calcium != null) 'calcium': calcium,
      if (organicMatter != null) 'organicMatter': organicMatter,
      if (salinity != null) 'salinity': salinity,
      if (cec != null) 'cec': cec,
      if (baseSaturation != null) 'baseSaturation': baseSaturation,
      if (soilType != null) 'soilType': soilType,
      if (textureClass != null) 'textureClass': textureClass,
      if (source != null) 'source': source,
      if (notes != null) 'notes': notes,
    };
  }

  // Create an empty response
  factory SoilNutrientResponse.empty() {
    return SoilNutrientResponse(
      date: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'SoilNutrientResponse(date: $date, pH: $pH, nitrogen: $nitrogen, soilType: $soilType)';
  }
}