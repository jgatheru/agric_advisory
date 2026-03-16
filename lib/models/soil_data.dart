import 'package:intl/intl.dart';

/// Comprehensive soil data model with all agricultural parameters
class SoilData {
  final DateTime date;
  final double latitude;
  final double longitude;
  final String location;
  final String? soilType;

  // Core soil nutrients
  final double? pH;
  final double? nitrogen;       // mg/kg
  final double? phosphorus;     // mg/kg
  final double? potassium;      // mg/kg
  final double? calcium;        // mg/kg
  final double? magnesium;      // mg/kg
  final double? organicMatter;  // %

  // Soil physical properties
  final double? soilMoisture;   // %
  final double? soilTemperature; // °C
  final double? salinity;       // dS/m
  final double? electricalConductivity; // dS/m
  final double? cationExchangeCapacity; // meq/100g

  // Weather/climate data
  final double? airTemperature; // °C
  final double? precipitation;  // mm
  final double? humidity;       // %
  final double? solarRadiation; // kWh/m²
  final double? windSpeed;      // m/s

  // Metadata
  final String source;
  final String? notes;
  final double? accuracy;
  final Map<String, dynamic>? rawData;

  SoilData({
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.location,
    this.soilType,

    // Nutrients
    this.pH,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.calcium,
    this.magnesium,
    this.organicMatter,

    // Physical properties
    this.soilMoisture,
    this.soilTemperature,
    this.salinity,
    this.electricalConductivity,
    this.cationExchangeCapacity,

    // Weather
    this.airTemperature,
    this.precipitation,
    this.humidity,
    this.solarRadiation,
    this.windSpeed,

    // Metadata
    required this.source,
    this.notes,
    this.accuracy,
    this.rawData,
  });

  /// Creates a SoilData object with all the fields you specified
  factory SoilData.complete({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String location,

    // Soil properties
    String? soilType,
    double? pH,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? organicMatter,
    double? salinity,

    // Physical measurements
    double? soilMoisture,
    double? soilTemperature,

    // Weather measurements
    double? airTemperature,
    double? precipitation,
    double? humidity,
    double? solarRadiation,
    double? windSpeed,

    // Other
    String source = 'Unknown',
    String? notes,
  }) {
    return SoilData(
      date: date,
      latitude: latitude,
      longitude: longitude,
      location: location,
      soilType: soilType,
      pH: pH,
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      organicMatter: organicMatter,
      salinity: salinity,
      soilMoisture: soilMoisture,
      soilTemperature: soilTemperature,
      airTemperature: airTemperature,
      precipitation: precipitation,
      humidity: humidity,
      solarRadiation: solarRadiation,
      windSpeed: windSpeed,
      source: source,
      notes: notes,
    );
  }

  /// Factory for creating from your exact field list
  factory SoilData.fromFields({
    required DateTime date,
    required double soilMoisture,
    required double soilTemperature,
    required double solarRadiation,
    required double precipitation,
    required String location,
    double? pH,
    double? magnesium,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? calcium,
    double? organicMatter,
    double? salinity,
    String? soilType,
    String? notes,
    String source = 'Custom',
  }) {
    // Parse latitude and longitude from location string
    double latitude = 0.0;
    double longitude = 0.0;

    try {
      // Try to extract coords from location string
      // Format: "Lat: 28.6139, Lng: 77.2090"
      final latMatch = RegExp(r'Lat:\s*([-\d.]+)').firstMatch(location);
      final lngMatch = RegExp(r'Lng:\s*([-\d.]+)').firstMatch(location);

      if (latMatch != null && lngMatch != null) {
        latitude = double.parse(latMatch.group(1)!);
        longitude = double.parse(lngMatch.group(1)!);
      }
    } catch (e) {
      // If parsing fails, use default
    }

    return SoilData.complete(
      date: date,
      latitude: latitude,
      longitude: longitude,
      location: location,
      soilType: soilType,
      pH: pH,
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      organicMatter: organicMatter,
      salinity: salinity,
      soilMoisture: soilMoisture,
      soilTemperature: soilTemperature,
      solarRadiation: solarRadiation,
      precipitation: precipitation,
      source: source,
      notes: notes,
    );
  }

  // ============ GETTERS ============

  bool get isValid =>
      latitude >= -90 && latitude <= 90 &&
          longitude >= -180 && longitude <= 180;

