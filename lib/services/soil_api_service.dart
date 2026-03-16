import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/soil_data.dart';

/// Main soil data model
// class SoilData {
//   final DateTime date;
//   final double latitude;
//   final double longitude;
//   final String location;
//   final String? soilType;
//   final double? pH;
//   final double? nitrogen;
//   final double? phosphorus;
//   final double? potassium;
//   final double? calcium;
//   final double? magnesium;
//   final double? organicMatter;
//   final double? soilMoisture;
//   final double? soilTemperature;
//   final double? airTemperature;
//   final double? precipitation;
//   final double? humidity;
//   final double? solarRadiation;
//   final String source;
//   final String? notes;
//
//   SoilData({
//     required this.date,
//     required this.latitude,
//     required this.longitude,
//     required this.location,
//     this.soilType,
//     this.pH,
//     this.nitrogen,
//     this.phosphorus,
//     this.potassium,
//     this.calcium,
//     this.magnesium,
//     this.organicMatter,
//     this.soilMoisture,
//     this.soilTemperature,
//     this.airTemperature,
//     this.precipitation,
//     this.humidity,
//     this.solarRadiation,
//     required this.source,
//     this.notes,
//   });
//
//   bool get isValid => latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
//
//   bool get hasNutrientData =>
//       pH != null || nitrogen != null || phosphorus != null || potassium != null ||
//           organicMatter != null;
//
//   Map<String, dynamic> toJson() {
//     return {
//       'date': date.toIso8601String(),
//       'latitude': latitude,
//       'longitude': longitude,
//       'location': location,
//       'soilType': soilType,
//       'pH': pH,
//       'nitrogen': nitrogen,
//       'phosphorus': phosphorus,
//       'potassium': potassium,
//       'calcium': calcium,
//       'magnesium': magnesium,
//       'organicMatter': organicMatter,
//       'soilMoisture': soilMoisture,
//       'soilTemperature': soilTemperature,
//       'airTemperature': airTemperature,
//       'precipitation': precipitation,
//       'humidity': humidity,
//       'solarRadiation': solarRadiation,
//       'source': source,
//       'notes': notes,
//     };
//   }
//
//   factory SoilData.fromJson(Map<String, dynamic> json) {
//     return SoilData(
//       date: DateTime.parse(json['date']),
//       latitude: (json['latitude'] as num).toDouble(),
//       longitude: (json['longitude'] as num).toDouble(),
//       location: json['location'] ?? '',
//       soilType: json['soilType'],
//       pH: json['pH']?.toDouble(),
//       nitrogen: json['nitrogen']?.toDouble(),
//       phosphorus: json['phosphorus']?.toDouble(),
//       potassium: json['potassium']?.toDouble(),
//       calcium: json['calcium']?.toDouble(),
//       magnesium: json['magnesium']?.toDouble(),
//       organicMatter: json['organicMatter']?.toDouble(),
//       soilMoisture: json['soilMoisture']?.toDouble(),
//       soilTemperature: json['soilTemperature']?.toDouble(),
//       airTemperature: json['airTemperature']?.toDouble(),
//       precipitation: json['precipitation']?.toDouble(),
//       humidity: json['humidity']?.toDouble(),
//       solarRadiation: json['solarRadiation']?.toDouble(),
//       source: json['source'] ?? 'Unknown',
//       notes: json['notes'],
//     );
//   }
//
//   factory SoilData.empty({
//     required double latitude,
//     required double longitude,
//     String source = 'Empty',
//   }) {
//     return SoilData(
//       date: DateTime.now(),
//       latitude: latitude,
//       longitude: longitude,
//       location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
//       source: source,
//       notes: 'No data available',
//     );
//   }
//
//   SoilData copyWith({
//     DateTime? date,
//     double? latitude,
//     double? longitude,
//     String? location,
//     String? soilType,
//     double? pH,
//     double? nitrogen,
//     double? phosphorus,
//     double? potassium,
//     double? calcium,
//     double? magnesium,
//     double? organicMatter,
//     double? soilMoisture,
//     double? soilTemperature,
//     double? airTemperature,
//     double? precipitation,
//     double? humidity,
//     double? solarRadiation,
//     String? source,
//     String? notes,
//   }) {
//     return SoilData(
//       date: date ?? this.date,
//       latitude: latitude ?? this.latitude,
//       longitude: longitude ?? this.longitude,
//       location: location ?? this.location,
//       soilType: soilType ?? this.soilType,
//       pH: pH ?? this.pH,
//       nitrogen: nitrogen ?? this.nitrogen,
//       phosphorus: phosphorus ?? this.phosphorus,
//       potassium: potassium ?? this.potassium,
//       calcium: calcium ?? this.calcium,
//       magnesium: magnesium ?? this.magnesium,
//       organicMatter: organicMatter ?? this.organicMatter,
//       soilMoisture: soilMoisture ?? this.soilMoisture,
//       soilTemperature: soilTemperature ?? this.soilTemperature,
//       airTemperature: airTemperature ?? this.airTemperature,
//       precipitation: precipitation ?? this.precipitation,
//       humidity: humidity ?? this.humidity,
//       solarRadiation: solarRadiation ?? this.solarRadiation,
//       source: source ?? this.source,
//       notes: notes ?? this.notes,
//     );
//   }
//
//   Map<String, String> getNutrientAnalysis() {
//     final analysis = <String, String>{};
//
//     if (pH != null) {
//       if (pH! < 5.5) analysis['pH'] = 'Very Acidic';
//       else if (pH! < 6.0) analysis['pH'] = 'Acidic';
//       else if (pH! <= 7.0) analysis['pH'] = 'Optimal';
//       else if (pH! <= 7.5) analysis['pH'] = 'Slightly Alkaline';
//       else analysis['pH'] = 'Alkaline';
//     }
//
//     if (nitrogen != null) {
//       if (nitrogen! < 20) analysis['nitrogen'] = 'Very Low';
//       else if (nitrogen! < 30) analysis['nitrogen'] = 'Low';
//       else if (nitrogen! <= 50) analysis['nitrogen'] = 'Medium';
//       else analysis['nitrogen'] = 'High';
//     }
//
//     if (phosphorus != null) {
//       if (phosphorus! < 10) analysis['phosphorus'] = 'Very Low';
//       else if (phosphorus! < 20) analysis['phosphorus'] = 'Low';
//       else if (phosphorus! <= 40) analysis['phosphorus'] = 'Medium';
//       else analysis['phosphorus'] = 'High';
//     }
//
//     if (potassium != null) {
//       if (potassium! < 100) analysis['potassium'] = 'Very Low';
//       else if (potassium! < 150) analysis['potassium'] = 'Low';
//       else if (potassium! <= 200) analysis['potassium'] = 'Medium';
//       else analysis['potassium'] = 'High';
//     }
//
//     if (organicMatter != null) {
//       if (organicMatter! < 1.0) analysis['organicMatter'] = 'Very Low';
//       else if (organicMatter! < 2.0) analysis['organicMatter'] = 'Low';
//       else if (organicMatter! <= 4.0) analysis['organicMatter'] = 'Medium';
//       else analysis['organicMatter'] = 'High';
//     }
//
//     return analysis;
//   }
// }

