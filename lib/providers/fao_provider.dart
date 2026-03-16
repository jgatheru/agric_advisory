import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';
import '../models/crop_model.dart';
import '../models/soil_data.dart';

class FAOProvider with ChangeNotifier {
  // Core data
  List<CropRequirement> _cropRequirements = [];
  List<Crop> _availableCrops = [];
  List<CropRecommendation> _integratedRecommendations = [];
  Map<String, dynamic> _soilData = {};
  Map<String, dynamic> _waterData = {};
  Map<String, dynamic> _analysisSummary = {};

  // State management
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String _error = '';
  DateTime? _lastFetchTime;
  String _currentRegion = 'Kenya';

  // Current analysis data
  WeatherData? _currentWeather;
  SoilData? _currentSoilData;
  double? _currentAnnualRainfall;
  double? _currentLatitude;
  double? _currentLongitude;

  // Crop metadata storage
  final Map<String, Map<String, dynamic>> _cropMetadata = {};

  // FAO Crop Calendar Data - ADDED BACK
  static final Map<String, Map<String, dynamic>> _faoCropCalendar = {
    'Maize': {
      'scientificName': 'Zea mays',
      'waterRequirement': 600.0,
      'growingPeriod': 90,
      'temperature': {'min': 18.0, 'max': 32.0, 'optimal': 24.0},
      'rainfall': {'min': 500.0, 'max': 1200.0, 'optimal': 750.0},
      'soilTypes': ['Sandy Loam', 'Loamy', 'Clay Loam'],
      'soilPH': {'min': 5.5, 'max': 7.5, 'optimal': 6.2},
      'season': 'Long Rain (March-May), Short Rain (Oct-Dec)',
      'faoCategory': 'Cereals',
      'nutrients': ['Nitrogen', 'Phosphorus', 'Potassium'],
      'importance': 'Staple food for majority of Kenyans',
      'droughtTolerance': 'Medium',
      'pestRisk': 'Medium',
      'marketValue': 'High',
      'yieldPotential': 2.5,
    },
    'Beans': {
      'scientificName': 'Phaseolus vulgaris',
      'waterRequirement': 400.0,
      'growingPeriod': 75,
      'temperature': {'min': 16.0, 'max': 28.0, 'optimal': 22.0},
      'rainfall': {'min': 350.0, 'max': 800.0, 'optimal': 500.0},
      'soilTypes': ['Loamy', 'Sandy Loam', 'Clay Loam'],
      'soilPH': {'min': 5.5, 'max': 7.0, 'optimal': 6.2},
      'season': 'Long Rain (March-May), Short Rain (Oct-Dec)',
      'faoCategory': 'Legumes',
      'nutrients': ['Nitrogen', 'Phosphorus', 'Potassium'],
      'importance': 'Major protein source, fixes nitrogen in soil',
      'droughtTolerance': 'Medium-Low',
      'pestRisk': 'High',
      'marketValue': 'Medium',
      'yieldPotential': 0.8,
    },
    // ... [Add other crops as needed] ...
  };

  // Getters
  List<CropRequirement> get cropRequirements => _cropRequirements;
  List<Crop> get availableCrops => _availableCrops;
  List<CropRecommendation> get integratedRecommendations => _integratedRecommendations;
  Map<String, dynamic> get soilData => _soilData;
  Map<String, dynamic> get waterData => _waterData;
  Map<String, dynamic> get analysisSummary => _analysisSummary;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isAnalyzing;
  String get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;
  String get currentRegion => _currentRegion;
  WeatherData? get currentWeather => _currentWeather;
  SoilData? get currentSoilData => _currentSoilData;

  set currentRegion(String region) {
    _currentRegion = region;
    notifyListeners();
  }

  // Initialize the provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      await _loadCachedData();

      if (_cropRequirements.isEmpty || _availableCrops.isEmpty) {
        await _loadFAOCropData();
      }

      await _loadKenyanSoilData();
      await _loadKenyanWaterData();

