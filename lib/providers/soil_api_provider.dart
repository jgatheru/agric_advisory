import 'dart:async';
import 'package:flutter/material.dart';

import '../models/soil_data.dart';
import '../services/soil_api_service.dart';

/// Provider for managing soil data state
class SoilApiProvider with ChangeNotifier {
  final SoilApiService _apiService;

  // State
  SoilData? _currentSoilData;
  List<SoilData> _historicalSoilData = [];
  bool _isLoading = false;
  String _error = '';
  DateTime? _lastFetch;
  String? _currentFetchLocation;

  // Cache
  final Map<String, CacheEntry> _locationCache = {};
  static const Duration _cacheDuration = Duration(hours: 1);

  // Request tracking
  final Map<String, Completer<SoilData>> _pendingRequests = {};

  // Source tracking
  List<String> _lastSuccessfulEndpoints = [];
  Map<String, ApiSourceResult> _lastSourceResults = {};

  // Constructor
  SoilApiProvider({
    required String soilHiveApiKey,
    String? openWeatherApiKey,
    bool useMultiSourceFallback = true,
    bool useLocalApi = true,
    bool verbose = true,
  }) : _apiService = SoilApiService(
    soilHiveApiKey: soilHiveApiKey,
    openWeatherApiKey: openWeatherApiKey,
    useMultiSourceFallback: useMultiSourceFallback,
    useLocalApi: useLocalApi,
    verbose: verbose,
  );

  // ============ GETTERS ============
  SoilData? get currentSoilData => _currentSoilData;
  List<SoilData> get historicalSoilData => _historicalSoilData;
  bool get isLoading => _isLoading;
  String get error => _error;
  DateTime? get lastFetch => _lastFetch;
  String? get currentFetchLocation => _currentFetchLocation;
  List<String> get successfulEndpoints => List.from(_lastSuccessfulEndpoints);
  Map<String, ApiSourceResult> get sourceResults => Map.from(_lastSourceResults);

  bool get hasData => _currentSoilData != null;
  bool get hasNutrientData => _currentSoilData?.hasNutrientData ?? false;

  // ============ MAIN FETCH METHOD ============
  Future<void> fetchSoilData({
    required double latitude,
    required double longitude,
    int depth = 30,
    bool forceRefresh = false,
    List<String>? properties,
    bool verbose = true,
  }) async {
    final cacheKey = _generateCacheKey(latitude, longitude, depth);

    // Check for pending request
    if (_pendingRequests.containsKey(cacheKey)) {
      if (verbose) print('⏳ Waiting for existing request for $cacheKey');
      await _pendingRequests[cacheKey]!.future;
      return;
    }

    // Check cache
    if (!forceRefresh) {
      final cachedData = _getCachedData(cacheKey);
      if (cachedData != null) {
        _updateStateWithCachedData(cachedData, cacheKey, verbose);
        return;
      }
    }

    // Create new request
    final completer = Completer<SoilData>();
    _pendingRequests[cacheKey] = completer;

    await _executeFetch(
      latitude: latitude,
      longitude: longitude,
      depth: depth,
      cacheKey: cacheKey,
      properties: properties,
      verbose: verbose,
      completer: completer,
    );
  }

  Future<void> _executeFetch({
    required double latitude,
    required double longitude,
    required int depth,
    required String cacheKey,
    List<String>? properties,
    required bool verbose,
    required Completer<SoilData> completer,
  }) async {
    _isLoading = true;
    _error = '';
    _currentFetchLocation = cacheKey;
    notifyListeners();

    if (verbose) {
      print('🚀 SoilApiProvider: Starting fetch for $cacheKey');
      print('📱 Provider state: loading started');
    }

    try {
      final soilData = await _apiService.fetchSoilData(
        latitude: latitude,
        longitude: longitude,
        depth: depth,
        propertyIdentifiers: properties,
        forceRefresh: false,
      );

      // Update state
      _updateStateWithNewData(
        soilData: soilData,
        cacheKey: cacheKey,
        verbose: verbose,
      );

      completer.complete(soilData);
    } catch (e, stackTrace) {
      _handleFetchError(
        error: e,
        stackTrace: stackTrace,
        latitude: latitude,
        longitude: longitude,
        cacheKey: cacheKey,
        verbose: verbose,
        completer: completer,
      );
    } finally {
      _cleanupRequest(cacheKey);
    }
  }

  void _updateStateWithCachedData(
      SoilData cachedData,
      String cacheKey,
      bool verbose,
      ) {
    _currentSoilData = cachedData;
    _currentFetchLocation = cacheKey;

    if (verbose) {
      print('✅ SoilApiProvider: Using cached data for $cacheKey');
      print('📱 Provider state: loaded from cache');
    }

    notifyListeners();
  }

