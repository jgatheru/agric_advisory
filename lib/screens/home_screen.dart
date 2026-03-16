import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../models/crop_model.dart';
import '../models/weather_models.dart';
import '../models/soil_data.dart';
import '../providers/weather_provider.dart';
import '../providers/nasa_power_provider.dart';
import '../providers/fao_provider.dart';
import '../providers/crop_provider.dart';
import '../providers/soil_api_provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _loadingSoilData = false;
  bool _fetchingLocation = false;
  String _locationName = 'Unknown Location';
  final ScrollController _scrollController = ScrollController();

  // Weather predictions
  List<WeatherData> _weeklyForecast = [];
  List<WeatherData> _monthlyForecast = [];
  Map<String, dynamic>? _lastYearWeather;
  bool _loadingForecast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isInitialized) {
      _refreshData();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_fetchingLocation) return;

    setState(() => _fetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      final weatherProvider = context.read<WeatherProvider>();
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      weatherProvider.currentPosition = position;
      await _updateLocationName(position);

    } catch (e) {
      _logError('Error getting location: $e');
      _showSnackBar('Failed to get location: ${_safeSubstring(e.toString(), 80)}', Colors.red);
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _updateLocationName(Position position) async {
    final weatherProvider = context.read<WeatherProvider>();

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final locality = placemark.locality ?? '';
        final administrativeArea = placemark.administrativeArea ?? '';

        _locationName = _formatLocationName(locality, administrativeArea, placemark.country);
      } else {
        _locationName = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      _locationName = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    }

    weatherProvider.locationName = _locationName;
  }

  String _formatLocationName(String locality, String administrativeArea, String? country) {
    if (locality.isNotEmpty && administrativeArea.isNotEmpty) {
      return '$locality, $administrativeArea';
    } else if (locality.isNotEmpty) {
      return locality;
    } else if (administrativeArea.isNotEmpty) {
      return administrativeArea;
    } else if (country != null) {
      return country;
    }
    return '';
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;

    setState(() => _isRefreshing = true);

    try {
      final weatherProvider = context.read<WeatherProvider>();
      final nasaProvider = context.read<NASAPowerProvider>();
      final faoProvider = context.read<FAOProvider>();
      final soilApiProvider = context.read<SoilApiProvider>();
      final cropProvider = context.read<CropProvider>();

      await weatherProvider.initialize();
      await _getCurrentLocation();

      if (weatherProvider.currentPosition != null) {
        await Future.wait([
          faoProvider.initialize(),
          nasaProvider.initialize(),
        ]);

        final lat = weatherProvider.currentPosition!.latitude;
        final lon = weatherProvider.currentPosition!.longitude;

        await _fetchAllData(weatherProvider, nasaProvider, soilApiProvider, lat, lon);
        await _fetchWeatherPredictions(weatherProvider, lat, lon);
        await _getCropRecommendations(weatherProvider, nasaProvider, faoProvider, soilApiProvider);
      }

      await cropProvider.initialize(context);

      setState(() {
        _isInitialized = true;
        _isRefreshing = false;
      });

    } catch (e) {
      _logError('Initialization error: $e');
      _showSnackBar('Failed to initialize: ${_safeSubstring(e.toString(), 80)}', Colors.red);
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchWeatherPredictions(WeatherProvider weatherProvider, double lat, double lon) async {
    setState(() => _loadingForecast = true);

    try {
      // Fetch weekly forecast (7 days)
      _weeklyForecast = await weatherProvider.fetchWeatherForecast(lat, lon, days: 7);

      // Fetch monthly forecast (30 days)
      _monthlyForecast = await weatherProvider.fetchWeatherForecast(lat, lon, days: 30);

      // Fetch last year's weather data for comparison
      final now = DateTime.now();
      final lastYear = DateTime(now.year - 1, now.month, now.day);
      _lastYearWeather = await weatherProvider.fetchHistoricalWeather(lat, lon, lastYear);

    } catch (e) {
      _logError('Error fetching weather predictions: $e');
    } finally {
      setState(() => _loadingForecast = false);
    }
  }

  Future<void> _fetchAllData(
      WeatherProvider weatherProvider,
      NASAPowerProvider nasaProvider,
      SoilApiProvider soilApiProvider,
      double lat,
      double lon,
      ) async {
    try {
      await Future.wait([
        weatherProvider.fetchOpenMeteoData(lat, lon),
        nasaProvider.fetchNASAData(lat, lon),
        _fetchSoilData(weatherProvider, soilApiProvider),
      ]);
    } catch (e) {
      _logError('Error fetching all data: $e');
      rethrow;
    }
  }

  Future<void> _getCropRecommendations(
      WeatherProvider weatherProvider,
      NASAPowerProvider nasaProvider,
      FAOProvider faoProvider,
      SoilApiProvider soilApiProvider,
      ) async {
    try {
      final weather = weatherProvider.currentWeather;
      final nasaData = nasaProvider.currentData;

      if (weather == null || nasaData == null) {
        _logError('Missing weather or NASA data for crop recommendations');
        return;
      }

      if (soilApiProvider.currentSoilData == null && weatherProvider.currentPosition != null) {
        await _fetchSoilData(weatherProvider, soilApiProvider);
      }

      final soilData = soilApiProvider.currentSoilData;
      if (soilData != null && faoProvider.integratedRecommendations.isEmpty) {
        await faoProvider.analyzeWithWeatherAndSoil(
          weather: weather,
          soilAnalysis: soilData,
          annualRainfall: nasaData.precipitation * 365,
          latitude: weatherProvider.currentPosition!.latitude,
          longitude: weatherProvider.currentPosition!.longitude,
          prioritizeDroughtTolerance: nasaData.precipitation * 365 < 600,
        );
      }
    } catch (e) {
      _logError('Error getting crop recommendations: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final weatherProvider = context.read<WeatherProvider>();

      if (weatherProvider.currentPosition != null) {
        final lat = weatherProvider.currentPosition!.latitude;
        final lon = weatherProvider.currentPosition!.longitude;

        await _fetchAllData(
          weatherProvider,
          context.read<NASAPowerProvider>(),
          context.read<SoilApiProvider>(),
          lat,
          lon,
        );

        await _fetchWeatherPredictions(weatherProvider, lat, lon);

        await _getCropRecommendations(
          weatherProvider,
          context.read<NASAPowerProvider>(),
          context.read<FAOProvider>(),
          context.read<SoilApiProvider>(),
        );
      }

      _showSnackBar('Data refreshed successfully', Colors.green);
    } catch (e) {
      _logError('Refresh error: $e');
      _showSnackBar('Refresh failed: ${_safeSubstring(e.toString(), 80)}', Colors.red);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchSoilData(WeatherProvider weatherProvider, SoilApiProvider soilApiProvider) async {
    if (weatherProvider.currentPosition == null) return;

    setState(() => _loadingSoilData = true);

    try {
      final lat = weatherProvider.currentPosition!.latitude;
      final lon = weatherProvider.currentPosition!.longitude;

      _logInfo('Fetching soil data for: ($lat, $lon)');

      await soilApiProvider.fetchSoilData(
        latitude: lat,
        longitude: lon,
        depth: 30,
        verbose: true,
      );

      if (soilApiProvider.currentSoilData != null) {
        _logInfo('Soil data fetched successfully');
      } else {
        _logWarning('No soil data available after fetch');
        _showSnackBar(
          'Unable to fetch soil data. The API may not have data for this location.',
          Colors.orange,
        );
      }
    } catch (e) {
      _logError('Error fetching soil data: $e');
      _showSnackBar('Error fetching soil data: ${_safeSubstring(e.toString(), 80)}', Colors.red);
    } finally {
      if (mounted) setState(() => _loadingSoilData = false);
    }
  }

  String _safeSubstring(String text, int maxLength) {
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}...';
  }

  void _logError(String message) => print('❌ $message');
  void _logInfo(String message) => print('ℹ️ $message');
  void _logWarning(String message) => print('⚠️ $message');

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AgriWeather Advisor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [_buildAppBarActions()],
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: _buildScrollToTopButton(),
    );
  }

  Widget _buildAppBarActions() {
    return Row(
      children: [
        if (_isRefreshing || _loadingSoilData || _fetchingLocation)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          )
        else
          IconButton(
            icon: Icon(Icons.refresh, size: 22),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 22),
          onSelected: (value) {
            switch (value) {
              case 'debug':
                _debugSoilData();
                break;
              case 'info':
                Navigator.pushNamed(context, '/api_info');
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'debug',
              child: Row(
                children: [
                  Icon(Icons.bug_report, size: 18),
                  SizedBox(width: 8),
                  Text('Debug Soil Data'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Text('API Information'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, child) {
        if (!_isInitialized && (weatherProvider.isLoading || _fetchingLocation)) {
          return _buildLoadingScreen();
        }

        if (weatherProvider.error.isNotEmpty) {
          return _buildErrorScreen(weatherProvider.error);
        }

        if (weatherProvider.currentWeather == null) {
          return _buildWelcomeScreen();
        }

        return _buildMainContent();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedLogo(),
          const SizedBox(height: 24),
          Text(
            _fetchingLocation ? 'Getting your location...' : 'Loading agricultural data...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (!_fetchingLocation)
            Text(
              'Fetching NASA POWER, FAO & Soil Data',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: AlwaysStoppedAnimation(0.25),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.green),
              strokeWidth: 2,
            ),
          ),
          Icon(Icons.agriculture, size: 40, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            'Error Loading Data',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 12),
          Text(
            _safeSubstring(error, 150),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeApp,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.agriculture, size: 60, color: Colors.green),
          ),
          const SizedBox(height: 32),
          Text(
            'AgriWeather Advisor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Get weather-based farming advisories with NASA POWER, FAO & Soil Data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await _getCurrentLocation();
                final weatherProvider = context.read<WeatherProvider>();
                if (weatherProvider.currentPosition != null) {
                  await _initializeApp();
                }
              } catch (e) {
                _showSnackBar('Failed to get location: ${_safeSubstring(e.toString(), 80)}', Colors.red);
              }
            },
            icon: Icon(Icons.my_location),
            label: Text('Get Location & Start Analysis'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: TextStyle(fontSize: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => _showManualLocationDialog(),
            icon: Icon(Icons.location_searching),
            label: Text('Enter Coordinates Manually'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.green,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildLocationHeader(),
            _buildCurrentWeatherCard(),
            _buildWeatherComparisonCard(),
            _buildWeeklyForecast(),
            _buildMonthlyForecast(),
            _buildSoilDataSection(),
            _buildCropRecommendationsSection(),
            _buildQuickActions(),
            _buildWeatherAlerts(),
            _buildCropRecommendationsPreview(),
            _buildDataSourcesInfo(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return FloatingActionButton(
      onPressed: () => _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      child: Icon(Icons.arrow_upward),
      elevation: 4,
    );
  }

  Widget _buildLocationHeader() {
    final weatherProvider = context.watch<WeatherProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[50]!, Colors.lightGreen[50]!],
        ),
        border: Border(bottom: BorderSide(color: Colors.green[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weatherProvider.locationName.isNotEmpty
                      ? weatherProvider.locationName
                      : (_locationName.isNotEmpty ? _locationName : 'Unknown Location'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${weatherProvider.currentPosition?.latitude?.toStringAsFixed(4) ?? 'N/A'}, '
                      '${weatherProvider.currentPosition?.longitude?.toStringAsFixed(4) ?? 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (weatherProvider.elevation != null)
                  Text(
                    'Elevation: ${weatherProvider.elevation!.toStringAsFixed(0)}m',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_location, color: Colors.green),
            onPressed: () => _showManualLocationDialog(),
            tooltip: 'Change Location',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCard() {
    final weatherProvider = context.watch<WeatherProvider>();
    final nasaProvider = context.watch<NASAPowerProvider>();

    final weather = weatherProvider.currentWeather;
    if (weather == null) return SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Weather',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d').format(DateTime.now()),
                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return constraints.maxWidth < 400
                      ? _buildMobileWeatherLayout(weatherProvider, weather, nasaProvider.currentData)
                      : _buildTabletWeatherLayout(weatherProvider, weather, nasaProvider.currentData);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileWeatherLayout(WeatherProvider provider, WeatherData weather, WeatherData? nasaData) {
    return Column(
      children: [
        // Hero section - Temperature and condition
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                provider.getWeatherColor(weather.weatherCode).withOpacity(0.2),
                provider.getWeatherColor(weather.weatherCode).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: weather.temperature > 30 ? Colors.orange[700] :
                  weather.temperature < 10 ? Colors.blue[700] : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    provider.getWeatherIcon(weather.weatherCode),
                    color: provider.getWeatherColor(weather.weatherCode),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    provider.getWeatherDescription(weather.weatherCode),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Feels like ${_calculateFeelsLike(weather.temperature, weather.humidity, weather.windSpeed).toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Weather metrics row
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildVerticalMetric(
                    Icons.water_drop,
                    '${weather.humidity.toStringAsFixed(0)}%',
                    'Humidity',
                    Colors.blue,
                  ),
                  _buildVerticalMetric(
                    Icons.air,
                    '${weather.windSpeed.toStringAsFixed(1)} km/h',
                    'Wind',
                    Colors.blueGrey,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildVerticalMetric(
                    Icons.cloud,
                    '${weather.precipitation.toStringAsFixed(1)} mm',
                    'Rain',
                    Colors.lightBlue,
                  ),
                  if (nasaData?.solarRadiation != null)
                    _buildVerticalMetric(
                      Icons.wb_sunny,
                      '${nasaData!.solarRadiation!.toStringAsFixed(1)} kWh/m²',
                      'Solar',
                      Colors.orange,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalMetric(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

// Enhanced metric tile with more padding and better spacing
  Widget _buildEnhancedWeatherMetricTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16), // Increased padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16), // More rounded
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color), // Increased from 24
          const SizedBox(height: 8), // Increased from 6
          Text(
            value,
            style: TextStyle(
              fontSize: 18, // Increased from 14
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4), // Increased from 2
          Text(
            label,
            style: TextStyle(
              fontSize: 13, // Increased from 12
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

// Additional info tile for extra metrics
  Widget _buildAdditionalWeatherInfo(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

// Helper method to calculate feels like temperature
  double _calculateFeelsLike(double temp, double humidity, double windSpeed) {
    // Simplified heat index calculation
    if (temp >= 27) {
      return -8.78469475556 +
          1.61139411 * temp +
          2.33854883889 * humidity +
          -0.14611605 * temp * humidity +
          -0.012308094 * temp * temp +
          -0.0164248277778 * humidity * humidity +
          0.002211732 * temp * temp * humidity +
          0.00072546 * temp * humidity * humidity +
          -0.000003582 * temp * temp * humidity * humidity;
    }
    // Wind chill calculation for cold temps
    else if (temp <= 10 && windSpeed > 4.8) {
      return 13.12 + 0.6215 * temp - 11.37 * pow(windSpeed, 0.16) + 0.3965 * temp * pow(windSpeed, 0.16);
    }
    return temp;
  }

  Widget _buildTabletWeatherLayout(WeatherProvider provider, WeatherData weather, WeatherData? nasaData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    provider.getWeatherIcon(weather.weatherCode),
                    color: provider.getWeatherColor(weather.weatherCode),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    provider.getWeatherDescription(weather.weatherCode),
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildWeatherMetricTile(
                Icons.water_drop,
                '${weather.humidity.toStringAsFixed(0)}%',
                'Humidity',
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildWeatherMetricTile(
                Icons.air,
                '${weather.windSpeed.toStringAsFixed(1)} km/h',
                'Wind',
                Colors.blueGrey,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildWeatherMetricTile(
                Icons.cloud,
                '${weather.precipitation.toStringAsFixed(1)} mm',
                'Rain',
                Colors.lightBlue,
              ),
              const SizedBox(height: 16),
              if (nasaData?.solarRadiation != null)
                _buildWeatherMetricTile(
                  Icons.wb_sunny,
                  '${nasaData!.solarRadiation!.toStringAsFixed(1)} kWh/m²',
                  'Solar',
                  Colors.orange,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherMetricTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherComparisonCard() {
    if (_loadingForecast || _lastYearWeather == null) {
      return SizedBox();
    }

    final currentWeather = context.watch<WeatherProvider>().currentWeather;
    if (currentWeather == null) return SizedBox();

    final tempDiff = currentWeather.temperature - (_lastYearWeather!['temperature'] ?? 0);
    final rainDiff = currentWeather.precipitation - (_lastYearWeather!['precipitation'] ?? 0);
    final humidityDiff = currentWeather.humidity - (_lastYearWeather!['humidity'] ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Compared to Last Year',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildComparisonMetric(
                  'Temperature',
                  '${_lastYearWeather!['temperature']?.toStringAsFixed(1)}°C',
                  '${currentWeather.temperature.toStringAsFixed(1)}°C',
                  tempDiff,
                  tempDiff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  tempDiff > 0 ? Colors.red : Colors.green,
                ),
                _buildComparisonMetric(
                  'Rainfall',
                  '${_lastYearWeather!['precipitation']?.toStringAsFixed(1)}mm',
                  '${currentWeather.precipitation.toStringAsFixed(1)}mm',
                  rainDiff,
                  rainDiff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  rainDiff > 0 ? Colors.blue : Colors.orange,
                ),
                _buildComparisonMetric(
                  'Humidity',
                  '${_lastYearWeather!['humidity']?.toStringAsFixed(0)}%',
                  '${currentWeather.humidity.toStringAsFixed(0)}%',
                  humidityDiff,
                  humidityDiff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  humidityDiff > 0 ? Colors.blue : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonMetric(String label, String lastYear, String current, double diff, IconData icon, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(lastYear, style: TextStyle(fontSize: 11, color: Colors.grey[500], decoration: TextDecoration.lineThrough)),
        Text(current, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              '${diff.abs().toStringAsFixed(1)}${label == 'Temperature' ? '°C' : label == 'Rainfall' ? 'mm' : '%'}',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyForecast() {
    if (_loadingForecast || _weeklyForecast.isEmpty) {
      return SizedBox();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  '7-Day Forecast',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _weeklyForecast.length,
                itemBuilder: (context, index) {
                  final forecast = _weeklyForecast[index];
                  final date = DateTime.now().add(Duration(days: index));
                  return _buildForecastTile(
                    DateFormat('E').format(date),
                    '${forecast.temperature.toStringAsFixed(0)}°',
                    forecast.weatherCode,
                    forecast.precipitation,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastTile(String day, String temp, String weatherCode, double precipitation) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            _getWeatherIcon(weatherCode), // Now accepts String
            size: 24,
            color: _getWeatherColor(weatherCode), // Now accepts String
          ),
          const SizedBox(height: 4),
          Text(
            temp,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (precipitation > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.water_drop, size: 8, color: Colors.blue),
                const SizedBox(width: 2),
                Text(
                  '${precipitation.toStringAsFixed(0)}mm',
                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyForecast() {
    if (_loadingForecast || _monthlyForecast.isEmpty) {
      return SizedBox();
    }

    // Group by week for better visualization
    final weeklyAverages = <String, Map<String, double>>{};
    for (int i = 0; i < _monthlyForecast.length; i++) {
      final week = (i ~/ 7).toString();
      if (!weeklyAverages.containsKey(week)) {
        weeklyAverages[week] = {'temp': 0, 'precip': 0, 'count': 0};
      }
      weeklyAverages[week]!['temp'] = (weeklyAverages[week]!['temp'] ?? 0) + _monthlyForecast[i].temperature;
      weeklyAverages[week]!['precip'] = (weeklyAverages[week]!['precip'] ?? 0) + _monthlyForecast[i].precipitation;
      weeklyAverages[week]!['count'] = (weeklyAverages[week]!['count'] ?? 0) + 1;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Monthly Outlook',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMonthlyMetric(
                  'Avg Temperature',
                  '${_calculateMonthlyAverage(_monthlyForecast.map((w) => w.temperature).toList()).toStringAsFixed(1)}°C',
                  Icons.thermostat,
                  Colors.orange,
                ),
                _buildMonthlyMetric(
                  'Total Rainfall',
                  '${_calculateMonthlyTotal(_monthlyForecast.map((w) => w.precipitation).toList()).toStringAsFixed(0)}mm',
                  Icons.water_drop,
                  Colors.blue,
                ),
                _buildMonthlyMetric(
                  'Rainy Days',
                  '${_monthlyForecast.where((w) => w.precipitation > 0.5).length} days',
                  Icons.cloud,
                  Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _monthlyForecast.where((w) => w.precipitation > 0.5).length / 30,
              backgroundColor: Colors.grey[200],
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              'Rain probability: ${(_monthlyForecast.where((w) => w.precipitation > 0.5).length * 100 / 30).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  double _calculateMonthlyAverage(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateMonthlyTotal(List<double> values) {
    return values.fold(0, (a, b) => a + b);
  }

  IconData _getWeatherIcon(String code) {
    if (code == '0') return Icons.wb_sunny;
    if (code == '1' || code == '2') return Icons.wb_cloudy;
    if (code == '3') return Icons.cloud;
    if (code == '45' || code == '48') return Icons.foggy;
    if (code.startsWith('5') || code.startsWith('6')) return Icons.grain;
    if (code.startsWith('7')) return Icons.ac_unit;
    if (code.startsWith('8')) return Icons.beach_access;
    if (code.startsWith('9')) return Icons.thunderstorm;
    return Icons.cloud;
  }

  Color _getWeatherColor(String code) {
    if (code == '0') return Colors.orange;
    if (code == '1' || code == '2') return Colors.blueGrey;
    if (code == '3') return Colors.grey;
    if (code == '45' || code == '48') return Colors.grey;
    if (code.startsWith('5') || code.startsWith('6')) return Colors.blue;
    if (code.startsWith('7')) return Colors.lightBlue;
    if (code.startsWith('8')) return Colors.blue;
    if (code.startsWith('9')) return Colors.purple;
    return Colors.grey;
  }

  Widget _buildSoilDataSection() {
    if (_loadingSoilData) return _buildSoilLoadingCard();

    final soilApiProvider = context.watch<SoilApiProvider>();
    final soilData = soilApiProvider.currentSoilData;

    if (soilData == null) return SizedBox();

    return _buildLatestSoilDataCard(soilData);
  }

  Widget _buildSoilLoadingCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: Colors.brown),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading Soil Analysis',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fetching soil nutrient data...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestSoilDataCard(SoilData latestData) {
    final hasValidData = latestData.pH != null ||
        latestData.nitrogen != null ||
        latestData.phosphorus != null ||
        latestData.potassium != null ||
        latestData.organicMatter != null ||
        latestData.soilType != null;

    if (!hasValidData) {
      return Card(
        margin: const EdgeInsets.all(16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 32),
              const SizedBox(height: 12),
              Text(
                'Incomplete Soil Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Some soil parameters could not be retrieved',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final nutrientAnalysis = latestData.getNutrientAnalysis();
    final nutrients = [
      if (latestData.pH != null)
        _NutrientInfo('pH', latestData.pH!.toStringAsFixed(1), nutrientAnalysis['pH'], Colors.purple, Icons.thermostat),
      if (latestData.nitrogen != null)
        _NutrientInfo('N', latestData.nitrogen!.toStringAsFixed(0), nutrientAnalysis['nitrogen'], Colors.green, Icons.grass),
      if (latestData.phosphorus != null)
        _NutrientInfo('P', latestData.phosphorus!.toStringAsFixed(0), nutrientAnalysis['phosphorus'], Colors.orange, Icons.whatshot),
      if (latestData.potassium != null)
        _NutrientInfo('K', latestData.potassium!.toStringAsFixed(0), nutrientAnalysis['potassium'], Colors.blue, Icons.opacity),
      if (latestData.organicMatter != null)
        _NutrientInfo('OM', '${latestData.organicMatter!.toStringAsFixed(1)}%', nutrientAnalysis['organicMatter'], Colors.brown, Icons.eco),
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.purple, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest Soil Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    latestData.source.contains('api') ? 'API' : 'Local',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: latestData.source.contains('api')
                      ? Colors.blue[100]
                      : Colors.orange[100],
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: nutrients.length > 2 ? 3 : nutrients.length,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: nutrients.length,
              itemBuilder: (context, index) => _buildNutrientTile(nutrients[index]),
            ),
            if (latestData.soilType != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.terrain, size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Soil Type',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              latestData.soilType!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last updated: ${DateFormat('MMM dd, HH:mm').format(latestData.date)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/soil'),
                  child: Text('Details', style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientTile(_NutrientInfo info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(info.icon, size: 16, color: info.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: info.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            info.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info.status ?? '',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCropRecommendationsSection() {
    final weatherProvider = context.watch<WeatherProvider>();
    final nasaProvider = context.watch<NASAPowerProvider>();
    final weather = weatherProvider.currentWeather;
    final nasaData = nasaProvider.currentData;

    if (weather == null || nasaData == null) return SizedBox();

    final month = DateTime.now().month;
    final season = month >= 6 && month <= 10 ? 'Kharif' : 'Rabi';
    final faoProvider = context.watch<FAOProvider>();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Crop Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(season),
                  backgroundColor: season == 'Kharif' ? Colors.green[100] : Colors.orange[100],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (faoProvider.isAnalyzing)
              _buildAnalyzingState()
            else if (faoProvider.integratedRecommendations.isNotEmpty)
              _buildCropRecommendationsList(faoProvider.integratedRecommendations.take(3).toList())
            else
              _buildNoRecommendationsState(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Analyzing conditions for crop recommendations...',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCropRecommendationsList(List<dynamic> recommendations) {
    return Column(
      children: recommendations.map((recommendation) {
        final crop = recommendation.crop;
        return _buildCropRecommendationTile(crop);
      }).toList(),
    );
  }

  Widget _buildCropRecommendationTile(Crop crop) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[100]!),
          ),
          child: Center(
            child: Text(
              crop.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ),
        title: Text(
          crop.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crop.scientificName,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(crop.category),
                  backgroundColor: Colors.blue[50],
                  labelStyle: TextStyle(fontSize: 10),
                  padding: EdgeInsets.symmetric(horizontal: 6),
                ),
                if (crop.soilRequirements['phMin'] != null && crop.soilRequirements['phMax'] != null)
                  Chip(
                    label: Text('pH: ${crop.soilRequirements['phMin']}-${crop.soilRequirements['phMax']}'),
                    backgroundColor: Colors.purple[50],
                    labelStyle: TextStyle(fontSize: 10),
                    padding: EdgeInsets.symmetric(horizontal: 6),
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Navigate to crop details screen
          Navigator.pushNamed(context, '/crop_details', arguments: crop);
        },
      ),
    );
  }

  Widget _buildNoRecommendationsState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.spa, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(
          'No crop recommendations yet',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Get personalized crop recommendations based on current weather and soil conditions',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () async {
            final weatherProvider = context.read<WeatherProvider>();
            final soilApiProvider = context.read<SoilApiProvider>();
            final faoProvider = context.read<FAOProvider>();
            final nasaProvider = context.read<NASAPowerProvider>();

            if (weatherProvider.currentPosition != null) {
              if (soilApiProvider.currentSoilData == null) {
                await _fetchSoilData(weatherProvider, soilApiProvider);
              }

              final soilData = soilApiProvider.currentSoilData;

              if (soilData != null) {
                await faoProvider.analyzeWithWeatherAndSoil(
                  weather: weatherProvider.currentWeather!,
                  soilAnalysis: soilData,
                  annualRainfall: nasaProvider.currentData!.precipitation * 365,
                  latitude: weatherProvider.currentPosition!.latitude,
                  longitude: weatherProvider.currentPosition!.longitude,
                  prioritizeDroughtTolerance: nasaProvider.currentData!.precipitation * 365 < 600,
                );
              } else {
                _showSnackBar('Soil data is required for recommendations', Colors.orange);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Get Recommendations'),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 0.9,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _buildActionTile(
                Icons.agriculture,
                'Soil Analysis',
                Colors.brown,
                    () => Navigator.pushNamed(context, '/soil'),
              ),
              _buildActionTile(
                Icons.spa,
                'Crops',
                Colors.green,
                    () => Navigator.pushNamed(context, '/crops'),
              ),
              _buildActionTile(
                Icons.lightbulb,
                'Advisory',
                Colors.orange,
                    () => Navigator.pushNamed(context, '/advisory'),
              ),
              _buildActionTile(
                Icons.satellite,
                'NASA Data',
                Colors.blue,
                    () => Navigator.pushNamed(context, '/nasa'),
              ),
              _buildActionTile(
                Icons.calendar_today,
                'Schedule',
                Colors.purple,
                    () => Navigator.pushNamed(context, '/schedule'),
              ),
              _buildActionTile(
                Icons.warning,
                'Alerts',
                Colors.red,
                    () => Navigator.pushNamed(context, '/alerts'),
              ),
              _buildActionTile(
                Icons.bar_chart,
                'Analytics',
                Colors.teal,
                    () => Navigator.pushNamed(context, '/analytics'),
              ),
              _buildActionTile(
                Icons.settings,
                'Settings',
                Colors.grey,
                    () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherAlerts() {
    final weather = context.watch<WeatherProvider>().currentWeather;
    if (weather == null) return SizedBox();

    final alerts = <_WeatherAlert>[];

    if (weather.precipitation > 20) {
      alerts.add(_WeatherAlert(
        'Heavy Rainfall Alert',
        'Significant rainfall expected. Ensure proper field drainage.',
        Icons.cloud,
        Colors.blue,
      ));
    }

    if (weather.temperature > 35) {
      alerts.add(_WeatherAlert(
        'Heat Wave Warning',
        'High temperatures may cause heat stress to crops.',
        Icons.whatshot,
        Colors.orange,
      ));
    }

    if (weather.temperature < 5) {
      alerts.add(_WeatherAlert(
        'Frost Alert',
        'Low temperatures may damage sensitive crops.',
        Icons.ac_unit,
        Colors.lightBlue,
      ));
    }

    if (weather.windSpeed > 30) {
      alerts.add(_WeatherAlert(
        'Strong Winds',
        'High winds may damage crops and affect pollination.',
        Icons.air,
        Colors.grey,
      ));
    }

    if (alerts.isEmpty) return SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Weather Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: alerts.map((alert) => _buildAlertCard(alert)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(_WeatherAlert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: alert.color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: alert.color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: alert.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(alert.icon, color: alert.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: alert.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropRecommendationsPreview() {
    final faoProvider = context.watch<FAOProvider>();
    final recommendations = faoProvider.integratedRecommendations.isNotEmpty
        ? faoProvider.integratedRecommendations.map((rec) => rec.crop.name).toList()
        : [];

    if (recommendations.isEmpty) return SizedBox();

    final month = DateTime.now().month;
    final season = month >= 6 && month <= 10 ? 'Kharif' : 'Rabi';

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended Crops ($season)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/crops'),
                  child: Text('View All', style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommendations.take(6).map((crop) => Chip(
                label: Text(
                  crop,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                backgroundColor: Colors.green[50],
                side: BorderSide(color: Colors.green[100]!),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: StadiumBorder(),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourcesInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Sources',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildDataSourceChip('Open-Meteo', Colors.blue),
              _buildDataSourceChip('NASA POWER', Colors.blue),
              _buildDataSourceChip('FAO', Colors.green),
              _buildDataSourceChip('Soil Hive', Colors.brown),
              _buildDataSourceChip('Geolocation', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      backgroundColor: color.withOpacity(0.1),
      labelPadding: EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
    );
  }

  void _showManualLocationDialog() {
    final latController = TextEditingController();
    final lonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Coordinates', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g., 28.6139',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lonController,
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g., 77.2090',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);

              if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                Navigator.pop(context);
                await _updateLocationManually(lat, lon);
              } else {
                _showSnackBar('Please enter valid coordinates', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Set Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocationManually(double lat, double lon) async {
    setState(() => _isRefreshing = true);

    try {
      final weatherProvider = context.read<WeatherProvider>();
      final position = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      weatherProvider.currentPosition = position;
      await _updateLocationName(position);

      await Future.wait([
        weatherProvider.fetchOpenMeteoData(lat, lon),
        context.read<NASAPowerProvider>().fetchNASAData(lat, lon),
        context.read<SoilApiProvider>().fetchSoilData(
          latitude: lat,
          longitude: lon,
          depth: 30,
          forceRefresh: true,
          verbose: true,
        ),
      ]);

      await _fetchWeatherPredictions(weatherProvider, lat, lon);

      await _getCropRecommendations(
        weatherProvider,
        context.read<NASAPowerProvider>(),
        context.read<FAOProvider>(),
        context.read<SoilApiProvider>(),
      );
    } catch (e) {
      _showSnackBar('Failed to update location data: ${_safeSubstring(e.toString(), 80)}', Colors.red);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _debugSoilData() {
    final soilApiProvider = context.read<SoilApiProvider>();
    final weatherProvider = context.read<WeatherProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Soil Data Debug', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Position: ${weatherProvider.currentPosition?.latitude?.toStringAsFixed(4)}, '
                  '${weatherProvider.currentPosition?.longitude?.toStringAsFixed(4)}'),
              const SizedBox(height: 12),
              Text('Has soil data: ${soilApiProvider.currentSoilData != null}'),
              const SizedBox(height: 12),
              if (soilApiProvider.currentSoilData != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('pH: ${soilApiProvider.currentSoilData!.pH ?? "N/A"}'),
                      Text('Nitrogen: ${soilApiProvider.currentSoilData!.nitrogen ?? "N/A"}'),
                      Text('Phosphorus: ${soilApiProvider.currentSoilData!.phosphorus ?? "N/A"}'),
                      Text('Potassium: ${soilApiProvider.currentSoilData!.potassium ?? "N/A"}'),
                      Text('Organic Matter: ${soilApiProvider.currentSoilData!.organicMatter ?? "N/A"}'),
                      Text('Soil Type: ${soilApiProvider.currentSoilData!.soilType ?? "N/A"}'),
                      Text('Source: ${soilApiProvider.currentSoilData!.source}'),
                      Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(soilApiProvider.currentSoilData!.date)}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchSoilData(weatherProvider, soilApiProvider);
            },
            child: Text('Fetch Soil Data'),
          ),
        ],
      ),
    );
  }
}

class _NutrientInfo {
  final String label;
  final String value;
  final String? status;
  final Color color;
  final IconData icon;

  _NutrientInfo(this.label, this.value, this.status, this.color, this.icon);
}

class _WeatherAlert {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  _WeatherAlert(this.title, this.message, this.icon, this.color);
}