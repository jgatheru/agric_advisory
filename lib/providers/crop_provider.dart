import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/crop_model.dart';
import '../models/weather_models.dart';
import 'fao_provider.dart';

class CropProvider with ChangeNotifier {
  List<CropRequirement> _crops = [];
  List<String> _recommendedCrops = [];
  Map<String, List<String>> _cropAdvisories = {};
  bool _isLoading = false;
  String _error = '';

  List<CropRequirement> get crops => _crops;
  List<String> get recommendedCrops => _recommendedCrops;
  Map<String, List<String>> get cropAdvisories => _cropAdvisories;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> initialize(BuildContext context) async {
    await loadCropData(context);
  }

  Future<void> loadCropData(BuildContext context) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      // Initialize with default crops first
      _initializeDefaultCrops();

      // Try to get data from FAO provider if available
      try {
        final faoProvider = Provider.of<FAOProvider>(context, listen: false);

        // Check different possible getters from FAOProvider
        if (faoProvider.cropRequirements.isNotEmpty) {
          // Use cropRequirements from FAOProvider
          _crops.addAll(faoProvider.cropRequirements);
          print('FAO crop requirements loaded: ${faoProvider.cropRequirements.length} crops');
        } else if (faoProvider.availableCrops.isNotEmpty) {
          // If FAOProvider has Crop objects, convert them to CropRequirement
          for (final crop in faoProvider.availableCrops) {
            final requirement = _convertCropToRequirement(crop);
            _crops.add(requirement);
          }
          print('FAO available crops loaded: ${faoProvider.availableCrops.length} crops');
        }

        // Also check if integrated recommendations are available
        if (faoProvider.integratedRecommendations.isNotEmpty) {
          print('FAO has ${faoProvider.integratedRecommendations.length} integrated recommendations');
        }

      } catch (e) {
        print('Could not load FAO data: $e');
      }