  bool get hasNutrientData =>
      pH != null || nitrogen != null || phosphorus != null ||
          potassium != null || calcium != null || magnesium != null;

  bool get hasCompleteNutrientData =>
      pH != null && nitrogen != null && phosphorus != null &&
          potassium != null && calcium != null && magnesium != null;

  bool get hasSoilProperties =>
      soilMoisture != null || soilTemperature != null || soilType != null;

  bool get hasWeatherData =>
      precipitation != null || solarRadiation != null || airTemperature != null;

  double get nutrientCompletenessScore {
    int total = 0;
    int present = 0;

    final nutrients = [pH, nitrogen, phosphorus, potassium, calcium, magnesium, organicMatter];
    for (var nutrient in nutrients) {
      total++;
      if (nutrient != null) present++;
    }

    return total > 0 ? (present / total * 100) : 0;
  }

  String get completenessDescription {
    final score = nutrientCompletenessScore;
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    if (score >= 30) return 'Poor';
    return 'Very Poor';
  }

  // ============ ANALYSIS METHODS ============

  Map<String, String> getNutrientAnalysis() {
    final analysis = <String, String>{};

    // pH Analysis
    if (pH != null) {
      if (pH! < 4.5) analysis['pH'] = 'Extremely Acidic';
      else if (pH! < 5.5) analysis['pH'] = 'Very Acidic';
      else if (pH! < 6.0) analysis['pH'] = 'Acidic';
      else if (pH! <= 7.0) analysis['pH'] = 'Optimal';
      else if (pH! <= 7.5) analysis['pH'] = 'Slightly Alkaline';
      else if (pH! <= 8.5) analysis['pH'] = 'Alkaline';
      else analysis['pH'] = 'Very Alkaline';
    }

    // Nitrogen Analysis (mg/kg)
    if (nitrogen != null) {
      if (nitrogen! < 10) analysis['nitrogen'] = 'Very Low';
      else if (nitrogen! < 20) analysis['nitrogen'] = 'Low';
      else if (nitrogen! <= 30) analysis['nitrogen'] = 'Medium';
      else if (nitrogen! <= 50) analysis['nitrogen'] = 'High';
      else analysis['nitrogen'] = 'Very High';
    }

    // Phosphorus Analysis (mg/kg)
    if (phosphorus != null) {
      if (phosphorus! < 5) analysis['phosphorus'] = 'Very Low';
      else if (phosphorus! < 10) analysis['phosphorus'] = 'Low';
      else if (phosphorus! <= 20) analysis['phosphorus'] = 'Medium';
      else if (phosphorus! <= 40) analysis['phosphorus'] = 'High';
      else analysis['phosphorus'] = 'Very High';
    }

    // Potassium Analysis (mg/kg)
    if (potassium != null) {
      if (potassium! < 50) analysis['potassium'] = 'Very Low';
      else if (potassium! < 100) analysis['potassium'] = 'Low';
      else if (potassium! <= 150) analysis['potassium'] = 'Medium';
      else if (potassium! <= 200) analysis['potassium'] = 'High';
      else analysis['potassium'] = 'Very High';
    }

    // Calcium Analysis (mg/kg)
    if (calcium != null) {
      if (calcium! < 200) analysis['calcium'] = 'Very Low';
      else if (calcium! < 400) analysis['calcium'] = 'Low';
      else if (calcium! <= 800) analysis['calcium'] = 'Medium';
      else if (calcium! <= 1200) analysis['calcium'] = 'High';
      else analysis['calcium'] = 'Very High';
    }

    // Magnesium Analysis (mg/kg)
    if (magnesium != null) {
      if (magnesium! < 30) analysis['magnesium'] = 'Very Low';
      else if (magnesium! < 60) analysis['magnesium'] = 'Low';
      else if (magnesium! <= 120) analysis['magnesium'] = 'Medium';
      else if (magnesium! <= 180) analysis['magnesium'] = 'High';
      else analysis['magnesium'] = 'Very High';
    }

    // Organic Matter Analysis (%)
    if (organicMatter != null) {
      if (organicMatter! < 1.0) analysis['organicMatter'] = 'Very Low';
      else if (organicMatter! < 2.0) analysis['organicMatter'] = 'Low';
      else if (organicMatter! <= 3.0) analysis['organicMatter'] = 'Medium';
      else if (organicMatter! <= 5.0) analysis['organicMatter'] = 'High';
      else analysis['organicMatter'] = 'Very High';
    }

    // Salinity Analysis (dS/m)
    if (salinity != null) {
      if (salinity! < 0.5) analysis['salinity'] = 'Non-Saline';
      else if (salinity! < 2.0) analysis['salinity'] = 'Slightly Saline';
      else if (salinity! < 4.0) analysis['salinity'] = 'Moderately Saline';
      else if (salinity! < 8.0) analysis['salinity'] = 'Strongly Saline';
      else analysis['salinity'] = 'Very Strongly Saline';
    }

    // Soil Moisture Analysis (%)
    if (soilMoisture != null) {
      if (soilMoisture! < 10) analysis['soilMoisture'] = 'Very Dry';
      else if (soilMoisture! < 20) analysis['soilMoisture'] = 'Dry';
      else if (soilMoisture! <= 40) analysis['soilMoisture'] = 'Optimal';
      else if (soilMoisture! <= 60) analysis['soilMoisture'] = 'Moist';
      else analysis['soilMoisture'] = 'Waterlogged';
    }

    // Soil Temperature Analysis (°C)
    if (soilTemperature != null) {
      if (soilTemperature! < 5) analysis['soilTemperature'] = 'Very Cold';
      else if (soilTemperature! < 10) analysis['soilTemperature'] = 'Cold';
      else if (soilTemperature! <= 20) analysis['soilTemperature'] = 'Optimal';
      else if (soilTemperature! <= 30) analysis['soilTemperature'] = 'Warm';
      else analysis['soilTemperature'] = 'Hot';
    }

    return analysis;
  }

