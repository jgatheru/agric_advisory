// models/crop_model.dart
class Crop {
  final String id;
  final String name;
  final String scientificName;
  final String category; // e.g., "Cereals", "Vegetables", "Fruits"
  final String season; // Kharif, Rabi, Zaid
  final Map<String, dynamic> climateRequirements;
  final Map<String, dynamic> soilRequirements;
  final List<String> regions;
  final String description;

  Crop({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.category,
    required this.season,
    required this.climateRequirements,
    required this.soilRequirements,
    required this.regions,
    required this.description,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      scientificName: json['scientificName'] ?? '',
      category: json['category'] ?? '',
      season: json['season'] ?? '',
      climateRequirements: Map<String, dynamic>.from(json['climateRequirements'] ?? {}),
      soilRequirements: Map<String, dynamic>.from(json['soilRequirements'] ?? {}),
      regions: List<String>.from(json['regions'] ?? []),
      description: json['description'] ?? '',
    );
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scientificName': scientificName,
      'category': category,
      'season': season,
      'climateRequirements': climateRequirements,
      'soilRequirements': soilRequirements,
      'regions': regions,
      'description': description,
    };
  }

  // Check if crop is suitable for given conditions
  bool isSuitableFor({
    required double temperature,
    required double annualRainfall,
    required double soilPH,
    required String soilType,
  }) {
    final tempMin = climateRequirements['tempMin'] ?? 10.0;
    final tempMax = climateRequirements['tempMax'] ?? 35.0;
    final rainfallMin = climateRequirements['rainfallMin'] ?? 500.0;
    final rainfallMax = climateRequirements['rainfallMax'] ?? 1500.0;
    final phMin = soilRequirements['phMin'] ?? 5.5;
    final phMax = soilRequirements['phMax'] ?? 7.5;
    final preferredSoilTypes = soilRequirements['soilTypes'] ?? <String>['Loamy'];

    // Check temperature range
    if (temperature < tempMin || temperature > tempMax) {
      return false;
    }

    // Check rainfall range
    if (annualRainfall < rainfallMin || annualRainfall > rainfallMax) {
      return false;
    }

    // Check pH range
    if (soilPH < phMin || soilPH > phMax) {
      return false;
    }

    // Check soil type
    if (!preferredSoilTypes.contains(soilType)) {
      return false;
    }

    return true;
  }

  // Calculate suitability score (0-100)
  double calculateSuitabilityScore({
    required double temperature,
    required double annualRainfall,
    required double soilPH,
    required String soilType,
  }) {
    double score = 0.0;

    // Temperature score (30% weight)
    final tempMin = climateRequirements['tempMin'] ?? 10.0;
    final tempMax = climateRequirements['tempMax'] ?? 35.0;
    final tempOptimal = climateRequirements['tempOptimal'] ?? ((tempMin + tempMax) / 2);

    if (temperature >= tempMin && temperature <= tempMax) {
      final tempDeviation = (temperature - tempOptimal).abs();
      final tempRange = tempMax - tempMin;
      score += 30 * (1 - (tempDeviation / (tempRange / 2)));
    }

    // Rainfall score (30% weight)
    final rainfallMin = climateRequirements['rainfallMin'] ?? 500.0;
    final rainfallMax = climateRequirements['rainfallMax'] ?? 1500.0;
    final rainfallOptimal = climateRequirements['rainfallOptimal'] ?? ((rainfallMin + rainfallMax) / 2);

    if (annualRainfall >= rainfallMin && annualRainfall <= rainfallMax) {
      final rainfallDeviation = (annualRainfall - rainfallOptimal).abs();
      final rainfallRange = rainfallMax - rainfallMin;
      score += 30 * (1 - (rainfallDeviation / (rainfallRange / 2)));
    }

    // pH score (20% weight)
    final phMin = soilRequirements['phMin'] ?? 5.5;
    final phMax = soilRequirements['phMax'] ?? 7.5;
    final phOptimal = soilRequirements['phOptimal'] ?? 6.5;

    if (soilPH >= phMin && soilPH <= phMax) {
      final phDeviation = (soilPH - phOptimal).abs();
      final phRange = phMax - phMin;
      score += 20 * (1 - (phDeviation / (phRange / 2)));
    }

    // Soil type score (20% weight)
    final preferredSoilTypes = soilRequirements['soilTypes'] ?? <String>['Loamy'];
    if (preferredSoilTypes.contains(soilType)) {
      score += 20;
    }

    return score.clamp(0.0, 100.0);
  }
}