/// Soil API Service - Handles all soil data fetching
class SoilApiService {
  // API Endpoints
  static const String _soilHiveUrl = 'https://api.soilhive.ag/v1';
  static const String _nasaPowerUrl = 'https://power.larc.nasa.gov/api/temporal/daily/point';
  static const String _soilGridsUrl = 'https://rest.isric.org/soilgrids/v2.0';
  static const String _openWeatherUrl = 'https://api.openweathermap.org/data/3.0/onecall';
  static const String _localApiUrl = 'http://62.171.164.83:8007/soils/api/soils.php';

  // Configuration
  final String soilHiveApiKey;
  final String? openWeatherApiKey;
  final Duration timeout;
  final bool useMultiSourceFallback;
  final bool useLocalApi;
  final bool verbose;

  // Tracking
  final List<String> _successfulEndpoints = [];
  final Map<String, ApiSourceResult> _sourceResults = {};
  final Map<String, String> _lastErrors = {};
  final List<SoilDataSource> _soilDataSources = [];

  // Property mappings
  static const Map<String, String> _propertyMappings = {
    '1': 'pH',
    '2': 'nitrogen',
    '3': 'phosphorus',
    '4': 'potassium',
    '5': 'calcium',
    '6': 'magnesium',
    '7': 'organic_carbon',
    '8': 'electrical_conductivity',
  };

  SoilApiService({
    required this.soilHiveApiKey,
    this.openWeatherApiKey,
    this.timeout = const Duration(seconds: 30),
    this.useMultiSourceFallback = true,
    this.useLocalApi = true,
    this.verbose = true,
  }) {
    _initializeDataSources();
  }

  void _initializeDataSources() {
    _soilDataSources.addAll([
      SoilDataSource(
        name: 'Soil Hive',
        priority: 1,
        fetch: _fetchSoilHiveSource,
      ),
    ]);

    if (useLocalApi) {
      _soilDataSources.add(
        SoilDataSource(
          name: 'Local Soil Database',
          priority: 2,
          fetch: _fetchLocalApiSource,
        ),
      );
    }

    _soilDataSources.addAll([
      SoilDataSource(
        name: 'SoilGrids',
        priority: 3,
        fetch: _fetchSoilGridsSource,
      ),
      SoilDataSource(
        name: 'Climate Data',
        priority: 4,
        fetch: _fetchClimateDataSource,
      ),
    ]);
  }