      _lastFetchTime = DateTime.now();
      await _cacheData();

    } catch (e) {
      _error = 'Initialization failed: $e';
      print('FAOProvider initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load FAO crop data into memory - FIXED VERSION
  Future<void> _loadFAOCropData() async {
    try {
      _cropRequirements.clear();
      _availableCrops.clear();
      _cropMetadata.clear();

      for (final entry in _faoCropCalendar.entries) {
        final cropName = entry.key;
        final cropInfo = entry.value;

        // Store metadata separately
        _cropMetadata[cropName] = {
          'droughtTolerance': cropInfo['droughtTolerance'] ?? 'Medium',
          'importance': cropInfo['importance'] ?? 'Subsistence crop',
          'marketValue': cropInfo['marketValue'] ?? 'Medium',
          'yieldPotential': cropInfo['yieldPotential'] ?? 5.0,
          'growingPeriod': cropInfo['growingPeriod'] ?? 100,
          'pestRisk': cropInfo['pestRisk'] ?? 'Medium',
          'localNames': _getLocalNames(cropName),
        };

        // Create CropRequirement - FIXED: Using soilPH from cropInfo
        final soilPH = cropInfo['soilPH'] ?? {'min': 5.5, 'max': 7.5, 'optimal': 6.5};

        final cropRequirement = CropRequirement(
          name: cropName,
          scientificName: cropInfo['scientificName'] ?? cropName,
          minTemp: cropInfo['temperature']['min'] ?? 0.0,
          maxTemp: cropInfo['temperature']['max'] ?? 0.0,
          minRainfall: cropInfo['rainfall']['min'] ?? 0.0,
          maxRainfall: cropInfo['rainfall']['max'] ?? 0.0,
          optimalSoilMoisture: 55.0,
          optimalSoilTemp: cropInfo['temperature']['optimal'] ?? 20.0,
          optimalSolarRadiation: 5.0,
          soilTypes: List<String>.from(cropInfo['soilTypes'] ?? []),
          growthDays: cropInfo['growingPeriod'] ?? 100,
          season: cropInfo['season'] ?? 'Year Round',
          waterRequirement: cropInfo['waterRequirement'] ?? 0.0,
          nutrients: List<String>.from(cropInfo['nutrients'] ?? []),
          faoCategory: cropInfo['faoCategory'] ?? 'Unknown',
          // Note: soilPH fields are not in original CropRequirement model
        );

        _cropRequirements.add(cropRequirement);

        // Create Crop object with available data
        final crop = Crop(
          id: cropName.toLowerCase().replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', ''),
          name: cropName,
          scientificName: cropInfo['scientificName'] ?? cropName,
          category: cropInfo['faoCategory'] ?? 'Unknown',
          season: cropInfo['season'] ?? 'Year Round',
          climateRequirements: {
            'tempMin': cropInfo['temperature']['min'] ?? 0.0,
            'tempMax': cropInfo['temperature']['max'] ?? 0.0,
            'tempOptimal': cropInfo['temperature']['optimal'] ?? 20.0,
            'rainfallMin': cropInfo['rainfall']['min'] ?? 0.0,
            'rainfallMax': cropInfo['rainfall']['max'] ?? 0.0,
            'rainfallOptimal': cropInfo['rainfall']['optimal'] ??
                ((cropInfo['rainfall']['min'] ?? 0.0) + (cropInfo['rainfall']['max'] ?? 0.0)) / 2,
            'waterRequirement': cropInfo['waterRequirement'] ?? 0.0,
          },
          soilRequirements: {
            'phMin': soilPH['min'] ?? 6.0,
            'phMax': soilPH['max'] ?? 7.0,
            'phOptimal': soilPH['optimal'] ?? 6.5,
            'soilTypes': List<String>.from(cropInfo['soilTypes'] ?? []),
            'droughtTolerance': cropInfo['droughtTolerance'] ?? 'Medium',
            'pestRisk': cropInfo['pestRisk'] ?? 'Medium',
          },
          regions: _getRegionsForCropInKenya(cropName),
          description: cropInfo['importance'] ?? 'Important subsistence crop in Kenya',
        );

        _availableCrops.add(crop);
      }

      print('FAO data loaded: ${_cropRequirements.length} crops');
    } catch (e) {
      _error = 'Failed to load FAO data: $e';
      print(_error);
      throw e;
    }
  }

  // Helper method to get crop metadata
  Map<String, dynamic> _getCropMetadata(String cropName) {
    return _cropMetadata[cropName] ?? {
      'droughtTolerance': 'Medium',
      'importance': 'Subsistence crop',
      'marketValue': 'Medium',
      'yieldPotential': 5.0,
      'growingPeriod': 100,
      'pestRisk': 'Medium',
      'localNames': {'Swahili': cropName},
    };
  }

  // Get soil pH values from crop info
  Map<String, dynamic> _getCropSoilPH(String cropName) {
    final cropInfo = _faoCropCalendar[cropName] ?? {};
    return cropInfo['soilPH'] ?? {'min': 5.5, 'max': 7.5, 'optimal': 6.5};
  }

  // MAJOR NEW METHOD: Integrated Analysis with Weather and Soil Data
  Future<void> analyzeWithWeatherAndSoil({
    required WeatherData weather,
    required SoilData? soilAnalysis,
    required double annualRainfall,
    required double latitude,
    required double longitude,
    bool prioritizeDroughtTolerance = false,
    bool prioritizeCashCrops = false,
    String? specificSeason,
  }) async {
    try {
      _isLoading = true;
      _error = '';
      _currentWeather = weather;
      _currentSoilData = soilAnalysis;
      _currentAnnualRainfall = annualRainfall;
      _currentLatitude = latitude;
      _currentLongitude = longitude;
      notifyListeners();

      // Load crop data if not already loaded
      if (_availableCrops.isEmpty) {
        await _loadFAOCropData();
      }

      // Determine current season
      final currentSeason = specificSeason ?? _getCurrentSeason(latitude);

      // Get soil parameters
      final soilPH = soilAnalysis?.pH ?? 6.5;
      final soilType = _determineSoilType(soilAnalysis, latitude, longitude);

      // Perform integrated analysis
      await _performIntegratedAnalysis(
        temperature: weather.temperature,
        annualRainfall: annualRainfall,
        soilPH: soilPH,
        soilType: soilType,
        season: currentSeason,
        precipitation: weather.precipitation,
        humidity: weather.humidity,
        solarRadiation: weather.solarRadiation ?? 5.0,
        windSpeed: weather.windSpeed,
        soilAnalysis: soilAnalysis,
        prioritizeDroughtTolerance: prioritizeDroughtTolerance,
        prioritizeCashCrops: prioritizeCashCrops,
        latitude: latitude,
        longitude: longitude,
      );

      // Generate analysis summary
      _generateAnalysisSummary();

      // Cache the analysis results
      await _cacheAnalysisResults();

    } catch (e) {
      _error = 'Analysis failed: $e';
      print('Error in analyzeWithWeatherAndSoil: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Perform the actual integrated analysis
  Future<void> _performIntegratedAnalysis({
    required double temperature,
    required double annualRainfall,
    required double soilPH,
    required String soilType,
    required String season,
    required double precipitation,
    required double humidity,
    required double solarRadiation,
    required double windSpeed,
    required SoilData? soilAnalysis,
    required bool prioritizeDroughtTolerance,
    required bool prioritizeCashCrops,
    required double latitude,
    required double longitude,
  }) async {
    _integratedRecommendations.clear();

    // Calculate rainfall metrics
    final dailyRainfall = precipitation;
    final monthlyRainfall = dailyRainfall * 30;
    final isDrySeason = monthlyRainfall < 50;

    // Get soil nutrient levels
    final nitrogenLevel = soilAnalysis?.nitrogen ?? 50;
    final phosphorusLevel = soilAnalysis?.phosphorus ?? 50;
    final potassiumLevel = soilAnalysis?.potassium ?? 50;
    final organicMatter = soilAnalysis?.organicMatter ?? 2.0;
    final soilMoisture = soilAnalysis?.soilMoisture ?? 50.0;

    // Get altitude-based adjustments
    final altitude = _estimateAltitude(latitude);
    final altitudeFactor = _calculateAltitudeFactor(altitude);

    // Analyze each crop
    final List<Map<String, dynamic>> scoredCrops = [];

    for (final crop in _availableCrops) {
      final cropRequirement = _cropRequirements.firstWhere(
            (req) => req.name == crop.name,
        orElse: () => cropRequirements[0],
      );

      final cropMetadata = _getCropMetadata(crop.name);
      final cropInfo = _faoCropCalendar[crop.name] ?? {};
      final cropSoilPH = _getCropSoilPH(crop.name);

      // Calculate base suitability score
      double score = _calculateBaseSuitabilityScore(
        crop: crop,
        cropInfo: cropInfo,
        temperature: temperature,
        annualRainfall: annualRainfall,
        soilPH: soilPH,
        soilType: soilType,
      );

      // Apply altitude adjustment
      score *= altitudeFactor;

      // Adjust for season
      final seasonScore = _calculateSeasonScore(crop, season, latitude);
      score *= seasonScore;

      // Adjust for current weather conditions
      final weatherAdjustment = _calculateWeatherAdjustment(
        crop: crop,
        cropInfo: cropInfo,
        cropMetadata: cropMetadata,
        temperature: temperature,
        precipitation: precipitation,
        humidity: humidity,
        solarRadiation: solarRadiation,
        windSpeed: windSpeed,
        soilMoisture: soilMoisture,
      );
      score += weatherAdjustment;

      // Adjust for soil nutrients
      final nutrientScore = _calculateNutrientScore(
        crop: crop,
        cropInfo: cropInfo,
        nitrogen: nitrogenLevel,
        phosphorus: phosphorusLevel,
        potassium: potassiumLevel,
        organicMatter: organicMatter,
        soilPH: soilPH,
        cropSoilPH: cropSoilPH,
      );
      score += nutrientScore;

      // Drought tolerance bonus if needed
      if (prioritizeDroughtTolerance || isDrySeason) {
        final droughtTolerance = crop.soilRequirements['droughtTolerance'] ?? 'Medium';
        final droughtBonus = _calculateDroughtBonus(droughtTolerance);
        score += droughtBonus;
      }

      // Cash crop bonus if prioritized
      if (prioritizeCashCrops) {
        final marketValue = cropMetadata['marketValue'] ?? 'Medium';
        final cashBonus = {
          'Very High': 20,
          'High': 15,
          'Medium': 5,
          'Low': 0,
        }[marketValue] ?? 0;
        score += cashBonus;
      }

      // Yield potential bonus
      final yieldPotential = (cropMetadata['yieldPotential'] as double?) ?? 5.0;
      score += (yieldPotential / 10);

      // Pest risk penalty
      final pestRisk = cropMetadata['pestRisk'] ?? 'Medium';
      final pestPenalty = {
        'Very High': -15,
        'High': -10,
        'Medium': -5,
        'Low': 0,
      }[pestRisk] ?? 0;
      score += pestPenalty;

      // Extreme condition penalties
      if (dailyRainfall > cropRequirement.maxRainfall / 365 * 1.5) {
        score *= 0.7;
      } else if (dailyRainfall < cropRequirement.minRainfall / 365 * 0.7) {
        score *= 0.8;
      }

      if (temperature > cropRequirement.maxTemp * 1.1 ||
          temperature < cropRequirement.minTemp * 0.9) {
        score *= 0.6;
      }

      // Cap score between 0-100
      score = score.clamp(0, 100);

      // Store the scored crop
      scoredCrops.add({
        'crop': crop,
        'score': score,
        'metadata': cropMetadata,
        'info': cropInfo,
        'soilPH': cropSoilPH,
      });
    }

    // Sort by score
    scoredCrops.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Create CropRecommendation objects
    _integratedRecommendations = scoredCrops
        .where((item) => (item['score'] as double) > 40)
        .take(10)
        .map((item) {
      final crop = item['crop'] as Crop;
      final score = item['score'] as double;
      final metadata = item['metadata'] as Map<String, dynamic>;
      final cropInfo = item['info'] as Map<String, dynamic>;
      final cropSoilPH = item['soilPH'] as Map<String, dynamic>;

      return CropRecommendation(
        crop: crop,
        score: score.round(),
        suitabilityLevel: _getSuitabilityLevel(score),
        reasons: _getRecommendationReasons(
          crop,
          metadata,
          cropInfo,
          cropSoilPH,
          score,
          temperature,
          annualRainfall,
          soilPH,
          soilType,
          season,
        ),
        plantingAdvice: _getPlantingAdvice(
          crop,
          metadata,
          cropInfo,
          cropSoilPH,
          season,
          temperature,
          precipitation,
          soilPH,
          soilType,
        ),
        riskFactors: _getRiskFactors(
          crop,
          metadata,
          cropInfo,
          temperature,
          precipitation,
          soilPH,
          soilType,
          humidity,
          windSpeed,
        ),
        estimatedYield: _estimateYield(
          crop,
          metadata,
          score,
          soilAnalysis,
        ),
        intercroppingOptions: _getIntercroppingOptions(crop),
      );
    })
        .toList();
  }

  // Calculate base suitability score
  double _calculateBaseSuitabilityScore({
    required Crop crop,
    required Map<String, dynamic> cropInfo,
    required double temperature,
    required double annualRainfall,
    required double soilPH,
    required String soilType,
  }) {
    double score = 0.0;

    // Temperature suitability (40% weight)
    final tempMin = cropInfo['temperature']?['min'] ?? 0.0;
    final tempMax = cropInfo['temperature']?['max'] ?? 40.0;
    final tempOptimal = cropInfo['temperature']?['optimal'] ?? 25.0;

    if (temperature >= tempMin && temperature <= tempMax) {
      final tempRange = tempMax - tempMin;
      final tempDiff = (temperature - tempOptimal).abs();
      final tempScore = 40.0 * (1.0 - (tempDiff / (tempRange / 2)));
      score += tempScore.clamp(0, 40);
    }

    // Rainfall suitability (30% weight)
    final rainMin = cropInfo['rainfall']?['min'] ?? 0.0;
    final rainMax = cropInfo['rainfall']?['max'] ?? 2000.0;
    final rainOptimal = cropInfo['rainfall']?['optimal'] ?? 750.0;

    if (annualRainfall >= rainMin && annualRainfall <= rainMax) {
      final rainRange = rainMax - rainMin;
      final rainDiff = (annualRainfall - rainOptimal).abs();
      final rainScore = 30.0 * (1.0 - (rainDiff / (rainRange / 2)));
      score += rainScore.clamp(0, 30);
    }

    // Soil pH suitability (15% weight) - FIXED: Using cropSoilPH
    final soilPHData = cropInfo['soilPH'] ?? {'min': 5.5, 'max': 7.5, 'optimal': 6.5};
    final phMin = soilPHData['min'] ?? 5.5;
    final phMax = soilPHData['max'] ?? 7.5;
    final phOptimal = soilPHData['optimal'] ?? 6.5;

    if (soilPH >= phMin && soilPH <= phMax) {
      final phRange = phMax - phMin;
      final phDiff = (soilPH - phOptimal).abs();
      final phScore = 15.0 * (1.0 - (phDiff / (phRange / 2)));
      score += phScore.clamp(0, 15);
    }

    // Soil type suitability (15% weight)
    final preferredSoilTypes = List<String>.from(cropInfo['soilTypes'] ?? []);
    if (preferredSoilTypes.any((type) => soilType.toLowerCase().contains(type.toLowerCase()))) {
      score += 15.0;
    } else if (soilType.isNotEmpty) {
      score += 7.5;
    }

    return score;
  }

  // Calculate drought bonus - FIXED: Now it's defined
  double _calculateDroughtBonus(String droughtTolerance) {
    return {
      'Very High': 25.0,
      'High': 15.0,
      'Medium-High': 10.0,
      'Medium': 5.0,
      'Medium-Low': 0.0,
      'Low': -10.0,
    }[droughtTolerance] ?? 0.0;
  }

  // Calculate season score
  double _calculateSeasonScore(Crop crop, String currentSeason, double latitude) {
    final cropSeason = crop.season;

    if (cropSeason == 'Year Round') return 1.0;

    // Check for exact match
    if (cropSeason.contains(currentSeason)) return 1.0;

    // Check for partial matches
    if (currentSeason.contains('Rains') && cropSeason.contains('Rain')) {
      return 0.9;
    }

    final droughtTolerance = crop.soilRequirements['droughtTolerance'] ?? 'Medium';
    if (currentSeason.contains('Dry') && droughtTolerance.contains('High')) {
      return 0.8;
    }

    return 0.5;
  }

  // Calculate weather adjustment
  double _calculateWeatherAdjustment({
    required Crop crop,
    required Map<String, dynamic> cropInfo,
    required Map<String, dynamic> cropMetadata,
    required double temperature,
    required double precipitation,
    required double humidity,
    required double solarRadiation,
    required double windSpeed,
    required double soilMoisture,
  }) {
    double adjustment = 0;
    final tempOptimal = cropInfo['temperature']?['optimal'] ?? 24.0;
    final rainfallOptimal = cropInfo['rainfall']?['optimal'] ?? 600.0;
    final droughtTolerance = cropMetadata['droughtTolerance'] ?? 'Medium';

    // Temperature adjustment
    final tempDiff = (temperature - tempOptimal).abs();
    if (tempDiff < 2) adjustment += 5;
    else if (tempDiff < 5) adjustment += 2;
    else if (tempDiff > 10) adjustment -= 10;
    else if (tempDiff > 15) adjustment -= 20;

    // Precipitation adjustment
    final dailyRainfallOptimal = rainfallOptimal / 365;
    final rainRatio = precipitation / dailyRainfallOptimal;

    if (rainRatio >= 0.8 && rainRatio <= 1.2) adjustment += 5;
    else if (rainRatio >= 0.5 && rainRatio <= 1.5) adjustment += 2;
    else if (rainRatio < 0.3) {
      if (droughtTolerance.contains('Low')) adjustment -= 10;
      else if (droughtTolerance.contains('High')) adjustment -= 2;
    }
    else if (rainRatio > 2.0) adjustment -= 10;

    return adjustment;
  }

  // Calculate nutrient score - FIXED: Using cropSoilPH parameter
  double _calculateNutrientScore({
    required Crop crop,
    required Map<String, dynamic> cropInfo,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double organicMatter,
    required double soilPH,
    required Map<String, dynamic> cropSoilPH,
  }) {
    double score = 0;
    final nutrients = List<String>.from(cropInfo['nutrients'] ?? []);

    // Nitrogen score
    if (nutrients.contains('Nitrogen')) {
      if (nitrogen > 70) score += 15;
      else if (nitrogen > 50) score += 10;
      else if (nitrogen > 30) score += 5;
      else if (nitrogen < 20) score -= 10;
    }

    // Phosphorus score
    if (nutrients.contains('Phosphorus')) {
      if (phosphorus > 60) score += 15;
      else if (phosphorus > 40) score += 10;
      else if (phosphorus > 20) score += 5;
      else if (phosphorus < 10) score -= 10;
    }

    // Potassium score
    if (nutrients.contains('Potassium')) {
      if (potassium > 60) score += 15;
      else if (potassium > 40) score += 10;
      else if (potassium > 20) score += 5;
      else if (potassium < 10) score -= 10;
    }

    // Organic matter score
    if (organicMatter > 3.5) score += 10;
    else if (organicMatter > 2.5) score += 5;
    else if (organicMatter < 1.0) score -= 10;

    // pH adjustment - FIXED: Using cropSoilPH
    final phMin = cropSoilPH['min'] ?? 5.5;
    final phMax = cropSoilPH['max'] ?? 7.5;
    final phOptimal = cropSoilPH['optimal'] ?? 6.5;

    if (soilPH >= phMin && soilPH <= phMax) {
      final phDiff = (soilPH - phOptimal).abs();
      if (phDiff < 0.5) score += 5;
    } else {
      score -= 10;
    }

    return score;
  }

  // Get recommendation reasons - FIXED: Using cropSoilPH
  List<String> _getRecommendationReasons(
      Crop crop,
      Map<String, dynamic> cropMetadata,
      Map<String, dynamic> cropInfo,
      Map<String, dynamic> cropSoilPH,
      double score,
      double temperature,
      double annualRainfall,
      double soilPH,
      String soilType,
      String season,
      ) {
    final reasons = <String>[];

    // Temperature reason
    final tempMin = cropInfo['temperature']?['min'] ?? 0.0;
    final tempMax = cropInfo['temperature']?['max'] ?? 40.0;
    if (temperature >= tempMin && temperature <= tempMax) {
      reasons.add('Optimal temperature conditions');
    }

    // Rainfall reason
    final rainMin = cropInfo['rainfall']?['min'] ?? 0.0;
    final rainMax = cropInfo['rainfall']?['max'] ?? 2000.0;
    final rainOptimal = cropInfo['rainfall']?['optimal'] ?? 750.0;

    if (annualRainfall >= rainMin && annualRainfall <= rainMax) {
      final rainRange = rainMax - rainMin;
      final rainDiff = (annualRainfall - rainOptimal).abs();
      final rainfallMatch = 100 - (rainDiff / (rainRange / 2) * 100);

      if (rainfallMatch > 80) {
        reasons.add('Excellent rainfall match');
      } else if (rainfallMatch > 60) {
        reasons.add('Good rainfall conditions');
      }
    }

    // Soil pH reason - FIXED: Using cropSoilPH
    final phMin = cropSoilPH['min'] ?? 5.5;
    final phMax = cropSoilPH['max'] ?? 7.5;
    final phOptimal = cropSoilPH['optimal'] ?? 6.5;

    if (soilPH >= phMin && soilPH <= phMax) {
      final phRange = phMax - phMin;
      final phDiff = (soilPH - phOptimal).abs();
      final phMatch = 100 - (phDiff / (phRange / 2) * 100);

      if (phMatch > 85) {
        reasons.add('Ideal soil pH');
      }
    }

    // Soil type reason
    final preferredSoilTypes = List<String>.from(cropInfo['soilTypes'] ?? []);
    if (preferredSoilTypes.isNotEmpty &&
        preferredSoilTypes.any((type) => soilType.toLowerCase().contains(type.toLowerCase()))) {
      reasons.add('Compatible soil type');
    }

    // Season reason
    if (_calculateSeasonScore(crop, season, _currentLatitude ?? 0.0) > 0.8) {
      reasons.add('Perfect planting season');
    }

    // Importance from metadata
    if (cropMetadata['importance'] != null) {
      reasons.add(cropMetadata['importance'].toString());
    }

    // Drought tolerance
    final droughtTolerance = cropMetadata['droughtTolerance'] ?? 'Medium';
    if (annualRainfall < 600 && droughtTolerance.contains('High')) {
      reasons.add('Excellent drought tolerance');
    }

    // Market value
    final marketValue = cropMetadata['marketValue'] ?? 'Medium';
    if (marketValue == 'High' || marketValue == 'Very High') {
      reasons.add('High market value crop');
    }

    // Staple crops
    if (['Maize', 'Beans', 'Cassava'].contains(crop.name)) {
      reasons.add('Important staple crop in the region');
    }

    return reasons;
  }

  // Get planting advice - FIXED: Using cropSoilPH
  String _getPlantingAdvice(
      Crop crop,
      Map<String, dynamic> cropMetadata,
      Map<String, dynamic> cropInfo,
      Map<String, dynamic> cropSoilPH,
      String season,
      double temperature,
      double precipitation,
      double soilPH,
      String soilType,
      ) {
    final growingPeriod = cropMetadata['growingPeriod'] ?? 100;
    final droughtTolerance = cropMetadata['droughtTolerance'] ?? 'Medium';
    final waterRequirement = cropInfo['waterRequirement'] ?? 500.0;
    final phOptimal = cropSoilPH['optimal'] ?? 6.5;

    final advice = StringBuffer();

    // Timing advice
    if (season.contains('Rains')) {
      advice.write('Plant at the onset of rains for best establishment. ');
    } else if (season.contains('Dry')) {
      if (droughtTolerance.contains('High')) {
        advice.write('Can be planted in dry season with minimal irrigation. ');
      } else {
        advice.write('Requires irrigation if planted in dry season. ');
      }
    }

    // Spacing advice
    final cropName = crop.name.toLowerCase();
    if (cropName.contains('maize') || cropName.contains('sorghum')) {
      advice.write('Spacing: 75cm rows × 30cm plants. ');
    } else if (cropName.contains('bean') || cropName.contains('pea')) {
      advice.write('Spacing: 45cm rows × 15cm plants. ');
    } else if (cropName.contains('potato') || cropName.contains('cassava')) {
      advice.write('Spacing: 90cm rows × 30cm plants. ');
    }

    // Water management
    final dailyWaterNeed = waterRequirement / 365;
    if (precipitation < dailyWaterNeed * 0.7) {
      advice.write('Additional irrigation needed. ');
    } else if (precipitation > dailyWaterNeed * 1.3) {
      advice.write('Ensure good drainage to prevent waterlogging. ');
    }

    // Soil preparation
    if (soilPH < phOptimal * 0.9) {
      advice.write('Apply lime to raise soil pH before planting. ');
    } else if (soilPH > phOptimal * 1.1) {
      advice.write('Add sulfur or organic matter to lower soil pH. ');
    }

    // Fertilizer advice
    final nutrients = List<String>.from(cropInfo['nutrients'] ?? []);
    if (nutrients.contains('Nitrogen')) {
      advice.write('Apply nitrogen fertilizer at planting and 4 weeks after. ');
    }

    // Harvest timeline
    advice.write('Expected harvest in $growingPeriod days. ');

    return advice.toString();
  }

  // Get risk factors
  List<String> _getRiskFactors(
      Crop crop,
      Map<String, dynamic> cropMetadata,
      Map<String, dynamic> cropInfo,
      double temperature,
      double precipitation,
      double soilPH,
      String soilType,
      double humidity,
      double windSpeed,
      ) {
    final risks = <String>[];
    final tempMin = cropInfo['temperature']?['min'] ?? 0.0;
    final tempMax = cropInfo['temperature']?['max'] ?? 40.0;
    final rainOptimal = cropInfo['rainfall']?['optimal'] ?? 600.0;
    final pestRisk = cropMetadata['pestRisk'] ?? 'Medium';
    final cropSoilPH = cropInfo['soilPH'] ?? {'min': 5.5, 'max': 7.5, 'optimal': 6.5};
    final phMin = cropSoilPH['min'] ?? 5.5;
    final phMax = cropSoilPH['max'] ?? 7.5;

    // Temperature risks
    if (temperature > tempMax * 1.1) {
      risks.add('High temperature stress may reduce yield');
    }
    if (temperature < tempMin * 0.9) {
      risks.add('Low temperature may slow growth');
    }

    // Rainfall risks
    final dailyRainfallOptimal = rainOptimal / 365;
    if (precipitation > dailyRainfallOptimal * 1.5) {
      risks.add('Excessive rainfall may cause waterlogging and diseases');
    }
    if (precipitation < dailyRainfallOptimal * 0.7) {
      risks.add('Insufficient rainfall, irrigation required');
    }

    // Soil risks
    if (soilPH < phMin * 0.9 || soilPH > phMax * 1.1) {
      risks.add('Soil pH outside optimal range may affect nutrient uptake');
    }

    // Pest/disease risks
    if (pestRisk == 'High' || pestRisk == 'Very High') {
      risks.add('High pest/disease pressure expected');
    }

    if (precipitation > 10 && humidity > 80) {
      risks.add('High humidity increases fungal disease risk');
    }

    return risks;
  }

  // Estimate yield
  Map<String, dynamic> _estimateYield(
      Crop crop,
      Map<String, dynamic> cropMetadata,
      double score,
      SoilData? soilAnalysis,
      ) {
    final baseYield = (cropMetadata['yieldPotential'] as double?) ?? 5.0;

    // Adjust yield based on score
    double yieldMultiplier = score / 100;

    // Adjust based on soil quality
    if (soilAnalysis != null) {
      if (soilAnalysis.organicMatter != null && soilAnalysis.organicMatter! > 3.0) {
        yieldMultiplier *= 1.2;
      }
    }

    final estimatedYield = baseYield * yieldMultiplier;

    return {
      'estimated': estimatedYield,
      'unit': 'tons/hectare',
      'confidence': score > 70 ? 'High' : score > 50 ? 'Medium' : 'Low',
    };
  }

  // Get intercropping options
  List<Map<String, dynamic>> _getIntercroppingOptions(Crop crop) {
    final intercroppingMap = {
      'Maize': [
        {'crop': 'Beans', 'benefit': 'Nitrogen fixation', 'spacing': 'Between maize rows'},
      ],
      'Beans': [
        {'crop': 'Maize', 'benefit': 'Provides support for climbing', 'spacing': 'Alternate rows'},
      ],
      'Cassava': [
        {'crop': 'Beans', 'benefit': 'Early harvest before cassava matures', 'spacing': 'Between cassava'},
      ],
    };

    return intercroppingMap[crop.name] ?? [];
  }

  // Helper methods
  String _getCurrentSeason(double latitude) {
    final month = DateTime.now().month;
    final isSouthernHemisphere = latitude < 0;

    if (isSouthernHemisphere) {
      if (month >= 9 && month <= 11) return 'Spring';
      if (month >= 12 || month <= 2) return 'Summer';
      if (month >= 3 && month <= 5) return 'Autumn';
      return 'Winter';
    }

    // Northern hemisphere (Kenya)
    if (month >= 3 && month <= 5) return 'Long Rains (March-May)';
    if (month >= 10 && month <= 12) return 'Short Rains (Oct-Dec)';
    if (month >= 6 && month <= 9) return 'Dry Season (June-Sept)';
    return 'Dry Season (Jan-Feb)';
  }

  String _determineSoilType(SoilData? soilAnalysis, double latitude, double longitude) {
    if (soilAnalysis?.soilType != null && soilAnalysis!.soilType!.isNotEmpty) {
      return soilAnalysis.soilType!;
    }

    // Default based on location in Kenya
    if (latitude > 0.5) return 'Sandy';
    if (latitude < -0.5) return 'Clay Loam';
    if (longitude > 36.5) return 'Sandy Loam';
    if (longitude < 35.0) return 'Volcanic';

    return 'Loamy';
  }

  double _estimateAltitude(double latitude) {
    if (latitude > 0.5) return 500.0;
    if (latitude < -0.5) return 1200.0;
    return 800.0;
  }

  double _calculateAltitudeFactor(double altitude) {
    if (altitude < 500) return 1.0;
    if (altitude < 1500) return 0.9;
    if (altitude < 2500) return 0.8;
    return 0.7;
  }

  String _getSuitabilityLevel(double score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 55) return 'Moderate';
    if (score >= 40) return 'Marginal';
    return 'Unsuitable';
  }

  // Local names helper
  Map<String, String> _getLocalNames(String cropName) {
    final Map<String, Map<String, String>> localNames = {
      'Maize': {'Swahili': 'Mahindi', 'Kikuyu': 'Mbembe', 'Luo': 'Oduma'},
      'Beans': {'Swahili': 'Maharage', 'Kikuyu': 'Mikoko', 'Luo': 'Mito'},
      'Cassava': {'Swahili': 'Muhogo', 'Luo': 'Mogo'},
    };
    return localNames[cropName] ?? {'Swahili': cropName};
  }

  // Regions helper
  List<String> _getRegionsForCropInKenya(String cropName) {
    final Map<String, List<String>> cropRegions = {
      'Maize': ['Rift Valley', 'Western Kenya', 'Nyanza', 'Central Kenya'],
      'Beans': ['Rift Valley', 'Central Kenya', 'Western Kenya', 'Eastern Kenya'],
      'Cassava': ['Coastal Kenya', 'Western Kenya', 'Lake Victoria Basin'],
    };
    return cropRegions[cropName] ?? ['Various regions across Kenya'];
  }

  // Load cached data
  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_fao_data');

    if (cachedData != null) {
      try {
        final data = json.decode(cachedData);
        _cropRequirements = (data['cropRequirements'] as List)
            .map((item) => CropRequirement.fromJson(item))
            .toList();
        _availableCrops = (data['availableCrops'] as List)
            .map((item) => Crop.fromJson(item))
            .toList();
        _soilData = Map<String, dynamic>.from(data['soilData'] ?? {});
        _waterData = Map<String, dynamic>.from(data['waterData'] ?? {});
        _currentRegion = data['currentRegion'] ?? 'Kenya';
        _lastFetchTime = DateTime.tryParse(data['lastFetchTime'] ?? '');

        // Load metadata
        if (data['cropMetadata'] != null) {
          final metadata = Map<String, dynamic>.from(data['cropMetadata']);
          for (final entry in metadata.entries) {
            _cropMetadata[entry.key] = Map<String, dynamic>.from(entry.value);
          }
        }

        notifyListeners();
      } catch (e) {
        print('Error loading cached FAO data: $e');
      }
    }
  }

  // Cache data
  Future<void> _cacheData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'cropRequirements': _cropRequirements.map((c) => c.toJson()).toList(),
      'availableCrops': _availableCrops.map((c) => c.toJson()).toList(),
      'soilData': _soilData,
      'waterData': _waterData,
      'currentRegion': _currentRegion,
      'lastFetchTime': _lastFetchTime?.toIso8601String(),
      'cropMetadata': _cropMetadata,
    };
    await prefs.setString('cached_fao_data', json.encode(data));
  }

  // Cache analysis results
  Future<void> _cacheAnalysisResults() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'lastAnalysis': {
        'timestamp': DateTime.now().toIso8601String(),
        'recommendations': _integratedRecommendations.map((r) => r.toJson()).toList(),
        'summary': _analysisSummary,
        'weather': _currentWeather?.toJson(),
        'soil': _currentSoilData?.toJson(),
      },
    };
    await prefs.setString('last_fao_analysis', json.encode(data));
  }

  // Load last analysis
  Future<void> loadLastAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('last_fao_analysis');

    if (cachedData != null) {
      try {
        final data = json.decode(cachedData);
        final lastAnalysis = data['lastAnalysis'];

        if (lastAnalysis != null) {
          _integratedRecommendations = (lastAnalysis['recommendations'] as List)
              .map((item) => CropRecommendation.fromJson(item))
              .toList();
          _analysisSummary = Map<String, dynamic>.from(lastAnalysis['summary'] ?? {});

          if (lastAnalysis['weather'] != null) {
            _currentWeather = WeatherData.fromJson(lastAnalysis['weather']);
          }
          if (lastAnalysis['soil'] != null) {
            _currentSoilData = SoilData.fromJson(lastAnalysis['soil']);
          }

          notifyListeners();
        }
      } catch (e) {
        print('Error loading last analysis: $e');
      }
    }
  }

  // Load Kenyan soil data
  Future<void> _loadKenyanSoilData() async {
    _soilData = {
      'volcanic': {
        'waterRetention': 'High',
        'drainage': 'Good',
        'fertility': 'Very High',
        'regions': ['Central Kenya', 'Rift Valley highlands'],
        'commonCrops': ['Irish Potatoes', 'Cabbage', 'Carrots'],
      },
      'sandyLoam': {
        'waterRetention': 'Medium-Low',
        'drainage': 'Good',
        'fertility': 'Medium',
        'regions': ['Coastal Kenya', 'Eastern lowlands'],
        'commonCrops': ['Cassava', 'Cowpeas', 'Green Grams'],
      },
    };
  }

  // Load Kenyan water data
  Future<void> _loadKenyanWaterData() async {
    _waterData = {
      'rainfallPatterns': {
        'longRains': 'March to May',
        'shortRains': 'October to December',
      },
      'cropCoefficients': {
        'Maize': 1.1,
        'Beans': 0.95,
        'Cassava': 1.05,
      },
    };
  }

  // Generate analysis summary
  void _generateAnalysisSummary() {
    if (_integratedRecommendations.isEmpty || _currentWeather == null) return;

    final topCrop = _integratedRecommendations.first;
    final weather = _currentWeather!;
    final season = _getCurrentSeason(_currentLatitude ?? 0.0);

    _analysisSummary = {
      'timestamp': DateTime.now().toIso8601String(),
      'location': {
        'region': _currentRegion,
        'latitude': _currentLatitude,
        'longitude': _currentLongitude,
        'season': season,
      },
      'weatherConditions': {
        'temperature': weather.temperature,
        'precipitation': weather.precipitation,
        'humidity': weather.humidity,
      },
      'topRecommendations': _integratedRecommendations.take(3).map((rec) => {
        'crop': rec.crop.name,
        'score': rec.score,
        'suitability': rec.suitabilityLevel,
      }).toList(),
      'statistics': {
        'totalCropsAnalyzed': _availableCrops.length,
        'suitableCrops': _integratedRecommendations.length,
        'overallSuitability': _calculateOverallSuitability(),
      },
    };
  }

  String _calculateOverallSuitability() {
    if (_integratedRecommendations.isEmpty) return 'Poor';

    final avgScore = _integratedRecommendations
        .map((rec) => rec.score)
        .reduce((a, b) => a + b) / _integratedRecommendations.length;

    if (avgScore >= 75) return 'Excellent';
    if (avgScore >= 60) return 'Good';
    if (avgScore >= 45) return 'Moderate';
    return 'Poor';
  }

  // Simple recommendation method for compatibility
  List<String> recommendCrops(double temperature, double rainfall, String soilType, String season) {
    final recommendations = <String>[];

    for (final crop in _availableCrops) {
      final cropInfo = _faoCropCalendar[crop.name] ?? {};
      final tempMin = cropInfo['temperature']?['min'] ?? 0.0;
      final tempMax = cropInfo['temperature']?['max'] ?? 40.0;
      final rainMin = cropInfo['rainfall']?['min'] ?? 0.0;
      final rainMax = cropInfo['rainfall']?['max'] ?? 2000.0;

      final isTempSuitable = temperature >= tempMin && temperature <= tempMax;
      final isRainSuitable = rainfall >= rainMin && rainfall <= rainMax;
      final isSeasonSuitable = crop.season.contains(season) || crop.season == 'Year Round';

      if (isTempSuitable && isRainSuitable && isSeasonSuitable) {
        recommendations.add(crop.name);
      }
    }

    return recommendations;
  }

  void clearData() {
    _cropRequirements.clear();
    _availableCrops.clear();
    _integratedRecommendations.clear();
    _cropMetadata.clear();
    _soilData.clear();
    _waterData.clear();
    _analysisSummary.clear();
    _currentWeather = null;
    _currentSoilData = null;
    _currentAnnualRainfall = null;
    _currentLatitude = null;
    _currentLongitude = null;
    _error = '';
    notifyListeners();
  }
}

