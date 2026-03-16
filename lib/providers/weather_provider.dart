import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';

class WeatherProvider with ChangeNotifier {
  WeatherData? _currentWeather;
  List<WeatherData> _forecast = [];
  List<WeatherData> _historicalData = [];
  Position? _currentPosition;
  String _locationName = '';
  bool _isLoading = false;
  String _error = '';
  double? _elevation;
  String? _timeZone;

  WeatherData? get currentWeather => _currentWeather;
  List<WeatherData> get forecast => _forecast;
  List<WeatherData> get historicalData => _historicalData;
  Position? get currentPosition => _currentPosition;
  String get locationName => _locationName;
  bool get isLoading => _isLoading;
  String get error => _error;
  double? get elevation => _elevation;
  String? get timeZone => _timeZone;

  // Add setters for currentPosition and locationName
  set currentPosition(Position? position) {
    _currentPosition = position;
    notifyListeners();
  }

  set locationName(String name) {
    _locationName = name;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_weather_data');

    if (cachedData != null) {
      try {
        final data = json.decode(cachedData);
        _currentWeather = WeatherData.fromJson(data['currentWeather']);
        _forecast = (data['forecast'] as List)
            .map((item) => WeatherData.fromJson(item))
            .toList();
        _historicalData = (data['historicalData'] as List)
            .map((item) => WeatherData.fromJson(item))
            .toList();
        _locationName = data['locationName'] ?? '';
        notifyListeners();
      } catch (e) {
        print('Error loading cached data: $e');
      }
    }
  }