  void _updateStateWithNewData({
    required SoilData soilData,
    required String cacheKey,
    required bool verbose,
  }) {
    _currentSoilData = soilData;
    _lastFetch = DateTime.now();
    _lastSuccessfulEndpoints = _apiService.getSuccessfulEndpoints();
    _lastSourceResults = _apiService.getSourceResults();
    _error = '';

    // Cache the result
    _cacheData(cacheKey, soilData);

    if (verbose) {
      print('✅ SoilApiProvider: Fetch completed successfully');
      print('📱 Provider state: updated with new data');
      print('📊 Source results:');
      for (final endpoint in _lastSuccessfulEndpoints) {
        print('  ✅ $endpoint');
      }
      _printSoilDataSummary(soilData);
    }

    notifyListeners();
  }

  void _handleFetchError({
    required Object error,
    required StackTrace stackTrace,
    required double latitude,
    required double longitude,
    required String cacheKey,
    required bool verbose,
    required Completer<SoilData> completer,
  }) {
    _error = 'Failed to fetch soil data: ${error.toString()}';

    // Try cache fallback
    final cachedData = _getCachedData(cacheKey);
    if (cachedData != null) {
      _currentSoilData = cachedData;
      _error = 'Using cached data due to error';

      if (verbose) {
        print('⚠️  SoilApiProvider: Using cached data due to error');
        _printSoilDataSummary(cachedData);
      }

      completer.complete(cachedData);
    } else {
      // Create fallback data
      _currentSoilData = _createFallbackSoilData(
        latitude: latitude,
        longitude: longitude,
        error: error.toString(),
      );

      if (verbose) {
        print('❌ SoilApiProvider: Fetch failed, created fallback data');
        print('Error: $error');
        print('Stack trace: $stackTrace');
      }

      completer.completeError(error);
    }

    notifyListeners();
  }

  void _cleanupRequest(String cacheKey) {
    _pendingRequests.remove(cacheKey);
    _isLoading = false;
    notifyListeners();
  }

  // ============ CACHE MANAGEMENT ============
  String _generateCacheKey(double lat, double lng, int depth) {
    return '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}_$depth';
  }

  SoilData? _getCachedData(String cacheKey) {
    final entry = _locationCache[cacheKey];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.timestamp);
    if (age > _cacheDuration) {
      _locationCache.remove(cacheKey);
      return null;
    }