// CropRecommendation class
class CropRecommendation {
  final Crop crop;
  final int score;
  final String suitabilityLevel;
  final List<String> reasons;
  final String plantingAdvice;
  final List<String> riskFactors;
  final Map<String, dynamic> estimatedYield;
  final List<Map<String, dynamic>> intercroppingOptions;

  CropRecommendation({
    required this.crop,
    required this.score,
    required this.suitabilityLevel,
    required this.reasons,
    required this.plantingAdvice,
    required this.riskFactors,
    required this.estimatedYield,
    required this.intercroppingOptions,
  });

  Map<String, dynamic> toJson() => {
    'crop': crop.toJson(),
    'score': score,
    'suitabilityLevel': suitabilityLevel,
    'reasons': reasons,
    'plantingAdvice': plantingAdvice,
    'riskFactors': riskFactors,
    'estimatedYield': estimatedYield,
    'intercroppingOptions': intercroppingOptions,
  };

  factory CropRecommendation.fromJson(Map<String, dynamic> json) {
    return CropRecommendation(
      crop: Crop.fromJson(json['crop']),
      score: json['score'] ?? 0,
      suitabilityLevel: json['suitabilityLevel'] ?? 'Unknown',
      reasons: List<String>.from(json['reasons'] ?? []),
      plantingAdvice: json['plantingAdvice'] ?? '',
      riskFactors: List<String>.from(json['riskFactors'] ?? []),
      estimatedYield: Map<String, dynamic>.from(json['estimatedYield'] ?? {}),
      intercroppingOptions: List<Map<String, dynamic>>.from(json['intercroppingOptions'] ?? []),
    );
  }
}