  Future<void> _cacheData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'currentWeather': _currentWeather?.toJson(),
      'forecast': _forecast.map((w) => w.toJson()).toList(),
      'historicalData': _historicalData.map((w) => w.toJson()).toList(),
      'locationName': _locationName,
    };
    prefs.setString('cached_weather_data', json.encode(data));
  }

  Future<void> getCurrentLocation() async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location permissions.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      // Get position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get location name
      await _getLocationName(_currentPosition!.latitude, _currentPosition!.longitude);

      // Fetch all weather data
      await Future.wait([
        fetchOpenMeteoData(_currentPosition!.latitude, _currentPosition!.longitude),
        fetchElevation(_currentPosition!.latitude, _currentPosition!.longitude),
      ]);

      await _cacheData();
    } catch (e) {
      _error = e.toString();
      print('Location error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getLocationName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        _locationName = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}'.trim();
        if (_locationName.isEmpty) {
          _locationName = '${placemark.country ?? ''}';
        }
      }
    } catch (e) {
      _locationName = 'Unknown Location';
      print('Geocoding error: $e');
    }
  }

  // Add these methods to your WeatherProvider class

  Future<List<WeatherData>> fetchWeatherForecast(double lat, double lon, {int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
                '?latitude=$lat'
                '&longitude=$lon'
                '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,relative_humidity_2m_max'
                '&timezone=auto'
                '&forecast_days=$days'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final forecast = <WeatherData>[];
        final daily = data['daily'];

        for (int i = 0; i < (daily['time'] as List).length; i++) {
          forecast.add(WeatherData(
            temperature: daily['temperature_2m_max'][i]?.toDouble() ?? 0.0,
            humidity: daily['relative_humidity_2m_max']?[i]?.toDouble() ?? 65.0,
            precipitation: daily['precipitation_sum'][i]?.toDouble() ?? 0.0,
            windSpeed: daily['wind_speed_10m_max']?[i]?.toDouble() ?? 10.0,
            weatherCode: daily['weather_code'][i]?.toString() ?? '0',
            time: DateTime.parse(daily['time'][i]),
          ));
        }

        return forecast;
      } else {
        throw Exception('Failed to fetch forecast: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching weather forecast: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchHistoricalWeather(double lat, double lon, DateTime date) async {
    try {
      // Fetch data for the same date last year
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = startDate.add(Duration(days: 1));

      final response = await http.get(
        Uri.parse(
            'https://archive-api.open-meteo.com/v1/archive'
                '?latitude=$lat'
                '&longitude=$lon'
                '&start_date=${DateFormat('yyyy-MM-dd').format(startDate)}'
                '&end_date=${DateFormat('yyyy-MM-dd').format(endDate)}'
                '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,relative_humidity_2m_max,wind_speed_10m_max'
                '&hourly=temperature_2m,relative_humidity_2m,precipitation'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final daily = data['daily'];
        final hourly = data['hourly'];

        // Calculate average conditions for the day
        double avgTemp = 0;
        double avgHumidity = 0;
        double totalPrecip = 0;

        if (hourly != null && hourly['time'] != null) {
          final temps = (hourly['temperature_2m'] as List).map((e) => e?.toDouble() ?? 0).toList();
          final humidities = (hourly['relative_humidity_2m'] as List).map((e) => e?.toDouble() ?? 0).toList();
          final precipitations = (hourly['precipitation'] as List).map((e) => e?.toDouble() ?? 0).toList();

          avgTemp = temps.isEmpty ? 0 : temps.reduce((a, b) => a + b) / temps.length;
          avgHumidity = humidities.isEmpty ? 65 : humidities.reduce((a, b) => a + b) / humidities.length;
          totalPrecip = precipitations.isEmpty ? 0 : precipitations.reduce((a, b) => a + b);
        }

        return {
          'temperature': avgTemp,
          'humidity': avgHumidity,
          'precipitation': totalPrecip,
          'windSpeed': daily['wind_speed_10m_max']?[0]?.toDouble() ?? 10.0,
          'weatherCode': daily['weather_code']?[0]?.toString() ?? '0',
          'date': startDate.toIso8601String(),
          'maxTemp': daily['temperature_2m_max']?[0]?.toDouble() ?? avgTemp,
          'minTemp': daily['temperature_2m_min']?[0]?.toDouble() ?? avgTemp,
        };
      } else {
        throw Exception('Failed to fetch historical data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching historical weather: $e');
      // Return fallback data with reasonable defaults
      return {
        'temperature': 25.0,
        'humidity': 65.0,
        'precipitation': 0.0,
        'windSpeed': 10.0,
        'weatherCode': '0',
        'date': date.toIso8601String(),
        'maxTemp': 25.0,
        'minTemp': 20.0,
      };
    }
  }

// Also add a method to fetch 30-day forecast for monthly outlook
  Future<List<WeatherData>> fetchMonthlyForecast(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
                '?latitude=$lat'
                '&longitude=$lon'
                '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max'
                '&timezone=auto'
                '&forecast_days=30'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final forecast = <WeatherData>[];
        final daily = data['daily'];

        for (int i = 0; i < (daily['time'] as List).length; i++) {
          forecast.add(WeatherData(
            temperature: daily['temperature_2m_max'][i]?.toDouble() ?? 0.0,
            humidity: 65.0, // Default value
            precipitation: daily['precipitation_sum'][i]?.toDouble() ?? 0.0,
            windSpeed: daily['wind_speed_10m_max']?[i]?.toDouble() ?? 10.0,
            weatherCode: daily['weather_code'][i]?.toString() ?? '0',
            time: DateTime.parse(daily['time'][i]),
          ));
        }

        return forecast;
      } else {
        throw Exception('Failed to fetch monthly forecast: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching monthly forecast: $e');
      return [];
    }
  }

// Update the _parseOpenMeteoData method to include humidity and wind speed from forecast
  Future<void> _parseOpenMeteoData(Map<String, dynamic> forecastData, Map<String, dynamic> historicalData) async {
    // Parse current weather
    final current = forecastData['current'];
    _currentWeather = WeatherData(
      temperature: current['temperature_2m']?.toDouble() ?? 0.0,
      humidity: current['relative_humidity_2m']?.toDouble() ?? 0.0,
      precipitation: current['precipitation']?.toDouble() ?? 0.0,
      windSpeed: current['wind_speed_10m']?.toDouble() ?? 0.0,
      weatherCode: current['weather_code']?.toString() ?? '0',
      time: DateTime.now(),
    );

    // Parse forecast with better data
    final daily = forecastData['daily'];
    _forecast.clear();

    for (int i = 0; i < (daily['time'] as List).length; i++) {
      _forecast.add(WeatherData(
        temperature: daily['temperature_2m_max'][i]?.toDouble() ?? 0.0,
        humidity: daily['relative_humidity_2m_max']?[i]?.toDouble() ?? 65.0,
        precipitation: daily['precipitation_sum'][i]?.toDouble() ?? 0.0,
        windSpeed: daily['wind_speed_10m_max']?[i]?.toDouble() ?? 10.0,
        weatherCode: daily['weather_code'][i]?.toString() ?? '0',
        time: DateTime.parse(daily['time'][i]),
      ));
    }

    // Parse historical data
    final historicalDaily = historicalData['daily'];
    _historicalData.clear();

    for (int i = 0; i < (historicalDaily['time'] as List).length; i++) {
      _historicalData.add(WeatherData(
        temperature: (historicalDaily['temperature_2m_max'][i]?.toDouble() ?? 0.0 +
            historicalDaily['temperature_2m_min'][i]?.toDouble() ?? 0.0) / 2,
        humidity: 65.0, // Default value as historical humidity might not be available
        precipitation: historicalDaily['precipitation_sum'][i]?.toDouble() ?? 0.0,
        windSpeed: 10.0, // Default value
        weatherCode: '0',
        time: DateTime.parse(historicalDaily['time'][i]),
      ));
    }

    _timeZone = forecastData['timezone']?.toString();

    notifyListeners();
  }

  Future<void> fetchGoogleWeatherData(double lat, double lon) async {
    try {
      // Replace with your Google API key
      const googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(Duration(days: 30));

      // Google Weather API endpoint
      final weatherResponse = await http.get(
        Uri.parse(
            'https://weatherkit.googleapis.com/v1/weather/current'
                '?latitude=$lat'
                '&longitude=$lon'
                '&dataSets=currentWeather,forecastDaily,forecastHourly'
                '&key=$googleApiKey'
        ),
      );

      if (weatherResponse.statusCode == 200) {
        await _parseGoogleWeatherData(json.decode(weatherResponse.body));
      } else if (weatherResponse.statusCode == 403) {
        throw Exception('Google API key not valid or quota exceeded');
      } else {
        throw Exception('Failed to fetch weather data from Google: ${weatherResponse.statusCode}');
      }
    } catch (e) {
      _error = 'Weather data error: $e';
      print('Google Weather API error: $e');
    }
  }

  Future<void> _parseGoogleWeatherData(Map<String, dynamic> data) async {
    try {
      // Parse current weather
      final currentWeather = data['currentWeather'];
      final currentConditions = currentWeather['conditions'];

      _currentWeather = WeatherData(
        temperature: currentConditions['temperature']?.toDouble() ?? 0.0,
        humidity: (currentConditions['humidity']?.toDouble() ?? 0.0) * 100, // Convert to percentage
        precipitation: currentConditions['precipitationIntensity']?.toDouble() ?? 0.0,
        windSpeed: currentConditions['windSpeed']?.toDouble() ?? 0.0,
        weatherCode: _convertGoogleWeatherCode(currentConditions['conditionCode'] ?? ''),
        time: DateTime.now(),
      );

      // Parse daily forecast
      final forecastDaily = data['forecastDaily'];
      final dailyDays = forecastDaily['days'];
      _forecast.clear();

      for (final day in dailyDays) {
        final daytimeForecast = day['daytimeForecast'];
        _forecast.add(WeatherData(
          temperature: daytimeForecast['temperatureMax']?.toDouble() ?? 0.0,
          humidity: (daytimeForecast['humidity']?.toDouble() ?? 0.65) * 100,
          precipitation: daytimeForecast['precipitationAmount']?.toDouble() ?? 0.0,
          windSpeed: daytimeForecast['windSpeed']?.toDouble() ?? 0.0,
          weatherCode: _convertGoogleWeatherCode(daytimeForecast['conditionCode'] ?? ''),
          time: DateTime.parse(day['forecastStart']),
        ));
      }

      // Parse hourly forecast (for historical simulation - you might need to adjust this)
      final forecastHourly = data['forecastHourly'];
      final hourlyHours = forecastHourly['hours'];
      _historicalData.clear();

      // Use hourly data for last 30 days simulation
      // Note: Google Weather API doesn't provide historical data directly
      // This is a simulation using current hourly data
      final now = DateTime.now();
      for (int i = 0; i < min(24 * 7, hourlyHours.length); i++) {
        final hour = hourlyHours[i];
        _historicalData.add(WeatherData(
          temperature: hour['temperature']?.toDouble() ?? 0.0,
          humidity: (hour['humidity']?.toDouble() ?? 0.65) * 100,
          precipitation: hour['precipitationIntensity']?.toDouble() ?? 0.0,
          windSpeed: hour['windSpeed']?.toDouble() ?? 0.0,
          weatherCode: _convertGoogleWeatherCode(hour['conditionCode'] ?? ''),
          time: now.add(Duration(hours: i)),
        ));
      }

      _timeZone = data['timezone']?.toString() ?? 'UTC';

      notifyListeners();
    } catch (e) {
      print('Error parsing Google Weather data: $e');
      throw Exception('Failed to parse weather data');
    }
  }

  String _convertGoogleWeatherCode(String googleCode) {
    // Map Google Weather condition codes to WMO codes used in your app
    final codeMap = {
      'Clear': '0',
      'MostlyClear': '1',
      'PartlyCloudy': '2',
      'Cloudy': '3',
      'Foggy': '45',
      'LightRain': '61',
      'Rain': '63',
      'HeavyRain': '65',
      'LightSnow': '71',
      'Snow': '73',
      'HeavySnow': '75',
      'Sleet': '77',
      'Thunderstorm': '95',
      'ThunderstormWithRain': '95',
      'ThunderstormWithSnow': '96',
      'Windy': '3', // Default to cloudy
      'Hail': '99',
      'Hot': '0', // Clear
      'Cold': '3', // Cloudy
      'Drizzle': '51',
      'Showers': '80',
    };

    return codeMap[googleCode] ?? '0';
  }

  Future<void> fetchOpenMeteoData(double lat, double lon) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      // Fetch current weather and forecast
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(Duration(days: 30));

      final forecastResponse = await http.get(
        Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
                '?latitude=$lat'
                '&longitude=$lon'
                '&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code,is_day'
                '&hourly=temperature_2m,relative_humidity_2m,precipitation,weather_code'
                '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,sunshine_duration'
                '&timezone=auto'
                '&forecast_days=7'
        ),
      );

      final historicalResponse = await http.get(
        Uri.parse(
            'https://archive-api.open-meteo.com/v1/archive'
                '?latitude=$lat'
                '&longitude=$lon'
                '&start_date=${DateFormat('yyyy-MM-dd').format(thirtyDaysAgo)}'
                '&end_date=${DateFormat('yyyy-MM-dd').format(now)}'
                '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum'
        ),
      );

      if (forecastResponse.statusCode == 200 && historicalResponse.statusCode == 200) {
        await _parseOpenMeteoData(
          json.decode(forecastResponse.body),
          json.decode(historicalResponse.body),
        );
        await _cacheData();
      } else {
        throw Exception('Failed to fetch weather data');
      }
    } catch (e) {
      _error = 'Weather data error: $e';
      print('OpenMeteo error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Future<void> _parseOpenMeteoData(Map<String, dynamic> forecastData, Map<String, dynamic> historicalData) async {
  //   // Parse current weather
  //   final current = forecastData['current'];
  //   _currentWeather = WeatherData(
  //     temperature: current['temperature_2m']?.toDouble() ?? 0.0,
  //     humidity: current['relative_humidity_2m']?.toDouble() ?? 0.0,
  //     precipitation: current['precipitation']?.toDouble() ?? 0.0,
  //     windSpeed: current['wind_speed_10m']?.toDouble() ?? 0.0,
  //     weatherCode: current['weather_code']?.toString() ?? '0',
  //     time: DateTime.now(),
  //   );
  //
  //   // Parse forecast
  //   final daily = forecastData['daily'];
  //   _forecast.clear();
  //
  //   for (int i = 0; i < (daily['time'] as List).length; i++) {
  //     _forecast.add(WeatherData(
  //       temperature: daily['temperature_2m_max'][i]?.toDouble() ?? 0.0,
  //       humidity: 65.0, // Default value
  //       precipitation: daily['precipitation_sum'][i]?.toDouble() ?? 0.0,
  //       windSpeed: 10.0, // Default value
  //       weatherCode: daily['weather_code'][i]?.toString() ?? '0',
  //       time: DateTime.parse(daily['time'][i]),
  //     ));
  //   }
  //
  //   // Parse historical data
  //   final historicalDaily = historicalData['daily'];
  //   _historicalData.clear();
  //
  //   for (int i = 0; i < (historicalDaily['time'] as List).length; i++) {
  //     _historicalData.add(WeatherData(
  //       temperature: historicalDaily['temperature_2m_max'][i]?.toDouble() ?? 0.0,
  //       humidity: 65.0,
  //       precipitation: historicalDaily['precipitation_sum'][i]?.toDouble() ?? 0.0,
  //       windSpeed: 10.0,
  //       weatherCode: '0',
  //       time: DateTime.parse(historicalDaily['time'][i]),
  //     ));
  //   }
  //
  //   _timeZone = forecastData['timezone']?.toString();
  //
  //   notifyListeners();
  // }

  Future<void> fetchElevation(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.open-meteo.com/v1/elevation'
                '?latitude=$lat'
                '&longitude=$lon'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _elevation = data['elevation']?[0]?.toDouble();
        notifyListeners();
      }
    } catch (e) {
      print('Elevation error: $e');
    }
  }

  Future<void> fetchWeatherByCoordinates(double lat, double lon) async {
    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      // Create a Position object without altitudeAccuracy
      _currentPosition = Position(
        longitude: lon,
        latitude: lat,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      await _getLocationName(lat, lon);
      await Future.wait([
        fetchOpenMeteoData(lat, lon),
        fetchElevation(lat, lon),
      ]);

      await _cacheData();
    } catch (e) {
      _error = e.toString();
      print('Weather by coordinates error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String getWeatherDescription(String code) {
    final weatherCodes = {
      '0': 'Clear sky',
      '1': 'Mainly clear',
      '2': 'Partly cloudy',
      '3': 'Overcast',
      '45': 'Fog',
      '48': 'Depositing rime fog',
      '51': 'Light drizzle',
      '53': 'Moderate drizzle',
      '55': 'Dense drizzle',
      '56': 'Light freezing drizzle',
      '57': 'Dense freezing drizzle',
      '61': 'Slight rain',
      '63': 'Moderate rain',
      '65': 'Heavy rain',
      '66': 'Light freezing rain',
      '67': 'Heavy freezing rain',
      '71': 'Slight snow fall',
      '73': 'Moderate snow fall',
      '75': 'Heavy snow fall',
      '77': 'Snow grains',
      '80': 'Slight rain showers',
      '81': 'Moderate rain showers',
      '82': 'Violent rain showers',
      '85': 'Slight snow showers',
      '86': 'Heavy snow showers',
      '95': 'Thunderstorm',
      '96': 'Thunderstorm with slight hail',
      '99': 'Thunderstorm with heavy hail',
    };
    return weatherCodes[code] ?? 'Unknown';
  }

  IconData getWeatherIcon(String code) {
    final weatherIcons = {
      '0': Icons.wb_sunny,
      '1': Icons.wb_sunny,
      '2': Icons.wb_cloudy,
      '3': Icons.cloud,
      '45': Icons.foggy,
      '48': Icons.foggy,
      '51': Icons.grain,
      '53': Icons.grain,
      '55': Icons.grain,
      '56': Icons.ac_unit,
      '57': Icons.ac_unit,
      '61': Icons.beach_access,
      '63': Icons.beach_access,
      '65': Icons.beach_access,
      '66': Icons.ac_unit,
      '67': Icons.ac_unit,
      '71': Icons.ac_unit,
      '73': Icons.ac_unit,
      '75': Icons.ac_unit,
      '77': Icons.ac_unit,
      '80': Icons.beach_access,
      '81': Icons.beach_access,
      '82': Icons.beach_access,
      '85': Icons.ac_unit,
      '86': Icons.ac_unit,
      '95': Icons.thunderstorm,
      '96': Icons.thunderstorm,
      '99': Icons.thunderstorm,
    };
    return weatherIcons[code] ?? Icons.help;
  }

  Color getWeatherColor(String code) {
    if (['0', '1', '2'].contains(code)) return Colors.orange;
    if (['3', '45', '48'].contains(code)) return Colors.grey;
    if (code.startsWith('5') || code.startsWith('6') || code.startsWith('8')) return Colors.blue;
    if (code.startsWith('7') || code == '56' || code == '57' || code == '66' || code == '67') return Colors.lightBlue;
    if (code.startsWith('9')) return Colors.purple;
    return Colors.grey;
  }

  String getAirQualityText(double? aqi) {
    if (aqi == null) return 'N/A';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  Color getAirQualityColor(double? aqi) {
    if (aqi == null) return Colors.grey;
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  double calculateEvapotranspiration(double temp, double humidity, double windSpeed, double solarRadiation) {
    // Simplified Hargreaves-Samani equation
    final now = DateTime.now();
    final delta = 0.409 * sin((2 * pi / 365) * _getDayOfYear(now) - 1.39);
    final phi = _currentPosition?.latitude ?? 0.0;
    final dr = 1 + 0.033 * cos((2 * pi / 365) * _getDayOfYear(now));
    final omega = acos(-tan(phi) * tan(delta));
    final ra = 24 * 60 / pi * 0.082 * dr * (omega * sin(phi) * sin(delta) + cos(phi) * cos(delta) * sin(omega));

    final et = 0.0023 * (temp + 17.8) * sqrt(temp - _getDewPoint(temp, humidity)) * ra / 2.45;
    return max(et, 0);
  }

  double _getDewPoint(double temp, double humidity) {
    final a = 17.27;
    final b = 237.7;
    final alpha = ((a * temp) / (b + temp)) + log(humidity / 100);
    return (b * alpha) / (a - alpha);
  }

  // Helper method to get day of year
  int _getDayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}