  Map<String, String> getRecommendations() {
    final recommendations = <String, String>{};
    final analysis = getNutrientAnalysis();

    // pH recommendations
    if (pH != null) {
      if (pH! < 6.0) {
        recommendations['pH'] = 'Add lime to raise pH (recommended: 1-2 tons/acre)';
      } else if (pH! > 7.5) {
        recommendations['pH'] = 'Add sulfur or gypsum to lower pH';
      } else {
        recommendations['pH'] = 'pH is optimal for most crops';
      }
    }

    // Nitrogen recommendations
    if (nitrogen != null && nitrogen! < 20) {
      recommendations['nitrogen'] = 'Apply nitrogen fertilizer (urea/ammonium nitrate)';
    }

    // Phosphorus recommendations
    if (phosphorus != null && phosphorus! < 10) {
      recommendations['phosphorus'] = 'Apply phosphorus fertilizer (DAP/SSP)';
    }

    // Potassium recommendations
    if (potassium != null && potassium! < 100) {
      recommendations['potassium'] = 'Apply potassium fertilizer (MOP/SOP)';
    }

    // Organic matter recommendations
    if (organicMatter != null && organicMatter! < 2.0) {
      recommendations['organicMatter'] = 'Add organic compost or manure';
    }

    // Soil moisture recommendations
    if (soilMoisture != null) {
      if (soilMoisture! < 20) {
        recommendations['irrigation'] = 'Irrigation needed immediately';
      } else if (soilMoisture! > 60) {
        recommendations['drainage'] = 'Improve drainage to prevent waterlogging';
      }
    }

    return recommendations;
  }

  String getOverallHealthRating() {
    final analysis = getNutrientAnalysis();
    int optimalCount = 0;
    int totalCount = 0;

    final optimalKeywords = ['Optimal', 'Medium', 'Non-Saline', 'Slightly Saline'];

    for (final status in analysis.values) {
      totalCount++;
      if (optimalKeywords.any((keyword) => status.contains(keyword))) {
        optimalCount++;
      }
    }

    if (totalCount == 0) return 'Unknown';

    final percentage = (optimalCount / totalCount * 100);

    if (percentage >= 80) return 'Excellent';
    if (percentage >= 60) return 'Good';
    if (percentage >= 40) return 'Fair';
    if (percentage >= 20) return 'Poor';
    return 'Very Poor';
  }

  // ============ JSON SERIALIZATION ============

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'soilType': soilType,

      // Nutrients
      'pH': pH,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'calcium': calcium,
      'magnesium': magnesium,
      'organicMatter': organicMatter,