  /// Main method to fetch comprehensive soil data
  Future<SoilData> fetchSoilData({
    required double latitude,
    required double longitude,
    int depth = 30,
    List<String>? propertyIdentifiers,
    bool forceRefresh = false,
    int maxRetries = 2,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Reset tracking
    _successfulEndpoints.clear();
    _sourceResults.clear();
    _lastErrors.clear();

    if (verbose) {
      _printHeader('STARTING SOIL DATA FETCH');
      print('📍 Coordinates: ($latitude, $longitude)');
      print('📏 Depth: ${depth}cm');
      print('🔄 Multi-source: ${useMultiSourceFallback}');
      print('🏠 Local API: ${useLocalApi}');
      _printDivider();
    }

    try {
      SoilData? result;

      if (useMultiSourceFallback) {
        result = await _fetchWithMultiSourceFallback(
          latitude: latitude,
          longitude: longitude,
          depth: depth,
          propertyIdentifiers: propertyIdentifiers,
        );
      } else {
        result = await _fetchPrimarySourceWithRetries(
          latitude: latitude,
          longitude: longitude,
          depth: depth,
          propertyIdentifiers: propertyIdentifiers,
          maxRetries: maxRetries,
        );
      }

      // Check if we got sufficient data
      if (result != null && _hasSufficientData(result)) {
        stopwatch.stop();

        if (verbose) {
          _printSuccess('FETCH COMPLETED SUCCESSFULLY');
          print('⏱️  Total time: ${stopwatch.elapsedMilliseconds}ms');
          print('✅ Successful endpoints: $_successfulEndpoints');
        }

        return _finalizeData(
          result: result,
          stopwatch: stopwatch,
        );
      }

      // Try emergency fallback
      return await _emergencyFallback(
        latitude: latitude,
        longitude: longitude,
        existingData: result,
        stopwatch: stopwatch,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();

      if (verbose) {
        _printError('FETCH FAILED');
        print('❌ Error: $e');
        print('🔧 Stack trace: $stackTrace');
        print('⏱️  Time elapsed: ${stopwatch.elapsedMilliseconds}ms');
      }

      return _handleCriticalError(
        latitude: latitude,
        longitude: longitude,
        error: e,
        stopwatch: stopwatch,
      );
    } finally {
      if (verbose) {
        _printSummary();
      }
    }
  }

  Future<SoilData?> _fetchWithMultiSourceFallback({
    required double latitude,
    required double longitude,
    int depth = 30,
    List<String>? propertyIdentifiers,
  }) async {
    final sortedSources = List<SoilDataSource>.from(_soilDataSources)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    SoilData? bestResult;
    int bestScore = 0;

    if (verbose) {
      print('🔄 Starting multi-source fallback');
      print('📋 Available sources:');
      for (var source in sortedSources) {
        print('   • ${source.name} (Priority: ${source.priority})');
      }
      _printDivider();
    }

    for (final source in sortedSources) {
      final sourceStopwatch = Stopwatch()..start();

      try {
        if (verbose) {
          print('🚀 Trying: ${source.name}...');
        }

        final result = await source.fetch(
          this,
          latitude,
          longitude,
          depth,
        );

        sourceStopwatch.stop();
        final score = _calculateDataScore(result);
        final params = _countParameters(result);

        if (verbose) {
          _printSourceResult(
            name: source.name,
            success: true,
            time: sourceStopwatch.elapsedMilliseconds,
            score: score,
            parameters: params,
          );
        }

        if (score > bestScore) {
          bestResult = result;
          bestScore = score;

          _addSuccessfulEndpoint(source.name);
          _sourceResults[source.name] = ApiSourceResult(
            name: source.name,
            success: true,
            parametersFound: params,
            responseTime: sourceStopwatch.elapsed,
          );

          if (verbose) {
            print('   🏆 New best result!');
            _printSoilDataPreview(result);
          }

          // Return early if we have excellent data
          if (score >= 8) {
            if (verbose) {
              print('🎯 Excellent data found, stopping further sources');
              _printDivider();
            }
            break;
          }
        }
      } catch (e) {
        sourceStopwatch.stop();

        if (verbose) {
          _printSourceResult(
            name: source.name,
            success: false,
            time: sourceStopwatch.elapsedMilliseconds,
            error: e.toString(),
          );
        }

        _sourceResults[source.name] = ApiSourceResult(
          name: source.name,
          success: false,
          error: e.toString().substring(0, 100),
          responseTime: sourceStopwatch.elapsed,
        );
      }
    }

    return bestResult;
  }

  Future<SoilData?> _fetchPrimarySourceWithRetries({
    required double latitude,
    required double longitude,
    int depth = 30,
    List<String>? propertyIdentifiers,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (verbose) {
          print('🔄 Attempt ${attempt + 1}/$maxRetries for Soil Hive');
        }

        final result = await _fetchSoilHiveData(
          latitude: latitude,
          longitude: longitude,
          depth: depth,
          propertyIdentifiers: propertyIdentifiers,
        );

        if (_hasSufficientData(result)) {
          _addSuccessfulEndpoint('Soil Hive (attempt ${attempt + 1})');
          return result;
        }
      } catch (e) {
        if (attempt == maxRetries) {
          _lastErrors['primary'] = e.toString();
        }

        if (verbose) {
          print('   ⏳ Retrying in ${1 << attempt} seconds...');
        }

        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
    return null;
  }

  Future<SoilData> _emergencyFallback({
    required double latitude,
    required double longitude,
    required SoilData? existingData,
    required Stopwatch stopwatch,
  }) async {
    if (verbose) {
      print('⚠️  Entering emergency fallback mode');
    }

    try {
      final climateData = await _fetchClimateData(
        latitude: latitude,
        longitude: longitude,
      );

      final mergedData = existingData != null
          ? _mergeData(existingData, climateData)
          : climateData;

      stopwatch.stop();

      return mergedData.copyWith(
        source: 'Emergency Fallback (${stopwatch.elapsedMilliseconds}ms)',
        notes: 'Limited data: ${_buildErrorSummary()}',
      );
    } catch (e) {
      return _generateSyntheticData(
        latitude: latitude,
        longitude: longitude,
        errors: _lastErrors,
      );
    }
  }

  SoilData _handleCriticalError({
    required double latitude,
    required double longitude,
    required Object error,
    required Stopwatch stopwatch,
  }) {
    final errorString = error.toString();

    if (verbose) {
      _printError('CRITICAL ERROR - GENERATING FALLBACK DATA');
    }

    return SoilData.empty(
      latitude: latitude,
      longitude: longitude,
      source: 'Failed (${stopwatch.elapsedMilliseconds}ms)',
    ).copyWith(
      notes: 'Error: ${errorString.substring(0, min(errorString.length, 100))}',
    );
  }

  SoilData _finalizeData({
    required SoilData result,
    required Stopwatch stopwatch,
  }) {
    final finalized = result.copyWith(
      source: '${result.source} (${stopwatch.elapsedMilliseconds}ms)',
      notes: _buildSourceNotes(),
    );

    if (verbose) {
      _printSuccess('FINAL DATA READY');
      print('🏷️  Source: ${finalized.source}');
      print('📊 Parameters: ${_countParameters(finalized)}');
      _printDivider();
    }

    return finalized;
  }

  // ============ SOURCE IMPLEMENTATIONS ============

  Future<SoilData> _fetchSoilHiveSource(
      SoilApiService service,
      double lat,
      double lon,
      int depth,
      ) async {
    if (verbose) {
      print('🌐 Soil Hive API Request:');
      print('   URL: $_soilHiveUrl/soil-properties/queries');
      print('   Coordinates: ($lat, $lon)');
      print('   Depth: ${depth}cm');
    }

    return await service._fetchSoilHiveData(
      latitude: lat,
      longitude: lon,
      depth: depth,
    );
  }

  Future<SoilData> _fetchSoilHiveData({
    required double latitude,
    required double longitude,
    int depth = 30,
    List<String>? propertyIdentifiers,
  }) async {
    final selectedProperties = propertyIdentifiers ?? _getDefaultProperties();

    final response = await _makeHttpRequest(
      '$_soilHiveUrl/soil-properties/queries',
      method: 'POST',
      body: {
        'geometry': 'POINT($longitude $latitude)',
        'properties': selectedProperties,
        'depth': depth,
      },
      headers: {
        'Authorization': 'Bearer $soilHiveApiKey',
        'Content-Type': 'application/json',
      },
      timeout: timeout,
    );

    return _parseSoilHiveResponse(
      response,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<SoilData> _fetchLocalApiSource(
      SoilApiService service,
      double lat,
      double lon,
      int depth,
      ) async {
    if (verbose) {
      print('🏠 Local Database Query:');
      print('   URL: $_localApiUrl');
      print('   Coordinates: ($lat, $lon)');
    }

    try {
      final response = await _makeHttpRequest(
        _localApiUrl,
        timeout: Duration(seconds: 10),
      );

      if (verbose) {
        print('   ✅ Response received');
        if (response.containsKey('data') && response['data'] is List) {
          print('   📊 Records found: ${(response['data'] as List).length}');
        }
      }

      return service._parseLocalApiResponse(
        response,
        latitude: lat,
        longitude: lon,
      );
    } catch (e) {
      if (verbose) {
        print('   ❌ Local API error: $e');
        print('   📝 Creating estimated data...');
      }

      return _createEstimatedSoilData(
        latitude: lat,
        longitude: lon,
        notes: 'API error: ${e.toString().substring(0, 50)}',
      );
    }
  }

  Future<SoilData> _fetchSoilGridsSource(
      SoilApiService service,
      double lat,
      double lon,
      int depth,
      ) async {
    if (verbose) {
      print('🛰️  SoilGrids API Request:');
      print('   URL: $_soilGridsUrl/properties/query');
      print('   Coordinates: ($lat, $lon)');
      print('   Depth: ${_getSoilGridsDepth(depth)}');
    }

    final depthStr = _getSoilGridsDepth(depth);
    final properties = 'phh2o,clay,sand,silt,ocd,cec,bdod';

    final response = await _makeHttpRequest(
      '$_soilGridsUrl/properties/query?lon=$lon&lat=$lat&properties=$properties&depth=$depthStr&value=mean',
      timeout: Duration(seconds: 15),
    );

    return service._parseSoilGridsResponse(
      response,
      latitude: lat,
      longitude: lon,
    );
  }

  Future<SoilData> _fetchClimateDataSource(
      SoilApiService service,
      double lat,
      double lon,
      int depth,
      ) async {
    if (verbose) {
      print('☀️  Climate Data Request:');
      print('   Coordinates: ($lat, $lon)');
    }

    return await service._fetchClimateData(
      latitude: lat,
      longitude: lon,
    );
  }

  Future<SoilData> _fetchClimateData({
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _fetchNasaClimateData(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      if (openWeatherApiKey != null) {
        return await _fetchOpenWeatherData(
          latitude: latitude,
          longitude: longitude,
        );
      }
      rethrow;
    }
  }

  // ============ PARSING METHODS ============

  SoilData _parseSoilHiveResponse(
      Map<String, dynamic> response, {
        required double latitude,
        required double longitude,
      }) {
    final properties = <String, dynamic>{};

    // Parse response
    if (response['features'] is List && (response['features'] as List).isNotEmpty) {
      final feature = (response['features'] as List).first;
      if (feature['properties'] is Map) {
        properties.addAll(feature['properties'] as Map<String, dynamic>);
      }
    } else if (response['data'] is List) {
      for (final item in (response['data'] as List)) {
        if (item is Map) {
          final id = item['propertyId']?.toString();
          final value = item['value'];
          if (id != null && value != null) {
            final name = _propertyMappings[id] ?? id;
            properties[name] = value;
          }
        }
      }
    }

    // Extract values
    double? soilTemperature;
    if (properties.containsKey('soil_temperature')) {
      soilTemperature = properties['soil_temperature'] as double?;
    }

    if (verbose) {
      print('   ✅ Soil Hive data parsed');
      print('   📊 Properties found: ${properties.length}');
    }

    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      soilType: properties['soil_type'] as String?,
      pH: properties['pH'] as double?,
      nitrogen: properties['nitrogen'] as double?,
      phosphorus: properties['phosphorus'] as double?,
      potassium: properties['potassium'] as double?,
      organicMatter: properties['organic_matter'] as double?,
      soilMoisture: properties['soil_moisture'] as double?,
      soilTemperature: soilTemperature,
      source: 'Soil Hive',
      notes: 'Soil Hive API Data',
    );
  }

  SoilData _parseLocalApiResponse(
      Map<String, dynamic> response, {
        required double latitude,
        required double longitude,
      }) {
    final dataList = response['data'] as List<dynamic>?;

    if (dataList == null || dataList.isEmpty) {
      if (verbose) print('   ⚠️  No exact soil data found at coordinates');
      return _createEstimatedSoilData(
        latitude: latitude,
        longitude: longitude,
        notes: 'No exact soil data found',
      );
    }

    try {
      final soilData = dataList.first as Map<String, dynamic>;
      final soilType = soilData['SOIL'] as String? ?? 'Unknown';
      final drainage = soilData['DRAI_DESCR'] as String?;
      final texture = soilData['TEXT_DESCR'] as String?;

      // Estimate nutrients
      final estimatedValues = _estimateNutrientsFromTexture(texture, drainage);

      // Create description
      String? soilDescription;
      if (texture != null && drainage != null) {
        soilDescription = '$texture, $drainage soil';
      } else if (texture != null) {
        soilDescription = '$texture soil';
      }

      if (verbose) {
        print('   ✅ Local data parsed successfully');
        print('   🏷️  Soil Type: $soilType');
        if (texture != null) print('   🧱 Texture: $texture');
        if (drainage != null) print('   💧 Drainage: $drainage');
      }

      return SoilData(
        date: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
        soilType: soilDescription ?? soilType,
        pH: estimatedValues['pH'],
        nitrogen: estimatedValues['nitrogen'],
        phosphorus: estimatedValues['phosphorus'],
        potassium: estimatedValues['potassium'],
        organicMatter: estimatedValues['organicMatter'],
        soilMoisture: estimatedValues['soilMoisture'],
        soilTemperature: estimatedValues['soilTemperature'],
        source: 'Local Soil Database',
        notes: _buildSoilNotes(soilType, drainage, texture),
      );
    } catch (e) {
      if (verbose) print('   ❌ Error parsing local data: $e');
      return _createEstimatedSoilData(
        latitude: latitude,
        longitude: longitude,
        notes: 'Error parsing: ${e.toString().substring(0, 50)}',
      );
    }
  }

  SoilData _parseSoilGridsResponse(
      Map<String, dynamic> response, {
        required double latitude,
        required double longitude,
      }) {
    final properties = <String, dynamic>{};
    final layers = response['properties']?['layers'] as List<dynamic>?;

    if (layers != null) {
      for (final layer in layers) {
        final name = layer['name'] as String?;
        final value = layer['values']?['mean'] as num?;

        if (name != null && value != null) {
          properties[name] = value.toDouble();
        }
      }
    }

    // Determine texture class
    String? soilTexture;
    if (properties['sand'] != null && properties['silt'] != null && properties['clay'] != null) {
      soilTexture = _determineTextureClass(
        sand: properties['sand'] as double,
        silt: properties['silt'] as double,
        clay: properties['clay'] as double,
      );
    }

    // Convert organic carbon to organic matter
    if (properties['ocd'] != null) {
      properties['organic_matter'] = (properties['ocd'] as double) * 1.724;
    }

    if (verbose) {
      print('   ✅ SoilGrids data parsed');
      print('   📊 Layers found: ${layers?.length ?? 0}');
      if (soilTexture != null) print('   🧱 Texture: $soilTexture');
    }

    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      soilType: soilTexture,
      pH: properties['phh2o'] as double?,
      organicMatter: properties['organic_matter'] as double?,
      source: 'SoilGrids',
      notes: 'Global soil property estimates',
    );
  }

  // ============ UTILITY METHODS ============

  Future<Map<String, dynamic>> _makeHttpRequest(
      String url, {
        String method = 'GET',
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        Map<String, String>? queryParams, // Added this parameter
        Duration? timeout,
      }) async {
    Uri uri = Uri.parse(url);

    // Add query parameters if provided
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final request = http.Request(method, uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (body != null && (method == 'POST' || method == 'PUT')) {
      request.body = jsonEncode(body);
      if (!request.headers.containsKey('Content-Type')) {
        request.headers['Content-Type'] = 'application/json';
      }
    }

    final streamedResponse = await request.send().timeout(timeout ?? this.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw HttpException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        response.statusCode,
      );
    }
  }

  List<String> _getDefaultProperties() {
    return ['1', '2', '3', '4', '5', '6', '7'];
  }

  bool _hasSufficientData(SoilData data) {
    return _countParameters(data) >= 3;
  }

  int _countParameters(SoilData data) {
    int count = 0;
    if (data.pH != null) count++;
    if (data.nitrogen != null) count++;
    if (data.phosphorus != null) count++;
    if (data.potassium != null) count++;
    if (data.organicMatter != null) count++;
    if (data.soilType != null && data.soilType!.isNotEmpty) count++;
    if (data.soilMoisture != null) count++;
    if (data.soilTemperature != null) count++;
    return count;
  }

  int _calculateDataScore(SoilData data) {
    int score = 0;
    if (data.pH != null) score += 2;
    if (data.nitrogen != null) score += 2;
    if (data.phosphorus != null) score += 2;
    if (data.potassium != null) score += 2;
    if (data.organicMatter != null) score += 2;
    if (data.soilType != null && data.soilType!.isNotEmpty) score += 1;
    if (data.soilMoisture != null) score += 1;
    if (data.soilTemperature != null) score += 1;
    return score;
  }

  void _addSuccessfulEndpoint(String endpoint) {
    if (!_successfulEndpoints.contains(endpoint)) {
      _successfulEndpoints.add(endpoint);
    }
  }

  String _buildSourceNotes() {
    final notes = <String>[];
    if (_successfulEndpoints.isNotEmpty) {
      notes.add('Sources: ${_successfulEndpoints.join(', ')}');
    }
    return notes.join(' | ');
  }

  String _buildErrorSummary() {
    if (_lastErrors.isEmpty) return 'No errors';
    return _lastErrors.entries.map((e) => '${e.key}').join(', ');
  }

  Map<String, double> _estimateNutrientsFromTexture(String? texture, String? drainage) {
    Map<String, double> values = {
      'pH': 6.5,
      'organicMatter': 2.0,
      'soilMoisture': 25.0,
      'soilTemperature': 20.0,
      'nitrogen': 25.0,
      'phosphorus': 15.0,
      'potassium': 150.0,
    };

    if (texture != null) {
      texture = texture.toLowerCase();
      if (texture.contains('clayey')) {
        values['pH'] = 7.2;
        values['organicMatter'] = 3.5;
        values['soilMoisture'] = 35.0;
        values['nitrogen'] = 30.0;
        values['phosphorus'] = 20.0;
        values['potassium'] = 180.0;
      } else if (texture.contains('sandy')) {
        values['pH'] = 6.0;
        values['organicMatter'] = 1.0;
        values['soilMoisture'] = 15.0;
        values['nitrogen'] = 15.0;
        values['phosphorus'] = 10.0;
        values['potassium'] = 120.0;
      } else if (texture.contains('loamy')) {
        values['pH'] = 6.8;
        values['organicMatter'] = 2.5;
        values['soilMoisture'] = 25.0;
        values['nitrogen'] = 25.0;
        values['phosphorus'] = 15.0;
        values['potassium'] = 160.0;
      }
    }

    // Adjust for season
    final month = DateTime.now().month;
    if (month >= 4 && month <= 9) {
      values['soilTemperature'] = 22.0;
    } else {
      values['soilTemperature'] = 18.0;
    }

    return values;
  }

  SoilData _createEstimatedSoilData({
    required double latitude,
    required double longitude,
    String? notes,
  }) {
    final random = Random((latitude * 1000 + longitude).toInt());

    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      soilType: 'Estimated Loam',
      pH: 6.5 + (random.nextDouble() * 1.0 - 0.5),
      organicMatter: 2.0 + random.nextDouble() * 2.0,
      soilMoisture: 25.0 + random.nextDouble() * 15.0,
      soilTemperature: 20.0 + (random.nextDouble() * 10.0 - 5.0),
      nitrogen: 25.0 + random.nextDouble() * 15.0,
      phosphorus: 15.0 + random.nextDouble() * 10.0,
      potassium: 150.0 + random.nextDouble() * 50.0,
      source: 'Estimated Data',
      notes: notes ?? 'Estimated soil parameters',
    );
  }

  String _buildSoilNotes(String? soilType, String? drainage, String? texture) {
    final notes = <String>[];
    if (soilType != null) notes.add('Soil: $soilType');
    if (drainage != null) notes.add('Drainage: $drainage');
    if (texture != null) notes.add('Texture: $texture');
    return notes.join(' • ');
  }

  SoilData _generateSyntheticData({
    required double latitude,
    required double longitude,
    required Map<String, String> errors,
  }) {
    final random = Random((latitude * 1000 + longitude).toInt());

    if (verbose) {
      print('   📝 Generating synthetic fallback data');
    }

    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      soilMoisture: 25.0 + random.nextDouble() * 15,
      soilTemperature: 15.0 + random.nextDouble() * 10,
      pH: 6.0 + random.nextDouble() * 1.5,
      organicMatter: 1.5 + random.nextDouble() * 3,
      source: 'Synthetic Fallback',
      notes: 'Generated due to API failures',
    );
  }

  SoilData _mergeData(SoilData primary, SoilData secondary) {
    return primary.copyWith(
      soilMoisture: primary.soilMoisture ?? secondary.soilMoisture,
      soilTemperature: primary.soilTemperature ?? secondary.soilTemperature,
      airTemperature: primary.airTemperature ?? secondary.airTemperature,
      precipitation: primary.precipitation ?? secondary.precipitation,
      humidity: primary.humidity ?? secondary.humidity,
      solarRadiation: primary.solarRadiation ?? secondary.solarRadiation,
    );
  }

  String _getSoilGridsDepth(int depth) {
    if (depth <= 5) return '0-5cm';
    if (depth <= 15) return '5-15cm';
    if (depth <= 30) return '15-30cm';
    if (depth <= 60) return '30-60cm';
    return '60-100cm';
  }

  String _determineTextureClass({
    required double sand,
    required double silt,
    required double clay,
  }) {
    final total = sand + silt + clay;
    if (total == 0) return 'Unknown';

    final sandPercent = (sand / total) * 100;
    final siltPercent = (silt / total) * 100;
    final clayPercent = (clay / total) * 100;

    if (clayPercent >= 40) return 'Clay';
    if (sandPercent >= 85 && clayPercent <= 10) return 'Sand';
    if (sandPercent >= 70 && clayPercent <= 15) return 'Loamy Sand';
    if (clayPercent >= 27 && clayPercent <= 40) return 'Clay Loam';
    if (sandPercent >= 45 && sandPercent <= 80 && clayPercent >= 12 && clayPercent <= 27) return 'Sandy Clay Loam';
    if (sandPercent >= 20 && sandPercent <= 45 && clayPercent >= 27 && clayPercent <= 40) return 'Sandy Clay';
    if (siltPercent >= 50 && clayPercent >= 12 && clayPercent <= 27) return 'Silt Loam';
    if (siltPercent >= 80 && clayPercent < 12) return 'Silt';
    if (sandPercent >= 23 && sandPercent <= 52 && siltPercent >= 28 && siltPercent <= 50 && clayPercent >= 7 && clayPercent <= 27) return 'Loam';
    if (sandPercent >= 43 && sandPercent <= 85 && siltPercent + clayPercent >= 15) return 'Sandy Loam';

    return 'Unknown';
  }

  Future<SoilData> _fetchNasaClimateData({
    required double latitude,
    required double longitude,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: 30));

    final startStr = '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';

    final response = await _makeHttpRequest(
      _nasaPowerUrl,
      queryParams: {
        'parameters': 'T2M,PRECTOTCORR,RH2M,ALLSKY_SFC_SW_DWN,WS2M',
        'community': 'AG',
        'longitude': longitude.toString(),
        'latitude': latitude.toString(),
        'start': startStr,
        'end': endStr,
        'format': 'JSON',
      },
      timeout: Duration(seconds: 20),
    );

    final parameterData = response['properties']?['parameter'];
    final climateProperties = <String, double>{};

    if (parameterData is Map<String, dynamic>) {
      final params = ['T2M', 'PRECTOTCORR', 'RH2M'];
      for (final paramKey in params) {
        final paramData = parameterData[paramKey];
        if (paramData is Map<String, dynamic>) {
          final values = paramData.values
              .where((v) => v is num && v != -999)
              .map((v) => v.toDouble())
              .toList();

          if (values.isNotEmpty) {
            final average = values.reduce((a, b) => a + b) / values.length;
            climateProperties[paramKey] = average;
          }
        }
      }
    }

    // Estimate soil conditions
    final precipitation = climateProperties['PRECTOTCORR'] ?? 0.0;
    final humidity = climateProperties['RH2M'] ?? 50.0;
    final airTemp = climateProperties['T2M'] ?? 20.0;

    final estimatedMoisture = min(100.0, (humidity * 0.7 + precipitation * 10));
    final estimatedSoilTemp = airTemp - 5.0;

    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      soilMoisture: estimatedMoisture,
      soilTemperature: estimatedSoilTemp,
      airTemperature: airTemp,
      precipitation: precipitation,
      humidity: humidity,
      source: 'NASA POWER',
      notes: 'Climate data derived',
    );
  }