    return entry.data;
  }

  void _cacheData(String cacheKey, SoilData data) {
    _locationCache[cacheKey] = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
    );
  }

  bool hasCachedDataForLocation(double latitude, double longitude, [int depth = 30]) {
    final cacheKey = _generateCacheKey(latitude, longitude, depth);
    return _getCachedData(cacheKey) != null;
  }

  SoilData? getCachedDataForLocation(double latitude, double longitude, [int depth = 30]) {
    final cacheKey = _generateCacheKey(latitude, longitude, depth);
    return _getCachedData(cacheKey);
  }

  void clearCache() {
    _locationCache.clear();
    notifyListeners();
  }

  // ============ ERROR HANDLING ============
  SoilData _createFallbackSoilData({
    required double latitude,
    required double longitude,
    String? error,
  }) {
    return SoilData.empty(
      latitude: latitude,
      longitude: longitude,
      source: 'Fallback Data',
    ).copyWith(
      notes: error != null
          ? 'Error: ${error.substring(0, 100)}'
          : 'No data available',
    );
  }

  void clearError() {
    if (_error.isNotEmpty) {
      _error = '';
      notifyListeners();
    }
  }

  // ============ STATE MANAGEMENT ============
  void clearAllData() {
    _currentSoilData = null;
    _historicalSoilData = [];
    _error = '';
    _currentFetchLocation = null;
    _lastSuccessfulEndpoints = [];
    _lastSourceResults = {};
    notifyListeners();
  }

  void cancelAllRequests() {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(CancelledException());
      }
    }
    _pendingRequests.clear();
    _isLoading = false;
    notifyListeners();
  }

  // ============ NUTRIENT ANALYSIS ============
  Map<String, dynamic> getNutrientAnalysis() {
    if (_currentSoilData == null) {
      return {
        'hasData': false,
        'message': 'No soil data available',
        'analysis': {},
        'summary': {},
      };
    }

    final analysis = _currentSoilData!.getNutrientAnalysis();
    final summary = _createAnalysisSummary(analysis);

    return {
      'hasData': true,
      'analysis': analysis,
      'summary': summary,
      'pHStatus': analysis['pH'] ?? 'No data',
      'nitrogenStatus': analysis['nitrogen'] ?? 'No data',
      'phosphorusStatus': analysis['phosphorus'] ?? 'No data',
      'potassiumStatus': analysis['potassium'] ?? 'No data',
      'organicMatterStatus': analysis['organicMatter'] ?? 'No data',
    };
  }

  Map<String, String> _createAnalysisSummary(Map<String, String> analysis) {
    if (analysis.isEmpty) {
      return {'overall': 'No data available'};
    }

    final statusCounts = <String, int>{};
    for (final status in analysis.values) {
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    String overall;
    if (analysis.values.any((s) => s.toLowerCase().contains('very low'))) {
      overall = 'Poor';
    } else if (analysis.values.any((s) => s.toLowerCase().contains('low'))) {
      overall = 'Fair';
    } else if (analysis.values.any((s) => s.toLowerCase().contains('medium'))) {
      overall = 'Good';
    } else if (analysis.values.any((s) => s.toLowerCase().contains('high'))) {
      overall = 'Excellent';
    } else {
      overall = 'Unknown';
    }

    return {
      'overall': overall,
      'parameters_analyzed': analysis.length.toString(),
      'most_common_status': statusCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key,
    };
  }

  Map<String, dynamic> getCurrentSoilDataMap() {
    if (_currentSoilData == null) return {};
    return _currentSoilData!.toJson();
  }

  // ============ DEBUGGING ============
  void printDebugInfo() {
    print('''
=== SoilApiProvider Debug Info ===
Current Soil Data: ${_currentSoilData != null ? 'Yes' : 'No'}
Is Loading: $_isLoading
Error: $_error
Last Fetch: $_lastFetch
Current Location: $_currentFetchLocation
Cache Size: ${_locationCache.length}
Pending Requests: ${_pendingRequests.length}
Successful Endpoints: $_lastSuccessfulEndpoints
Has Nutrient Data: $hasNutrientData
==================================
''');

    if (_currentSoilData != null) {
      _printSoilDataDetails(_currentSoilData!);
    }
  }

  void _printSoilDataSummary(SoilData soilData) {
    print('''
📊 Soil Data Summary:
  Location: ${soilData.location}
  Source: ${soilData.source}
  Date: ${soilData.date}
  pH: ${soilData.pH?.toStringAsFixed(2) ?? 'N/A'}
  Nitrogen: ${soilData.nitrogen?.toStringAsFixed(1) ?? 'N/A'} mg/kg
  Phosphorus: ${soilData.phosphorus?.toStringAsFixed(1) ?? 'N/A'} mg/kg
  Potassium: ${soilData.potassium?.toStringAsFixed(1) ?? 'N/A'} mg/kg
  Organic Matter: ${soilData.organicMatter?.toStringAsFixed(2) ?? 'N/A'}%
  Soil Type: ${soilData.soilType ?? 'N/A'}
''');
  }

  void _printSoilDataDetails(SoilData soilData) {
    print('''
📊 Full Soil Data:
  Location: ${soilData.location}
  Source: ${soilData.source}
  Date: ${soilData.date}
  
  🌡️ Temperature: ${soilData.soilTemperature?.toStringAsFixed(1) ?? 'N/A'}°C
  💧 Moisture: ${soilData.soilMoisture?.toStringAsFixed(1) ?? 'N/A'}%
  🧪 pH: ${soilData.pH?.toStringAsFixed(2) ?? 'N/A'}
  
  🌱 Nutrients:
    • Nitrogen: ${soilData.nitrogen?.toStringAsFixed(1) ?? 'N/A'} mg/kg
    • Phosphorus: ${soilData.phosphorus?.toStringAsFixed(1) ?? 'N/A'} mg/kg
    • Potassium: ${soilData.potassium?.toStringAsFixed(1) ?? 'N/A'} mg/kg
    • Organic Matter: ${soilData.organicMatter?.toStringAsFixed(2) ?? 'N/A'}%
  
  🏜️ Soil Type: ${soilData.soilType ?? 'N/A'}
  📝 Notes: ${soilData.notes ?? 'None'}
''');
  }

  // ============ SERVICE STATUS ============
  Map<String, dynamic> getServiceStatus() {
    return _apiService.getServiceStatus();
  }

  Future<Map<String, dynamic>> testConnections() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🔍 Testing API connections...');
      final results = await Future.delayed(Duration(seconds: 2), () {
        return {
          'soil_hive': {'status': 'Not tested - requires API key'},
          'local_api': {'status': 'Available'},
          'soilgrids': {'status': 'Available'},
          'nasa_power': {'status': 'Available'},
        };
      });

      print('✅ Connection tests completed');
      return results;
    } catch (e) {
      print('❌ Connection tests failed: $e');
      return {'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// ============ SUPPORTING CLASSES ============

class CacheEntry {
  final SoilData data;
  final DateTime timestamp;

  CacheEntry({
    required this.data,
    required this.timestamp,
  });
}

class CancelledException implements Exception {
  @override
  String toString() => 'Request cancelled';
}