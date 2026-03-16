import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/soil_data.dart';

class SoilHiveProvider with ChangeNotifier {
  late Box<SoilData> _soilBox;
  late Box _settingsBox;

  bool _isLoading = false;
  String _error = '';

  bool get isLoading => _isLoading;
  String get error => _error;

  SoilHiveProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      _soilBox = Hive.box<SoilData>('soilData');
      _settingsBox = Hive.box('soilSettings');
    } catch (e) {
      _error = 'Hive initialization error: $e';
    }
  }

  // Save soil data with additional parameters - FIXED VERSION
  Future<void> saveSoilData(SoilData data) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _soilBox.add(data);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save soil data with nutrient parameters - FIXED VERSION
  Future<void> saveSoilDataWithNutrients({
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
  }) async {
    // Parse latitude and longitude from location string
    double latitude = 0.0;
    double longitude = 0.0;

    try {
      // Extract coordinates from location string
      // Expected formats:
      // 1. "Lat: 28.6139, Lng: 77.2090"
      // 2. "28.6139, 77.2090"
      // 3. "28.6139°, 77.2090°"

      String cleanLocation = location.replaceAll('°', '').replaceAll('Lat:', '').replaceAll('Lng:', '');
      final parts = cleanLocation.split(',').map((s) => s.trim()).toList();

      if (parts.length >= 2) {
        latitude = double.tryParse(parts[0]) ?? 0.0;
        longitude = double.tryParse(parts[1]) ?? 0.0;
      }
    } catch (e) {
      // Use default values if parsing fails
      latitude = 0.0;
      longitude = 0.0;
    }

    // Create the SoilData object using the correct constructor
    final data = SoilData.complete(
      date: date,
      latitude: latitude,
      longitude: longitude,
      location: location,

      // Soil properties
      soilType: soilType,

      // Nutrients
      pH: pH,
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      organicMatter: organicMatter,
      salinity: salinity,

      // Physical measurements
      soilMoisture: soilMoisture,
      soilTemperature: soilTemperature,

      // Weather measurements
      airTemperature: null, // Not provided
      precipitation: precipitation,
      humidity: null, // Not provided
      solarRadiation: solarRadiation,
      windSpeed: null, // Not provided

      // Metadata
      source: 'Manual Entry',
      notes: notes,
    );

    await saveSoilData(data);
  }

  // Alternative method using the fromFields factory (if you added it)
  Future<void> saveSoilDataWithNutrientsAlternative({
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
  }) async {
    try {
      // Use the fromFields factory if available
      final data = SoilData.fromFields(
        date: date,
        soilMoisture: soilMoisture,
        soilTemperature: soilTemperature,
        solarRadiation: solarRadiation,
        precipitation: precipitation,
        location: location,
        pH: pH,
        magnesium: magnesium,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        calcium: calcium,
        organicMatter: organicMatter,
        salinity: salinity,
        soilType: soilType,
        notes: notes,
        source: 'Manual Entry',
      );

      await saveSoilData(data);
    } catch (e) {
      // Fallback to the complete method
      await saveSoilDataWithNutrients(
        date: date,
        soilMoisture: soilMoisture,
        soilTemperature: soilTemperature,
        solarRadiation: solarRadiation,
        precipitation: precipitation,
        location: location,
        pH: pH,
        magnesium: magnesium,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        calcium: calcium,
        organicMatter: organicMatter,
        salinity: salinity,
        soilType: soilType,
        notes: notes,
      );
    }
  }

  // Get all soil data
  List<SoilData> getAllSoilData() {
    return _soilBox.values.toList();
  }

  // Get soil data by location
  List<SoilData> getSoilDataByLocation(String location) {
    return _soilBox.values
        .where((data) => data.location.toLowerCase().contains(location.toLowerCase()))
        .toList();
  }

  // Get last N days of soil data
  List<SoilData> getLastNDays(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _soilBox.values
        .where((data) => data.date.isAfter(cutoffDate))
        .toList();
  }

  // Get averages for basic parameters
  Map<String, double> getAverages(List<SoilData> data) {
    if (data.isEmpty) {
      return {
        'moisture': 0.0,
        'temperature': 0.0,
        'solarRadiation': 0.0,
        'precipitation': 0.0,
        'pH': 0.0,
        'magnesium': 0.0,
        'nitrogen': 0.0,
        'phosphorus': 0.0,
        'potassium': 0.0,
        'calcium': 0.0,
        'organicMatter': 0.0,
      };
    }

    double moistureSum = 0;
    double temperatureSum = 0;
    double solarRadiationSum = 0;
    int solarRadiationCount = 0;
    double precipitationSum = 0;
    int precipitationCount = 0;
    double phSum = 0;
    int phCount = 0;
    double magnesiumSum = 0;
    int magnesiumCount = 0;
    double nitrogenSum = 0;
    int nitrogenCount = 0;
    double phosphorusSum = 0;
    int phosphorusCount = 0;
    double potassiumSum = 0;
    int potassiumCount = 0;
    double calciumSum = 0;
    int calciumCount = 0;
    double organicMatterSum = 0;
    int organicMatterCount = 0;

    for (var d in data) {
      // Handle nullable fields
      if (d.soilMoisture != null) {
        moistureSum += d.soilMoisture!;
      }

      if (d.soilTemperature != null) {
        temperatureSum += d.soilTemperature!;
      }

      if (d.solarRadiation != null) {
        solarRadiationSum += d.solarRadiation!;
        solarRadiationCount++;
      }

      if (d.precipitation != null) {
        precipitationSum += d.precipitation!;
        precipitationCount++;
      }

      if (d.pH != null) {
        phSum += d.pH!;
        phCount++;
      }
      if (d.magnesium != null) {
        magnesiumSum += d.magnesium!;
        magnesiumCount++;
      }
      if (d.nitrogen != null) {
        nitrogenSum += d.nitrogen!;
        nitrogenCount++;
      }
      if (d.phosphorus != null) {
        phosphorusSum += d.phosphorus!;
        phosphorusCount++;
      }
      if (d.potassium != null) {
        potassiumSum += d.potassium!;
        potassiumCount++;
      }
      if (d.calcium != null) {
        calciumSum += d.calcium!;
        calciumCount++;
      }
      if (d.organicMatter != null) {
        organicMatterSum += d.organicMatter!;
        organicMatterCount++;
      }
    }

    int dataCount = data.length;
    int moistureCount = data.where((d) => d.soilMoisture != null).length;
    int temperatureCount = data.where((d) => d.soilTemperature != null).length;

    return {
      'moisture': moistureCount > 0 ? moistureSum / moistureCount : 0.0,
      'temperature': temperatureCount > 0 ? temperatureSum / temperatureCount : 0.0,
      'solarRadiation': solarRadiationCount > 0 ? solarRadiationSum / solarRadiationCount : 0.0,
      'precipitation': precipitationCount > 0 ? precipitationSum / precipitationCount : 0.0,
      'pH': phCount > 0 ? phSum / phCount : 0.0,
      'magnesium': magnesiumCount > 0 ? magnesiumSum / magnesiumCount : 0.0,
      'nitrogen': nitrogenCount > 0 ? nitrogenSum / nitrogenCount : 0.0,
      'phosphorus': phosphorusCount > 0 ? phosphorusSum / phosphorusCount : 0.0,
      'potassium': potassiumCount > 0 ? potassiumSum / potassiumCount : 0.0,
      'calcium': calciumCount > 0 ? calciumSum / calciumCount : 0.0,
      'organicMatter': organicMatterCount > 0 ? organicMatterSum / organicMatterCount : 0.0,
    };
  }

  // Get nutrient analysis
  Map<String, dynamic> getNutrientAnalysis(List<SoilData> data) {
    final averages = getAverages(data);

    String getNutrientStatus(double value, String nutrient) {
      switch (nutrient) {
        case 'pH':
          if (value < 6.0) return 'Acidic';
          if (value > 7.5) return 'Alkaline';
          return 'Optimal';
        case 'nitrogen':
          if (value < 20) return 'Low';
          if (value > 60) return 'High';
          return 'Optimal';
        case 'phosphorus':
          if (value < 15) return 'Low';
          if (value > 50) return 'High';
          return 'Optimal';
        case 'potassium':
          if (value < 100) return 'Low';
          if (value > 250) return 'High';
          return 'Optimal';
        case 'magnesium':
          if (value < 50) return 'Low';
          if (value > 150) return 'High';
          return 'Optimal';
        case 'calcium':
          if (value < 400) return 'Low';
          if (value > 1000) return 'High';
          return 'Optimal';
        case 'organicMatter':
          if (value < 2.0) return 'Low';
          if (value > 5.0) return 'High';
          return 'Optimal';
        default:
          return 'Normal';
      }
    }

    return {
      'averages': averages,
      'pHStatus': getNutrientStatus(averages['pH'] ?? 0.0, 'pH'),
      'nitrogenStatus': getNutrientStatus(averages['nitrogen'] ?? 0.0, 'nitrogen'),
      'phosphorusStatus': getNutrientStatus(averages['phosphorus'] ?? 0.0, 'phosphorus'),
      'potassiumStatus': getNutrientStatus(averages['potassium'] ?? 0.0, 'potassium'),
      'magnesiumStatus': getNutrientStatus(averages['magnesium'] ?? 0.0, 'magnesium'),
      'calciumStatus': getNutrientStatus(averages['calcium'] ?? 0.0, 'calcium'),
      'organicMatterStatus': getNutrientStatus(averages['organicMatter'] ?? 0.0, 'organicMatter'),
    };
  }

  // Get soil health summary
  Map<String, dynamic> getSoilHealthSummary(List<SoilData> data) {
    final analysis = getNutrientAnalysis(data);
    final averages = analysis['averages'] as Map<String, double>;

    int optimalCount = 0;
    int totalCount = 0;

    // Count optimal parameters
    for (final status in analysis.values) {
      if (status is String) {
        totalCount++;
        if (status == 'Optimal' || status == 'Normal') {
          optimalCount++;
        }
      }
    }

    double healthScore = totalCount > 0 ? (optimalCount / totalCount * 100) : 0.0;

    String getHealthRating(double score) {
      if (score >= 80) return 'Excellent';
      if (score >= 60) return 'Good';
      if (score >= 40) return 'Fair';
      if (score >= 20) return 'Poor';
      return 'Very Poor';
    }

    return {
      'healthScore': healthScore,
      'healthRating': getHealthRating(healthScore),
      'optimalParameters': optimalCount,
      'totalParameters': totalCount,
      'analysis': analysis,
    };
  }

  // Clear all data
  Future<void> clearAllData() async {
    await _soilBox.clear();
    notifyListeners();
  }

  // Export data as JSON
  Future<String> exportData() async {
    final data = getAllSoilData();
    final jsonList = data.map((d) => d.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // Import data from JSON
  Future<void> importData(String jsonString) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = jsonDecode(jsonString) as List;
      for (final item in data) {
        try {
          final soilData = SoilData.fromJson(item);
          await _soilBox.add(soilData);
        } catch (e) {
          print('Error importing item: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to import data: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Save settings
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
    notifyListeners();
  }

  // Get setting
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final allData = getAllSoilData();

    if (allData.isEmpty) {
      return {
        'totalRecords': 0,
        'oldestDate': null,
        'newestDate': null,
        'locations': [],
        'dataCompleteness': 0.0,
      };
    }

    final dates = allData.map((d) => d.date).toList();
    dates.sort();

    final locations = allData.map((d) => d.location).toSet().toList();

    // Calculate data completeness
    int totalFields = 0;
    int populatedFields = 0;

    for (var data in allData) {
      final fields = [
        data.soilMoisture,
        data.soilTemperature,
        data.pH,
        data.nitrogen,
        data.phosphorus,
        data.potassium,
        data.organicMatter,
      ];

      totalFields += fields.length;
      populatedFields += fields.where((f) => f != null).length;
    }

    double completeness = totalFields > 0 ? (populatedFields / totalFields * 100) : 0.0;

    return {
      'totalRecords': allData.length,
      'oldestDate': dates.first,
      'newestDate': dates.last,
      'locations': locations,
      'dataCompleteness': completeness,
    };
  }

  // Search soil data
  List<SoilData> searchSoilData({
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? minPH,
    double? maxPH,
    double? minMoisture,
    double? maxMoisture,
  }) {
    var results = getAllSoilData();

    if (location != null && location.isNotEmpty) {
      results = results.where((d) =>
          d.location.toLowerCase().contains(location.toLowerCase())
      ).toList();
    }

    if (startDate != null) {
      results = results.where((d) => d.date.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      results = results.where((d) => d.date.isBefore(endDate)).toList();
    }

    if (minPH != null) {
      results = results.where((d) => d.pH != null && d.pH! >= minPH).toList();
    }

    if (maxPH != null) {
      results = results.where((d) => d.pH != null && d.pH! <= maxPH).toList();
    }

    if (minMoisture != null) {
      results = results.where((d) => d.soilMoisture != null && d.soilMoisture! >= minMoisture).toList();
    }

    if (maxMoisture != null) {
      results = results.where((d) => d.soilMoisture != null && d.soilMoisture! <= maxMoisture).toList();
    }

    return results;
  }
}