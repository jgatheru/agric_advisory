import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';

class NASAPowerProvider with ChangeNotifier {
  // Constants
  static const String _baseUrl = 'https://power.larc.nasa.gov/api/temporal/daily/point';
  static const String _cacheKey = 'cached_nasa_data_v2';
  static const Duration _cacheDuration = Duration(hours: 6);
  static const int _maxRetryAttempts = 3;
  static const Duration _timeoutDuration = Duration(seconds: 30);

  // State variables
  List<WeatherData> _historicalData = [];
  WeatherData? _currentData;
  bool _isLoading = false;
  bool _isInitialized = false;
  String _error = '';
  String _status = 'Ready';
  DateTime? _lastFetchTime;
  int _retryCount = 0;
  StreamController<double> _progressController = StreamController<double>.broadcast();

  // Analytics
  Map<String, dynamic> _analytics = {};
  List<String> _fetchLogs = [];

  // Getters
  List<WeatherData> get historicalData => _historicalData;
  WeatherData? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get status => _status;
  Stream<double> get progressStream => _progressController.stream;
  Map<String, dynamic> get analytics => _analytics;
  List<String> get fetchLogs => List.unmodifiable(_fetchLogs);
  bool get hasData => _currentData != null && _historicalData.isNotEmpty;
  bool get isCacheValid => _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _status = 'Initializing...';
      notifyListeners();

      await _loadCachedData();
      await _loadAnalytics();

      _isInitialized = true;
      _status = 'Ready';
      notifyListeners();