      print('Total crop data loaded: ${_crops.length} crops');
    } catch (e) {
      _error = 'Failed to load crop data: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to convert Crop to CropRequirement
  CropRequirement _convertCropToRequirement(Crop crop) {
    return CropRequirement(
      name: crop.name,
      scientificName: crop.scientificName,
      minTemp: crop.climateRequirements['tempMin'] ?? 10.0,
      maxTemp: crop.climateRequirements['tempMax'] ?? 35.0,
      minRainfall: crop.climateRequirements['rainfallMin'] ?? 500.0,
      maxRainfall: crop.climateRequirements['rainfallMax'] ?? 1500.0,
      optimalSoilMoisture: 60.0, // Default value
      optimalSoilTemp: crop.climateRequirements['tempOptimal'] ?? 25.0,
      optimalSolarRadiation: 5.0, // Default value
      soilTypes: List<String>.from(crop.soilRequirements['soilTypes'] ?? ['Loamy']),
      growthDays: 100, // Default value
      season: crop.season,
      waterRequirement: crop.climateRequirements['waterRequirement'] ?? 500.0,
      nutrients: _extractNutrients(crop.soilRequirements),
    );
  }

  // Extract nutrients from soil requirements
  List<String> _extractNutrients(Map<String, dynamic> soilRequirements) {
    final nutrients = <String>[];

    if (soilRequirements['nitrogen'] != null &&
        (soilRequirements['nitrogen'] == 'High' || soilRequirements['nitrogen'] == 'Medium')) {
      nutrients.add('Nitrogen');
    }

    if (soilRequirements['phosphorus'] != null &&
        (soilRequirements['phosphorus'] == 'High' || soilRequirements['phosphorus'] == 'Medium')) {
      nutrients.add('Phosphorus');
    }

    if (soilRequirements['potassium'] != null &&
        (soilRequirements['potassium'] == 'High' || soilRequirements['potassium'] == 'Medium')) {
      nutrients.add('Potassium');
    }

    return nutrients;
  }

  // The rest of your existing methods remain the same...
  void _initializeDefaultCrops() {
    // Default crops if FAO data fails
    if (_crops.isEmpty) {
      _crops = [
        CropRequirement(
          name: 'Rice',
          scientificName: 'Oryza sativa',
          minTemp: 20.0,
          maxTemp: 35.0,
          minRainfall: 1000.0,
          maxRainfall: 2500.0,
          optimalSoilMoisture: 70.0,
          optimalSoilTemp: 25.0,
          optimalSolarRadiation: 5.0,
          soilTypes: ['Clay', 'Clay Loam'],
          growthDays: 120,
          season: 'Kharif',
          waterRequirement: 1200.0,
          nutrients: ['Nitrogen', 'Phosphorus', 'Potassium'],
        ),
        CropRequirement(
          name: 'Wheat',
          scientificName: 'Triticum aestivum',
          minTemp: 10.0,
          maxTemp: 25.0,
          minRainfall: 500.0,
          maxRainfall: 1000.0,
          optimalSoilMoisture: 60.0,
          optimalSoilTemp: 20.0,
          optimalSolarRadiation: 5.5,
          soilTypes: ['Loamy', 'Clay Loam'],
          growthDays: 140,
          season: 'Rabi',
          waterRequirement: 600.0,
          nutrients: ['Nitrogen', 'Phosphorus', 'Potassium'],
        ),
        // ... rest of your default crops remain the same
      ];
    }
  }

  // Alternative method to get recommendations from FAOProvider directly
  // Alternative method to get recommendations from FAOProvider directly
  Future<List<String>> getRecommendationsFromFAO(BuildContext context, {
    required double temperature,
    required double annualRainfall,
    required double soilPH,
    required String soilType,
    required String season,
  }) async {
    try {
      final faoProvider = Provider.of<FAOProvider>(context, listen: false);

      // Check if FAOProvider has integrated recommendations
      if (faoProvider.integratedRecommendations.isNotEmpty) {
        // Return crop names from integrated recommendations
        return faoProvider.integratedRecommendations
            .map((rec) => rec.crop.name)
            .toList();
      }

      // Otherwise, use the simpler recommendCrops method if available
      final weather = WeatherData(
        temperature: temperature,
        precipitation: annualRainfall / 365, // Convert to daily
        humidity: 60.0, // Default
        windSpeed: 10.0, // Default
        weatherCode: '0',
        time: DateTime.now(), // Required parameter
        solarRadiation: 5.0, // Default
      );

      // You might need to call analyzeWithWeatherAndSoil first
      await faoProvider.analyzeWithWeatherAndSoil(
        weather: weather,
        soilAnalysis: null, // Pass null or get from SoilApiProvider
        annualRainfall: annualRainfall,
        latitude: 0.0, // You need to get actual coordinates
        longitude: 0.0,
        prioritizeDroughtTolerance: annualRainfall < 600,
      );

      if (faoProvider.integratedRecommendations.isNotEmpty) {
        return faoProvider.integratedRecommendations
            .take(5) // Top 5
            .map((rec) => rec.crop.name)
            .toList();
      }

      return [];
    } catch (e) {
      print('Error getting recommendations from FAO: $e');
      return [];
    }
  }

  // Your existing recommendCrops method remains the same...
  Future<List<String>> recommendCrops(
      BuildContext context, {
        required double temperature,
        required double rainfall,
        required double soilMoisture,
        required double soilTemperature,
        required double solarRadiation,
        required String soilType,
        required String season,
      }) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      final recommendations = <String>[];
      final advisories = <String, List<String>>{};

      for (final crop in _crops) {
        final cropAdvisories = <String>[];
        bool isSuitable = true;

        // Temperature check (more realistic daily range)
        if (temperature < crop.minTemp - 2) {
          cropAdvisories.add('Temperature ${temperature.toStringAsFixed(1)}°C is below minimum requirement (${crop.minTemp}°C).');
          isSuitable = false;
        } else if (temperature > crop.maxTemp + 2) {
          cropAdvisories.add('Temperature ${temperature.toStringAsFixed(1)}°C is above maximum tolerance (${crop.maxTemp}°C).');
          isSuitable = false;
        } else if (temperature < crop.minTemp) {
          cropAdvisories.add('Temperature is slightly low. Consider delayed planting or protected cultivation.');
        } else if (temperature > crop.maxTemp) {
          cropAdvisories.add('Temperature is slightly high. Provide shade if possible.');
        }

        // Rainfall check (use annual requirements)
        final annualRainfall = rainfall * 365; // Convert daily to annual
        if (annualRainfall < crop.minRainfall * 0.7) {
          cropAdvisories.add('Insufficient rainfall. Requires substantial irrigation.');
          isSuitable = false;
        } else if (annualRainfall < crop.minRainfall) {
          cropAdvisories.add('Rainfall is below optimal. Supplemental irrigation needed.');
        } else if (annualRainfall > crop.maxRainfall) {
          cropAdvisories.add('Excess rainfall. Ensure proper drainage.');
        }

        // Soil moisture check
        if (soilMoisture < 30) {
          cropAdvisories.add('Critical soil moisture level. Immediate irrigation required.');
          isSuitable = false;
        } else if (soilMoisture < crop.optimalSoilMoisture - 10) {
          cropAdvisories.add('Soil moisture low. Schedule irrigation.');
        } else if (soilMoisture > crop.optimalSoilMoisture + 10) {
          cropAdvisories.add('Soil moisture high. Risk of root diseases.');
        }

        // Soil temperature check
        if (soilTemperature < crop.optimalSoilTemp - 5) {
          cropAdvisories.add('Soil temperature too low for optimal germination.');
        } else if (soilTemperature > crop.optimalSoilTemp + 5) {
          cropAdvisories.add('Soil temperature high. May affect root development.');
        }

        // Solar radiation check
        if (solarRadiation < crop.optimalSolarRadiation - 2) {
          cropAdvisories.add('Low sunlight. Growth may be slower.');
        }

        // Soil type check
        if (!crop.soilTypes.any((type) =>
        soilType.toLowerCase().contains(type.toLowerCase()) ||
            type.toLowerCase().contains(soilType.toLowerCase()))) {
          cropAdvisories.add('Soil type ($soilType) not ideal. Consider soil amendment.');
        }

        // Season check
        if (crop.season != 'Year Round' && crop.season != season) {
          cropAdvisories.add('Outside optimal season ($season). Consider protected cultivation.');
          isSuitable = false;
        }

        // Calculate suitability score
        final suitabilityScore = _calculateSuitabilityScore(
          crop,
          temperature,
          annualRainfall, // Use annual rainfall
          soilMoisture,
          soilTemperature,
          solarRadiation,
          soilType,
          season,
        );

        if (isSuitable || suitabilityScore > 0.5) {
          recommendations.add(crop.name);
          advisories[crop.name] = cropAdvisories;
        }
      }

      // Sort by suitability score
      recommendations.sort((a, b) {
        final cropA = _crops.firstWhere((c) => c.name == a);
        final cropB = _crops.firstWhere((c) => c.name == b);
        final scoreA = _calculateSuitabilityScore(
          cropA,
          temperature,
          rainfall * 365,
          soilMoisture,
          soilTemperature,
          solarRadiation,
          soilType,
          season,
        );
        final scoreB = _calculateSuitabilityScore(
          cropB,
          temperature,
          rainfall * 365,
          soilMoisture,
          soilTemperature,
          solarRadiation,
          soilType,
          season,
        );
        return scoreB.compareTo(scoreA);
      });

      // Limit to top recommendations
      _recommendedCrops = recommendations.take(5).toList();
      _cropAdvisories = advisories;

      await Future.delayed(Duration(milliseconds: 100)); // Small delay for UI

      return _recommendedCrops;
    } catch (e) {
      _error = 'Error recommending crops: $e';
      print(_error);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double _calculateSuitabilityScore(
      CropRequirement crop,
      double temperature,
      double annualRainfall,
      double soilMoisture,
      double soilTemperature,
      double solarRadiation,
      String soilType,
      String season,
      ) {
    double score = 0.0;
    final maxScore = 100.0;

    // Temperature (max 30 points)
    if (temperature >= crop.minTemp && temperature <= crop.maxTemp) {
      final tempMid = (crop.minTemp + crop.maxTemp) / 2;
      final tempRange = crop.maxTemp - crop.minTemp;
      final tempDeviation = (temperature - tempMid).abs();
      final tempScore = 30 * (1 - (tempDeviation / (tempRange / 2)));
      score += tempScore.clamp(0.0, 30.0);
    }

    // Rainfall (max 25 points)
    if (annualRainfall >= crop.minRainfall && annualRainfall <= crop.maxRainfall) {
      final rainMid = (crop.minRainfall + crop.maxRainfall) / 2;
      final rainRange = crop.maxRainfall - crop.minRainfall;
      final rainDeviation = (annualRainfall - rainMid).abs();
      final rainScore = 25 * (1 - (rainDeviation / (rainRange / 2)));
      score += rainScore.clamp(0.0, 25.0);
    }

    // Soil moisture (max 20 points)
    final moistureDeviation = (soilMoisture - crop.optimalSoilMoisture).abs();
    final moistureScore = 20 * (1 - (moistureDeviation / 50));
    score += moistureScore.clamp(0.0, 20.0);

    // Soil temperature (max 10 points)
    final soilTempDeviation = (soilTemperature - crop.optimalSoilTemp).abs();
    final soilTempScore = 10 * (1 - (soilTempDeviation / 15));
    score += soilTempScore.clamp(0.0, 10.0);

    // Solar radiation (max 10 points)
    final solarDeviation = (solarRadiation - crop.optimalSolarRadiation).abs();
    final solarScore = 10 * (1 - (solarDeviation / 5));
    score += solarScore.clamp(0.0, 10.0);

    // Soil type match (max 3 points)
    if (crop.soilTypes.any((type) =>
        soilType.toLowerCase().contains(type.toLowerCase()))) {
      score += 3;
    }

    // Season match (max 2 points)
    if (crop.season == 'Year Round' || crop.season == season) {
      score += 2;
    }

    return (score / maxScore).clamp(0.0, 1.0);
  }

  // The rest of your existing methods remain exactly the same...
  Map<String, dynamic> getCropAnalysis(
      BuildContext context,
      String cropName, {
        required double temperature,
        required double rainfall,
        required double soilMoisture,
        required double soilTemperature,
        required double solarRadiation,
        required String soilType,
        required String season,
        required double humidity,
      }) {
    try {
      final crop = _crops.firstWhere((c) => c.name == cropName);

      final annualRainfall = rainfall * 365;
      final suitabilityScore = _calculateSuitabilityScore(
        crop,
        temperature,
        annualRainfall,
        soilMoisture,
        soilTemperature,
        solarRadiation,
        soilType,
        season,
      );

      // Get advisories for this crop
      final advisories = _cropAdvisories[cropName] ?? [];

      return {
        'crop': crop,
        'suitabilityScore': suitabilityScore,
        'suitabilityLevel': _getSuitabilityLevel(suitabilityScore),
        'advisories': advisories,
        'plantingWindow': _getPlantingWindow(crop, season),
        'harvestTimeline': _getHarvestTimeline(crop),
        'fertilizerRecommendation': _getFertilizerRecommendation(crop),
        'pestRisk': _getPestRisk(temperature, humidity, season),
        'irrigationRequirement': _getIrrigationRequirement(crop, annualRainfall),
      };
    } catch (e) {
      return {
        'error': 'Crop analysis error: $e',
      };
    }
  }

  String _getSuitabilityLevel(double score) {
    if (score >= 0.8) return 'Excellent';
    if (score >= 0.6) return 'Good';
    if (score >= 0.4) return 'Fair';
    return 'Poor';
  }

  String _getPlantingWindow(CropRequirement crop, String season) {
    final now = DateTime.now();
    final plantingDate = now;
    final harvestDate = now.add(Duration(days: crop.growthDays));

    return '${DateFormat('MMM d').format(plantingDate)} - ${DateFormat('MMM d, yyyy').format(harvestDate)}';
  }

  String _getHarvestTimeline(CropRequirement crop) {
    return 'Approximately ${crop.growthDays} days from planting';
  }

  Map<String, String> _getFertilizerRecommendation(CropRequirement crop) {
    final recommendations = <String, String>{};

    for (final nutrient in crop.nutrients) {
      switch (nutrient.toLowerCase()) {
        case 'nitrogen':
          recommendations['Nitrogen'] = 'Apply 100-150 kg/ha in split doses';
          break;
        case 'phosphorus':
          recommendations['Phosphorus'] = 'Apply 50-80 kg/ha as basal dose';
          break;
        case 'potassium':
          recommendations['Potassium'] = 'Apply 60-100 kg/ha in split doses';
          break;
        case 'calcium':
          recommendations['Calcium'] = 'Apply 200-400 kg/ha gypsum';
          break;
        default:
          recommendations[nutrient] = 'Apply as per soil test recommendation';
      }
    }

    return recommendations;
  }

  String _getPestRisk(double temperature, double humidity, String season) {
    if (temperature > 25 && humidity > 70) {
      return 'High pest risk - warm, humid conditions favor pest growth';
    } else if (season == 'Kharif' && humidity > 60) {
      return 'Moderate pest risk - rainy season increases disease pressure';
    } else {
      return 'Low pest risk - maintain regular monitoring';
    }
  }

  String _getIrrigationRequirement(CropRequirement crop, double annualRainfall) {
    if (annualRainfall < crop.minRainfall) {
      final deficit = crop.minRainfall - annualRainfall;
      return 'Required: ${deficit.toStringAsFixed(0)} mm additional irrigation';
    } else if (annualRainfall > crop.maxRainfall) {
      return 'Reduce irrigation, ensure drainage';
    } else {
      return 'Rainfall adequate, monitor soil moisture';
    }
  }

  List<CropRequirement> searchCrops(String query) {
    if (query.isEmpty) return _crops;

    final lowerQuery = query.toLowerCase();
    return _crops.where((crop) {
      return crop.name.toLowerCase().contains(lowerQuery) ||
          crop.scientificName.toLowerCase().contains(lowerQuery) ||
          crop.season.toLowerCase().contains(lowerQuery) ||
          crop.soilTypes.any((type) => type.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  void clearRecommendations() {
    _recommendedCrops.clear();
    _cropAdvisories.clear();
    notifyListeners();
  }
}