      // Physical properties
      'soilMoisture': soilMoisture,
      'soilTemperature': soilTemperature,
      'salinity': salinity,
      'electricalConductivity': electricalConductivity,
      'cationExchangeCapacity': cationExchangeCapacity,

      // Weather
      'airTemperature': airTemperature,
      'precipitation': precipitation,
      'humidity': humidity,
      'solarRadiation': solarRadiation,
      'windSpeed': windSpeed,

      // Metadata
      'source': source,
      'notes': notes,
      'accuracy': accuracy,

      // Derived metrics
      'nutrientCompletenessScore': nutrientCompletenessScore,
      'completenessDescription': completenessDescription,
      'overallHealthRating': getOverallHealthRating(),
    };
  }

  factory SoilData.fromJson(Map<String, dynamic> json) {
    return SoilData(
      date: DateTime.parse(json['date']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      location: json['location'] ?? '',
      soilType: json['soilType'],

      // Nutrients
      pH: json['pH']?.toDouble(),
      nitrogen: json['nitrogen']?.toDouble(),
      phosphorus: json['phosphorus']?.toDouble(),
      potassium: json['potassium']?.toDouble(),
      calcium: json['calcium']?.toDouble(),
      magnesium: json['magnesium']?.toDouble(),
      organicMatter: json['organicMatter']?.toDouble(),

      // Physical properties
      soilMoisture: json['soilMoisture']?.toDouble(),
      soilTemperature: json['soilTemperature']?.toDouble(),
      salinity: json['salinity']?.toDouble(),
      electricalConductivity: json['electricalConductivity']?.toDouble(),
      cationExchangeCapacity: json['cationExchangeCapacity']?.toDouble(),

      // Weather
      airTemperature: json['airTemperature']?.toDouble(),
      precipitation: json['precipitation']?.toDouble(),
      humidity: json['humidity']?.toDouble(),
      solarRadiation: json['solarRadiation']?.toDouble(),
      windSpeed: json['windSpeed']?.toDouble(),

      // Metadata
      source: json['source'] ?? 'Unknown',
      notes: json['notes'],
      accuracy: json['accuracy']?.toDouble(),
      rawData: json['rawData'] as Map<String, dynamic>?,
    );
  }

  // ============ FACTORY METHODS ============

  factory SoilData.empty({
    required double latitude,
    required double longitude,
    String source = 'Empty',
  }) {
    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      source: source,
      notes: 'No data available',
    );
  }

  factory SoilData.fromCoordinates({
    required double latitude,
    required double longitude,
    String source = 'Coordinates',
  }) {
    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      source: source,
    );
  }

  // ============ COPY METHODS ============

  SoilData copyWith({
    DateTime? date,
    double? latitude,
    double? longitude,
    String? location,
    String? soilType,
    double? pH,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? organicMatter,
    double? soilMoisture,
    double? soilTemperature,
    double? salinity,
    double? electricalConductivity,
    double? cationExchangeCapacity,
    double? airTemperature,
    double? precipitation,
    double? humidity,
    double? solarRadiation,
    double? windSpeed,
    String? source,
    String? notes,
    double? accuracy,
    Map<String, dynamic>? rawData,
  }) {
    return SoilData(
      date: date ?? this.date,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      soilType: soilType ?? this.soilType,
      pH: pH ?? this.pH,
      nitrogen: nitrogen ?? this.nitrogen,
      phosphorus: phosphorus ?? this.phosphorus,
      potassium: potassium ?? this.potassium,
      calcium: calcium ?? this.calcium,
      magnesium: magnesium ?? this.magnesium,
      organicMatter: organicMatter ?? this.organicMatter,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      soilTemperature: soilTemperature ?? this.soilTemperature,
      salinity: salinity ?? this.salinity,
      electricalConductivity: electricalConductivity ?? this.electricalConductivity,
      cationExchangeCapacity: cationExchangeCapacity ?? this.cationExchangeCapacity,
      airTemperature: airTemperature ?? this.airTemperature,
      precipitation: precipitation ?? this.precipitation,
      humidity: humidity ?? this.humidity,
      solarRadiation: solarRadiation ?? this.solarRadiation,
      windSpeed: windSpeed ?? this.windSpeed,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      accuracy: accuracy ?? this.accuracy,
      rawData: rawData ?? this.rawData,
    );
  }

  SoilData merge(SoilData other) {
    return copyWith(
      pH: pH ?? other.pH,
      nitrogen: nitrogen ?? other.nitrogen,
      phosphorus: phosphorus ?? other.phosphorus,
      potassium: potassium ?? other.potassium,
      calcium: calcium ?? other.calcium,
      magnesium: magnesium ?? other.magnesium,
      organicMatter: organicMatter ?? other.organicMatter,
      soilMoisture: soilMoisture ?? other.soilMoisture,
      soilTemperature: soilTemperature ?? other.soilTemperature,
      salinity: salinity ?? other.salinity,
      soilType: soilType ?? other.soilType,
      airTemperature: airTemperature ?? other.airTemperature,
      precipitation: precipitation ?? other.precipitation,
      humidity: humidity ?? other.humidity,
      solarRadiation: solarRadiation ?? other.solarRadiation,
      windSpeed: windSpeed ?? other.windSpeed,
      notes: notes ?? other.notes,
    );
  }

  // ============ UTILITY METHODS ============

  String toFormattedString() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final buffer = StringBuffer();

    buffer.writeln('Soil Data Report');
    buffer.writeln('=' * 40);
    buffer.writeln('Date: ${dateFormat.format(date)}');
    buffer.writeln('Location: $location');
    buffer.writeln('Source: $source');
    buffer.writeln('Health Rating: ${getOverallHealthRating()}');
    buffer.writeln('');

    if (hasNutrientData) {
      buffer.writeln('NUTRIENTS:');
      if (pH != null) buffer.writeln('  pH: ${pH!.toStringAsFixed(2)}');
      if (nitrogen != null) buffer.writeln('  Nitrogen: ${nitrogen!.toStringAsFixed(1)} mg/kg');
      if (phosphorus != null) buffer.writeln('  Phosphorus: ${phosphorus!.toStringAsFixed(1)} mg/kg');
      if (potassium != null) buffer.writeln('  Potassium: ${potassium!.toStringAsFixed(1)} mg/kg');
      if (calcium != null) buffer.writeln('  Calcium: ${calcium!.toStringAsFixed(1)} mg/kg');
      if (magnesium != null) buffer.writeln('  Magnesium: ${magnesium!.toStringAsFixed(1)} mg/kg');
      if (organicMatter != null) buffer.writeln('  Organic Matter: ${organicMatter!.toStringAsFixed(2)}%');
      buffer.writeln('');
    }

    if (hasSoilProperties) {
      buffer.writeln('SOIL PROPERTIES:');
      if (soilMoisture != null) buffer.writeln('  Moisture: ${soilMoisture!.toStringAsFixed(1)}%');
      if (soilTemperature != null) buffer.writeln('  Temperature: ${soilTemperature!.toStringAsFixed(1)}°C');
      if (salinity != null) buffer.writeln('  Salinity: ${salinity!.toStringAsFixed(2)} dS/m');
      if (soilType != null) buffer.writeln('  Type: $soilType');
      buffer.writeln('');
    }

    if (hasWeatherData) {
      buffer.writeln('WEATHER DATA:');
      if (precipitation != null) buffer.writeln('  Precipitation: ${precipitation!.toStringAsFixed(1)} mm');
      if (solarRadiation != null) buffer.writeln('  Solar Radiation: ${solarRadiation!.toStringAsFixed(1)} kWh/m²');
      if (airTemperature != null) buffer.writeln('  Air Temperature: ${airTemperature!.toStringAsFixed(1)}°C');
      buffer.writeln('');
    }

    if (notes != null && notes!.isNotEmpty) {
      buffer.writeln('NOTES:');
      buffer.writeln('  $notes');
    }

    return buffer.toString();
  }

  Map<String, dynamic> toSimpleMap() {
    return {
      'date': date.toIso8601String(),
      'location': location,
      'pH': pH,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'organicMatter': organicMatter,
      'soilMoisture': soilMoisture,
      'soilTemperature': soilTemperature,
      'source': source,
    };
  }

  @override
  String toString() {
    return 'SoilData(location: $location, pH: $pH, N: $nitrogen, P: $phosphorus, K: $potassium, OM: $organicMatter)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SoilData &&
        other.date == date &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.location == location;
  }

  @override
  int get hashCode {
    return date.hashCode ^ latitude.hashCode ^ longitude.hashCode ^ location.hashCode;
  }
}