  Future<SoilData> _fetchOpenWeatherData({
    required double latitude,
    required double longitude,
  }) async {
    if (openWeatherApiKey == null) {
      throw Exception('OpenWeather API key not configured');
    }

    final response = await _makeHttpRequest(
      _openWeatherUrl,
      queryParams: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'exclude': 'minutely,hourly',
        'units': 'metric',
        'appid': openWeatherApiKey!,
      },
      timeout: Duration(seconds: 10),
    );

    final current = response['current'] as Map<String, dynamic>?;
    final airTemp = current?['temp'] as double? ?? 20.0;
    final estimatedSoilTemp = airTemp - 5.0;

    return SoilData(
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      airTemperature: airTemp,
      humidity: current?['humidity'] as double?,
      soilMoisture: (current?['humidity'] as double?)?.clamp(0, 100) ?? 25.0,
      soilTemperature: estimatedSoilTemp,
      precipitation: (current?['rain']?['1h'] as double?) ?? 0.0,
      source: 'OpenWeather',
      notes: 'Weather data only',
    );
  }

  // ============ LOGGING METHODS ============

  void _printHeader(String title) {
    print('');
    print('┌' + '─' * 50 + '┐');
    print('│' + title.padLeft(25 + title.length ~/ 2).padRight(50) + '│');
    print('└' + '─' * 50 + '┘');
    print('');
  }

  void _printDivider() {
    print('─' * 50);
  }

  void _printSuccess(String message) {
    print('✅ $message');
  }

  void _printError(String message) {
    print('❌ $message');
  }

  void _printSourceResult({
    required String name,
    required bool success,
    required int time,
    int? score,
    int? parameters,
    String? error,
  }) {
    final icon = success ? '✅' : '❌';
    final status = success ? 'SUCCESS' : 'FAILED';

    print('$icon $name: $status (${time}ms)');

    if (success) {
      print('   📊 Score: $score, Parameters: $parameters');
    } else if (error != null) {
      print('   📝 Error: ${error.substring(0, min(80, error.length))}');
    }
  }

  void _printSoilDataPreview(SoilData data) {
    print('   📍 Location: ${data.location}');
    print('   🏷️  Source: ${data.source}');

    if (data.pH != null) print('   🧪 pH: ${data.pH!.toStringAsFixed(2)}');
    if (data.nitrogen != null) print('   🌱 N: ${data.nitrogen!.toStringAsFixed(1)} mg/kg');
    if (data.phosphorus != null) print('   🔥 P: ${data.phosphorus!.toStringAsFixed(1)} mg/kg');
    if (data.potassium != null) print('   ⚡ K: ${data.potassium!.toStringAsFixed(1)} mg/kg');
    if (data.organicMatter != null) print('   ♻️  OM: ${data.organicMatter!.toStringAsFixed(2)}%');

    print('');
  }

  void _printSummary() {
    print('');
    _printHeader('FETCH SUMMARY');

    print('📊 SOURCE RESULTS:');
    int successCount = 0;
    int totalCount = 0;

    _sourceResults.forEach((name, result) {
      totalCount++;
      if (result.success) {
        successCount++;
        print('   ✅ $name: ${result.parametersFound} parameters (${result.responseTime?.inMilliseconds}ms)');
      } else {
        print('   ❌ $name: Failed - ${result.error}');
      }
    });

    print('');
    print('📈 STATISTICS:');
    print('   • Total Sources Attempted: $totalCount');
    print('   • Successful: $successCount');
    print('   • Failed: ${totalCount - successCount}');
    if (totalCount > 0) {
      final successRate = (successCount / totalCount * 100).toStringAsFixed(1);
      print('   • Success Rate: $successRate%');
    }

    if (_successfulEndpoints.isNotEmpty) {
      print('');
      print('🏆 BEST RESULT: ${_successfulEndpoints.first}');
    }

    _printDivider();
  }

  // ============ PUBLIC METHODS ============

  Map<String, dynamic> getServiceStatus() {
    return {
      'service': 'SoilApiService',
      'soil_hive_key': soilHiveApiKey.isNotEmpty ? 'configured' : 'missing',
      'openweather_key': openWeatherApiKey?.isNotEmpty ?? false ? 'configured' : 'missing',
      'multi_source_enabled': useMultiSourceFallback,
      'local_api_enabled': useLocalApi,
      'available_sources': _soilDataSources.map((s) => s.name).toList(),
      'last_successful_endpoints': _successfulEndpoints,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Map<String, ApiSourceResult> getSourceResults() {
    return Map.from(_sourceResults);
  }

  List<String> getSuccessfulEndpoints() {
    return List.from(_successfulEndpoints);
  }
}

// ============ SUPPORTING CLASSES ============

class SoilDataSource {
  final String name;
  final int priority;
  final Future<SoilData> Function(SoilApiService, double, double, int) fetch;

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

class HttpException implements Exception {
  final String message;
  final int statusCode;

  HttpException(this.message, this.statusCode);

  @override
  String toString() => 'HttpException: $message (Status: $statusCode)';
}