      print('NASA POWER Provider initialized successfully');
    } catch (e) {
      _error = 'Initialization failed: $e';
      print('Error initializing NASA POWER Provider: $e');
      _status = 'Error';
      notifyListeners();
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);

      if (cachedData != null) {
        final data = json.decode(cachedData);

        // Check cache version
        final version = data['version'] ?? '1.0';
        final cacheTime = DateTime.tryParse(data['timestamp'] ?? '');

        if (cacheTime != null && DateTime.now().difference(cacheTime) < Duration(days: 7)) {
          // Load current data
          if (data['currentData'] != null) {
            _currentData = WeatherData.fromJson(data['currentData']);
          }

          // Load historical data
          if (data['historicalData'] != null) {
            _historicalData = (data['historicalData'] as List)
                .map((item) => WeatherData.fromJson(item))
                .toList();
          }

          _lastFetchTime = DateTime.tryParse(data['lastFetchTime'] ?? '');

          print('Loaded cached NASA data (${_historicalData.length} days)');

          // Update analytics
          _updateAnalytics();
        } else {
          print('Cache expired or invalid');
        }
      }
    } catch (e) {
      print('Error loading cached NASA data: $e');
    }
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'version': '2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'currentData': _currentData?.toJson(),
        'historicalData': _historicalData.map((w) => w.toJson()).toList(),
        'lastFetchTime': _lastFetchTime?.toIso8601String(),
        'metadata': {
          'dataPoints': _historicalData.length,
          'dateRange': _historicalData.isNotEmpty ? {
            'start': _historicalData.last.time.toIso8601String(),
            'end': _historicalData.first.time.toIso8601String(),
          } : null,
          'latitude': _currentData != null ? _currentData!.toJson()['latitude'] : null,
          'longitude': _currentData != null ? _currentData!.toJson()['longitude'] : null,
        },
      };
      await prefs.setString(_cacheKey, json.encode(data));
      print('Cached NASA data successfully');
    } catch (e) {
      print('Error caching NASA data: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _analytics = json.decode(prefs.getString('nasa_analytics') ?? '{}');
      _fetchLogs = prefs.getStringList('nasa_fetch_logs') ?? [];
    } catch (e) {
      _analytics = {};
      _fetchLogs = [];
    }
  }

  Future<void> _saveAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nasa_analytics', json.encode(_analytics));

      // Keep last 50 logs
      final logsToKeep = _fetchLogs.length > 50
          ? _fetchLogs.sublist(_fetchLogs.length - 50)
          : _fetchLogs;

      await prefs.setStringList('nasa_fetch_logs', logsToKeep);
    } catch (e) {
      print('Error saving analytics: $e');
    }
  }

  Future<void> _logFetch(String event, {String? details}) async {
    final log = '${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}: $event${details != null ? ' - $details' : ''}';
    _fetchLogs.add(log);
    await _saveAnalytics();
  }

  Future<void> fetchNASAData(
      double latitude,
      double longitude,
      {bool forceRefresh = false}
      ) async {
    await _fetchWithRetry(latitude, longitude, forceRefresh: forceRefresh);
  }

  Future<void> _fetchWithRetry(
      double latitude,
      double longitude,
      {bool forceRefresh = false, int attempt = 1}
      ) async {
    try {
      // Validate coordinates
      if (!_validateCoordinates(latitude, longitude)) {
        _error = 'Invalid coordinates: Latitude must be between -90 and 90, Longitude between -180 and 180';
        _status = 'Error';
        notifyListeners();
        return;
      }

      // Check cache
      if (!forceRefresh && isCacheValid && hasData) {
        _status = 'Using cached data';
        print('Using cached NASA data (last fetch: $_lastFetchTime)');
        notifyListeners();
        return;
      }

      _isLoading = true;
      _error = '';
      _status = 'Fetching data...';
      _retryCount = attempt;
      notifyListeners();

      await _logFetch('Fetch attempt $attempt', details: 'lat=$latitude, lon=$longitude');

      // Calculate date range
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: 30));
      final endDate = now;

      // NASA POWER parameters for agriculture
      final parameters = [
        'T2M',           // Temperature at 2m (°C)
        'T2M_MAX',       // Maximum temperature (°C)
        'T2M_MIN',       // Minimum temperature (°C)
        'PRECTOTCORR',   // Precipitation (mm/day)
        'RH2M',          // Relative humidity at 2m (%)
        'WS2M',          // Wind speed at 2m (m/s)
        'WS2M_MAX',      // Maximum wind speed (m/s)
        'ALLSKY_SFC_SW_DWN',  // Solar radiation (kW/m²/day)
        'ALLSKY_KT',     // Clearness index
        'CLOUD_AMT',     // Cloud amount (%)
      ].join(',');

      // Build URL
      final url = Uri.parse(
          '$_baseUrl?parameters=$parameters'
              '&community=AG'
              '&longitude=$longitude'
              '&latitude=$latitude'
              '&start=${DateFormat('yyyyMMdd').format(startDate)}'
              '&end=${DateFormat('yyyyMMdd').format(endDate)}'
              '&format=JSON'
      );

      print('NASA POWER Request: ${url.toString()}');

      // Make API call
      _status = 'Connecting to NASA...';
      notifyListeners();

      final response = await http.get(url).timeout(_timeoutDuration);

      _progressController.add(0.5);

      if (response.statusCode == 200) {
        _status = 'Processing data...';
        notifyListeners();

        final data = json.decode(response.body);
        await _parseNASAData(data, latitude, longitude);

        _lastFetchTime = DateTime.now();
        await _cacheData();
        await _updateAnalytics();

        _status = 'Data loaded successfully';
        _error = '';

        await _logFetch('Fetch successful',
            details: '${_historicalData.length} days loaded');

        print('NASA POWER data fetched successfully: ${_historicalData.length} days');
      } else {
        throw HttpException(
            'NASA POWER API returned status code: ${response.statusCode}',
            response.statusCode
        );
      }
    } on TimeoutException catch (e) {
      _error = 'Request timed out. Please check your internet connection.';
      await _logFetch('Timeout error', details: e.toString());

      if (attempt < _maxRetryAttempts) {
        print('Retrying fetch (attempt $attempt of $_maxRetryAttempts)...');
        await Future.delayed(Duration(seconds: 2));
        await _fetchWithRetry(latitude, longitude,
            forceRefresh: forceRefresh, attempt: attempt + 1);
        return;
      }
    } on HttpException catch (e) {
      _error = 'Server error: ${e.message}';
      await _logFetch('HTTP error ${e.statusCode}', details: e.message);
    } on SocketException catch (e) {
      _error = 'Network error: Please check your internet connection.';
      await _logFetch('Network error', details: e.toString());
    } on FormatException catch (e) {
      _error = 'Data format error: Invalid response from server.';
      await _logFetch('Format error', details: e.toString());
    } catch (e, stackTrace) {
      _error = 'Unexpected error: $e';
      await _logFetch('Unexpected error', details: '$e\n$stackTrace');
      print('Error stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      _progressController.add(1.0);
      notifyListeners();

      // Reset progress after delay
      Future.delayed(Duration(milliseconds: 500), () {
        _progressController.add(0.0);
      });
    }
  }

  bool _validateCoordinates(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180;
  }

  Future<void> _parseNASAData(Map<String, dynamic> data, double lat, double lon) async {
    try {
      print('Parsing NASA POWER data...');

      final properties = data['properties']['parameter'];

      // Check for error messages
      if (properties.containsKey('messages')) {
        final messages = properties['messages'];
        print('NASA POWER messages: $messages');
      }

      // Get dates from temperature data
      final tempData = properties['T2M'];
      if (tempData == null || tempData is! Map) {
        throw Exception('No valid temperature data in response');
      }

      final dates = (tempData as Map<String, dynamic>).keys.toList();
      print('Found ${dates.length} days of data');

      if (dates.isEmpty) {
        throw Exception('No date data available');
      }

      _historicalData.clear();

      int processed = 0;
      for (final dateStr in dates) {
        try {
          final date = DateTime.parse(dateStr);

          // Get all parameters with validation
          final temperature = _getDoubleValue(properties['T2M']?[dateStr]);
          final maxTemp = _getDoubleValue(properties['T2M_MAX']?[dateStr]);
          final minTemp = _getDoubleValue(properties['T2M_MIN']?[dateStr]);
          final humidity = _getDoubleValue(properties['RH2M']?[dateStr]);
          final precipitation = _getDoubleValue(properties['PRECTOTCORR']?[dateStr]);
          final windSpeed = _getDoubleValue(properties['WS2M']?[dateStr]);
          final maxWindSpeed = _getDoubleValue(properties['WS2M_MAX']?[dateStr]);
          final solarRadiation = _getDoubleValue(properties['ALLSKY_SFC_SW_DWN']?[dateStr]);
          final clearnessIndex = _getDoubleValue(properties['ALLSKY_KT']?[dateStr]);
          final cloudAmount = _getDoubleValue(properties['CLOUD_AMT']?[dateStr]);

          // Validate data
          if (!_isValidTemperature(temperature) ||
              !_isValidHumidity(humidity) ||
              !_isValidPrecipitation(precipitation)) {
            print('Skipping invalid data for $dateStr');
            continue;
          }

          // Calculate derived parameters
          final estimatedSoilMoisture = _estimateSoilMoisture(
              precipitation, temperature, humidity, solarRadiation, windSpeed
          );

          final estimatedSoilTemperature = _estimateSoilTemperature(
              minTemp, maxTemp, temperature
          );

          final evapotranspiration = _estimateEvapotranspiration(
              temperature, humidity, windSpeed, solarRadiation
          );

          // Create weather data object
          final weatherData = WeatherData(
            temperature: temperature,
            humidity: humidity,
            precipitation: precipitation,
            windSpeed: windSpeed,
            weatherCode: _getWeatherCode(precipitation, cloudAmount, temperature),
            time: date,
            soilMoisture: estimatedSoilMoisture,
            soilTemperature: estimatedSoilTemperature,
            solarRadiation: solarRadiation,
            airQualityIndex: _estimateAirQuality(temperature, humidity, windSpeed),
          );

          _historicalData.add(weatherData);

          // Update current data to the most recent
          if (_currentData == null || date.isAfter(_currentData!.time)) {
            _currentData = weatherData;
          }

          processed++;

          // Update progress
          if (processed % 5 == 0) {
            _progressController.add(0.5 + (processed / dates.length) * 0.3);
          }
        } catch (e) {
          print('Error parsing data for date $dateStr: $e');
        }
      }

      // Sort by date (most recent first)
      _historicalData.sort((a, b) => b.time.compareTo(a.time));

      print('Successfully parsed $processed/${dates.length} days of NASA POWER data');

      if (_currentData != null) {
        print('Current data: '
            'Temp=${_currentData!.temperature.toStringAsFixed(1)}°C, '
            'Rain=${_currentData!.precipitation.toStringAsFixed(1)}mm, '
            'Humidity=${_currentData!.humidity.toStringAsFixed(0)}%, '
            'Solar=${_currentData!.solarRadiation?.toStringAsFixed(2) ?? "N/A"}kWh/m²');
      }

    } catch (e, stackTrace) {
      print('Error parsing NASA POWER data: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Error parsing NASA POWER data: $e');
    }
  }

  String _getWeatherCode(double precipitation, double cloudAmount, double temperature) {
    if (precipitation > 5.0) return '80'; // Heavy rain
    if (precipitation > 0.1) return '60'; // Rain
    if (cloudAmount > 70) return '3'; // Cloudy
    if (cloudAmount > 30) return '2'; // Partly cloudy
    if (temperature < 0 && precipitation > 0) return '70'; // Snow
    return '1'; // Clear
  }

  double _estimateSoilMoisture(
      double precipitation,
      double temperature,
      double humidity,
      double solarRadiation,
      double windSpeed
      ) {
    // Simple water balance model
    const baseMoisture = 40.0;

    // Precipitation effect (capped)
    final precipEffect = min(precipitation * 1.5, 30.0);

    // Evapotranspiration effect
    final et = 0.5 * solarRadiation +
        0.2 * max(0, temperature - 15) -
        0.1 * min(humidity, 80);

    // Temperature effect
    final tempEffect = temperature > 25 ? (temperature - 25) * -0.5 : 0.0;

    // Humidity effect
    final humidityEffect = humidity > 70 ? 5.0 : 0.0;

    // Wind effect (drying)
    final windEffect = windSpeed > 5 ? (windSpeed - 5) * -0.5 : 0.0;

    final moisture = baseMoisture + precipEffect - et + tempEffect + humidityEffect + windEffect;

    return moisture.clamp(0.0, 100.0);
  }

  double _estimateSoilTemperature(double minTemp, double maxTemp, double avgTemp) {
    // Soil temperature follows air temperature with damping
    // More stable than air temperature
    final soilTemp = (minTemp * 0.6 + maxTemp * 0.4);
    return soilTemp.clamp(avgTemp - 8, avgTemp + 3);
  }

  double _estimateEvapotranspiration(
      double temperature,
      double humidity,
      double windSpeed,
      double solarRadiation
      ) {
    // Simplified Hargreaves equation
    const lambda = 2.45; // Latent heat of vaporization (MJ/kg)

    final et0 = 0.0023 *
        (temperature + 17.8) *
        sqrt(max(temperature - 5, 0)) *
        solarRadiation / lambda;

    // Adjust for humidity and wind
    final humidityFactor = 1 - (humidity / 100) * 0.5;
    final windFactor = 1 + (windSpeed / 10) * 0.2;

    return max(et0 * humidityFactor * windFactor, 0.0);
  }

  double _estimateAirQuality(double temperature, double humidity, double windSpeed) {
    // Simplified AQI estimation
    double aqi = 50.0; // Base value (good)

    // Temperature effect (high temps can increase pollution)
    if (temperature > 30) aqi += (temperature - 30) * 2;

    // Humidity effect (high humidity can trap pollutants)
    if (humidity > 80) aqi += 10;
    else if (humidity < 30) aqi += 5; // Dry conditions can increase dust

    // Wind effect (higher winds disperse pollutants)
    if (windSpeed > 5) aqi -= min(windSpeed * 2, 20);

    return aqi.clamp(0, 300);
  }

  double _getDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  bool _isValidTemperature(double temp) {
    return temp >= -50 && temp <= 60;
  }

  bool _isValidHumidity(double humidity) {
    return humidity >= 0 && humidity <= 100;
  }

  bool _isValidPrecipitation(double precipitation) {
    return precipitation >= 0 && precipitation <= 500;
  }

  Future<void> _updateAnalytics() async {
    if (_historicalData.isEmpty) return;

    _analytics = {
      'lastUpdate': DateTime.now().toIso8601String(),
      'totalDataPoints': _historicalData.length,
      'dateRange': {
        'start': _historicalData.last.time.toIso8601String(),
        'end': _historicalData.first.time.toIso8601String(),
        'days': _historicalData.first.time.difference(_historicalData.last.time).inDays,
      },
      'averages': {
        'temperature': getAverageTemperature(),
        'precipitation': getAveragePrecipitation(),
        'humidity': getAverageHumidity(),
        'solarRadiation': getAverageSolarRadiation(),
        'soilMoisture': getAverageSoilMoisture(),
      },
      'extremes': {
        'maxTemp': getMaxTemperature(),
        'minTemp': getMinTemperature(),
        'maxRain': getMaxPrecipitation(),
        'maxWind': getMaxWindSpeed(),
      },
      'trends': _calculateTrends(),
    };

    await _saveAnalytics();
  }

  Map<String, dynamic> _calculateTrends() {
    if (_historicalData.length < 7) return {};

    // Get recent data
    final recentWeek = _historicalData.take(7).toList();
    final previousWeek = _historicalData.skip(7).take(7).toList();

    if (previousWeek.isEmpty || recentWeek.isEmpty) return {};

    // Calculate averages
    double calculateAverage(List<WeatherData> data, double Function(WeatherData) selector) {
      return data.map(selector).reduce((a, b) => a + b) / data.length;
    }

    final recentAvgTemp = calculateAverage(recentWeek, (d) => d.temperature);
    final previousAvgTemp = calculateAverage(previousWeek, (d) => d.temperature);

    final recentAvgRain = calculateAverage(recentWeek, (d) => d.precipitation);
    final previousAvgRain = calculateAverage(previousWeek, (d) => d.precipitation);

    return {
      'temperatureChange': recentAvgTemp - previousAvgTemp,
      'precipitationChange': recentAvgRain - previousAvgRain,
      'temperatureTrend': recentAvgTemp > previousAvgTemp ? 'rising' : 'falling',
      'precipitationTrend': recentAvgRain > previousAvgRain ? 'wetter' : 'drier',
    };
  }

  // Helper method to get last N elements
  List<T> _getLastElements<T>(List<T> list, int count) {
    if (list.length <= count) return List<T>.from(list);
    return list.sublist(list.length - count);
  }

  // Analysis methods
  double getAverageTemperature() {
    if (_historicalData.isEmpty) return 0.0;
    final sum = _historicalData.map((d) => d.temperature).reduce((a, b) => a + b);
    return sum / _historicalData.length;
  }

  double getAveragePrecipitation() {
    if (_historicalData.isEmpty) return 0.0;
    final sum = _historicalData.map((d) => d.precipitation).reduce((a, b) => a + b);
    return sum / _historicalData.length;
  }

  double getAverageHumidity() {
    if (_historicalData.isEmpty) return 0.0;
    final sum = _historicalData.map((d) => d.humidity).reduce((a, b) => a + b);
    return sum / _historicalData.length;
  }

  double getAverageSolarRadiation() {
    if (_historicalData.isEmpty) return 0.0;
    final validData = _historicalData.where((d) => d.solarRadiation != null && d.solarRadiation! > 0).toList();
    if (validData.isEmpty) return 0.0;
    final sum = validData.map((d) => d.solarRadiation!).reduce((a, b) => a + b);
    return sum / validData.length;
  }

  double getAverageSoilMoisture() {
    if (_historicalData.isEmpty) return 0.0;
    final validData = _historicalData.where((d) => d.soilMoisture != null).toList();
    if (validData.isEmpty) return 0.0;
    final sum = validData.map((d) => d.soilMoisture!).reduce((a, b) => a + b);
    return sum / validData.length;
  }

  double getMaxTemperature() {
    if (_historicalData.isEmpty) return 0.0;
    return _historicalData.map((d) => d.temperature).reduce(max);
  }

  double getMinTemperature() {
    if (_historicalData.isEmpty) return 0.0;
    return _historicalData.map((d) => d.temperature).reduce(min);
  }

  double getMaxPrecipitation() {
    if (_historicalData.isEmpty) return 0.0;
    return _historicalData.map((d) => d.precipitation).reduce(max);
  }

  double getMaxWindSpeed() {
    if (_historicalData.isEmpty) return 0.0;
    return _historicalData.map((d) => d.windSpeed).reduce(max);
  }

  List<WeatherData> getLastNDays(int days) {
    if (_historicalData.isEmpty) return [];
    final count = min(days, _historicalData.length);
    return _historicalData.take(count).toList();
  }

  WeatherData? getDataForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);

    for (final data in _historicalData) {
      final dataDate = DateTime(data.time.year, data.time.month, data.time.day);
      if (dataDate == targetDate) {
        return data;
      }
    }

    return _historicalData.isNotEmpty ? _historicalData.first : null;
  }

  Map<String, dynamic> getSolarAnalysis() {
    final solarData = _historicalData
        .where((d) => d.solarRadiation != null && d.solarRadiation! > 0)
        .map((d) => d.solarRadiation!)
        .toList();

    if (solarData.isEmpty) {
      return {
        'total': 0.0,
        'average': 0.0,
        'max': 0.0,
        'min': 0.0,
        'suitableForSolar': false,
        'status': 'No solar data',
        'classification': 'Unknown',
        'dailyAverage': 0.0,
        'efficiency': 0.0,
      };
    }

    final total = solarData.reduce((a, b) => a + b);
    final average = total / solarData.length;
    final maxSolar = solarData.reduce((a, b) => a > b ? a : b);
    final minSolar = solarData.reduce((a, b) => a < b ? a : b);

    String getClassification(double avg) {
      if (avg >= 5.0) return 'Excellent';
      if (avg >= 4.0) return 'Good';
      if (avg >= 3.0) return 'Moderate';
      if (avg >= 2.0) return 'Fair';
      return 'Poor';
    }

    double getEfficiency(double avg) {
      if (avg >= 5.0) return 0.85;
      if (avg >= 4.0) return 0.75;
      if (avg >= 3.0) return 0.65;
      if (avg >= 2.0) return 0.55;
      return 0.45;
    }

    return {
      'total': total,
      'average': average,
      'max': maxSolar,
      'min': minSolar,
      'suitableForSolar': average >= 3.0,
      'status': getClassification(average),
      'classification': getClassification(average),
      'dailyAverage': average,
      'efficiency': getEfficiency(average),
      'energyPotential': average * 0.18 * 1000, // kWh per 1000 m²
    };
  }

  Map<String, dynamic> getSoilAnalysis() {
    if (_historicalData.isEmpty) {
      return {
        'averageMoisture': 0.0,
        'averageTemperature': 0.0,
        'moistureStatus': 'Unknown',
        'temperatureStatus': 'Unknown',
        'moistureLevel': 0,
        'temperatureLevel': 0,
        'irrigationRequired': false,
        'plantingSuitable': false,
        'trend': 'stable',
      };
    }

    final recentData = getLastNDays(7);
    if (recentData.isEmpty) return {};

    final moistureData = recentData
        .where((d) => d.soilMoisture != null)
        .map((d) => d.soilMoisture!)
        .toList();

    final tempData = recentData
        .where((d) => d.soilTemperature != null)
        .map((d) => d.soilTemperature!)
        .toList();

    if (moistureData.isEmpty || tempData.isEmpty) {
      return {
        'averageMoisture': 0.0,
        'averageTemperature': 0.0,
        'moistureStatus': 'No data',
        'temperatureStatus': 'No data',
        'moistureLevel': 0,
        'temperatureLevel': 0,
        'irrigationRequired': false,
        'plantingSuitable': false,
        'trend': 'unknown',
      };
    }

    final avgMoisture = moistureData.reduce((a, b) => a + b) / moistureData.length;
    final avgTemp = tempData.reduce((a, b) => a + b) / tempData.length;

    String getMoistureStatus(double moisture) {
      if (moisture < 15) return 'Very Dry';
      if (moisture < 30) return 'Dry';
      if (moisture < 50) return 'Optimal';
      if (moisture < 70) return 'Moist';
      return 'Saturated';
    }

    int getMoistureLevel(double moisture) {
      if (moisture < 15) return 1;
      if (moisture < 30) return 2;
      if (moisture < 50) return 3;
      if (moisture < 70) return 4;
      return 5;
    }

    String getTemperatureStatus(double temp) {
      if (temp < 5) return 'Very Cold';
      if (temp < 10) return 'Cold';
      if (temp < 25) return 'Optimal';
      if (temp < 30) return 'Warm';
      return 'Hot';
    }

    int getTemperatureLevel(double temp) {
      if (temp < 5) return 1;
      if (temp < 10) return 2;
      if (temp < 25) return 3;
      if (temp < 30) return 4;
      return 5;
    }

    bool isIrrigationRequired(double moisture) {
      return moisture < 30;
    }

    bool isPlantingSuitable(double moisture, double temp) {
      return moisture >= 30 && moisture <= 70 && temp >= 10 && temp <= 25;
    }

    String getTrend(List<double> values) {
      if (values.length < 2) return 'stable';
      final first = values.first;
      final last = values.last;
      final change = last - first;

      if (change > 2) return 'rising';
      if (change < -2) return 'falling';
      return 'stable';
    }

    return {
      'averageMoisture': avgMoisture,
      'averageTemperature': avgTemp,
      'moistureStatus': getMoistureStatus(avgMoisture),
      'temperatureStatus': getTemperatureStatus(avgTemp),
      'moistureLevel': getMoistureLevel(avgMoisture),
      'temperatureLevel': getTemperatureLevel(avgTemp),
      'irrigationRequired': isIrrigationRequired(avgMoisture),
      'plantingSuitable': isPlantingSuitable(avgMoisture, avgTemp),
      'trend': getTrend(moistureData),
      'moistureTrend': getTrend(moistureData),
      'temperatureTrend': getTrend(tempData),
    };
  }

  Map<String, dynamic> getWeatherSummary() {
    if (_currentData == null) {
      return {
        'status': 'No data',
        'temperature': 0.0,
        'condition': 'Unknown',
        'recommendations': ['Fetch weather data first'],
      };
    }

    final data = _currentData!;
    final soilAnalysis = getSoilAnalysis();
    final solarAnalysis = getSolarAnalysis();

    String getCondition(double temp, double precipitation) {
      if (precipitation > 10) return 'Heavy Rain';
      if (precipitation > 2) return 'Rain';
      if (temp > 30) return 'Hot';
      if (temp > 20) return 'Warm';
      if (temp > 10) return 'Cool';
      return 'Cold';
    }

    List<String> getRecommendations() {
      final recommendations = <String>[];

      if (data.precipitation > 20) {
        recommendations.add('Heavy rainfall expected - ensure proper drainage');
      } else if (data.precipitation < 1 && data.temperature > 25) {
        recommendations.add('Dry and hot conditions - irrigation recommended');
      }

      if (soilAnalysis['irrigationRequired'] == true) {
        recommendations.add('Soil moisture low - consider irrigation');
      }

      if (data.temperature < 5) {
        recommendations.add('Frost risk - protect sensitive crops');
      } else if (data.temperature > 35) {
        recommendations.add('Heat stress risk - provide shade if possible');
      }

      if (solarAnalysis['suitableForSolar'] == true) {
        recommendations.add('Good solar conditions - solar irrigation recommended');
      }

      if (recommendations.isEmpty) {
        recommendations.add('Weather conditions are favorable for most crops');
      }

      return recommendations;
    }

    return {
      'status': 'Current',
      'temperature': data.temperature,
      'humidity': data.humidity,
      'precipitation': data.precipitation,
      'windSpeed': data.windSpeed,
      'condition': getCondition(data.temperature, data.precipitation),
      'soilMoisture': data.soilMoisture,
      'soilTemperature': data.soilTemperature,
      'solarRadiation': data.solarRadiation,
      'recommendations': getRecommendations(),
      'timestamp': data.time.toIso8601String(),
      'isFavorable': data.temperature >= 10 &&
          data.temperature <= 30 &&
          data.precipitation >= 1 &&
          data.precipitation <= 20,
    };
  }

  void clearData() {
    _historicalData.clear();
    _currentData = null;
    _error = '';
    _status = 'Data cleared';
    notifyListeners();
  }

  void clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove('nasa_analytics');
      await prefs.remove('nasa_fetch_logs');

      clearData();
      _analytics = {};
      _fetchLogs = [];

      _status = 'Cache cleared';
      print('NASA POWER cache cleared');
      notifyListeners();
    } catch (e) {
      _error = 'Error clearing cache: $e';
      notifyListeners();
    }
  }

  Future<void> refreshData(double latitude, double longitude) async {
    await fetchNASAData(latitude, longitude, forceRefresh: true);
  }

  // Helper to check data availability for specific date range
  bool hasDataForRange(DateTime start, DateTime end) {
    if (_historicalData.isEmpty) return false;

    final dataStart = _historicalData.last.time;
    final dataEnd = _historicalData.first.time;

    return start.isAfter(dataStart) && end.isBefore(dataEnd);
  }

  // Export data for backup or sharing
  Map<String, dynamic> exportData() {
    return {
      'metadata': {
        'exportDate': DateTime.now().toIso8601String(),
        'dataPoints': _historicalData.length,
        'source': 'NASA POWER',
        'version': '2.0',
      },
      'currentData': _currentData?.toJson(),
      'historicalData': _historicalData.map((d) => d.toJson()).toList(),
      'analytics': _analytics,
      'summary': getWeatherSummary(),
      'solarAnalysis': getSolarAnalysis(),
      'soilAnalysis': getSoilAnalysis(),
    };
  }

  // Get recent logs (last N)
  List<String> getRecentLogs(int count) {
    if (_fetchLogs.isEmpty) return [];
    return _getLastElements(_fetchLogs, count);
  }

  // Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final totalFetches = _fetchLogs.where((log) => log.contains('Fetch attempt')).length;
    final successfulFetches = _fetchLogs.where((log) => log.contains('Fetch successful')).length;
    final errorFetches = totalFetches - successfulFetches;

    return {
      'totalFetches': totalFetches,
      'successfulFetches': successfulFetches,
      'errorFetches': errorFetches,
      'successRate': totalFetches > 0 ? (successfulFetches / totalFetches) * 100 : 0,
      'lastFetch': _lastFetchTime?.toIso8601String(),
      'cacheStatus': isCacheValid ? 'Valid' : 'Expired',
      'dataAge': _lastFetchTime != null ?
      '${DateTime.now().difference(_lastFetchTime!).inHours} hours' : 'Unknown',
    };
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }
}

// Custom exceptions
class HttpException implements Exception {
  final String message;
  final int statusCode;

  HttpException(this.message, this.statusCode);

  @override
  String toString() => 'HttpException: $message (Status: $statusCode)';
}

// Extension for List utilities
extension ListUtils<T> on List<T> {
  List<T> takeLast(int count) {
    if (count <= 0) return [];
    if (count >= length) return List<T>.from(this);
    return sublist(length - count);
  }
}