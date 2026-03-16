import 'package:flutter/material.dart';

class AppConstants {
  // API Endpoints
  static const String openMeteoBaseUrl = 'https://api.open-meteo.com/v1';
  static const String nasaPowerBaseUrl = 'https://power.larc.nasa.gov/api/temporal/daily/point';
  static const String faoBaseUrl = 'http://www.fao.org';

  // Default values
  static const double defaultLatitude = 28.6139; // New Delhi
  static const double defaultLongitude = 77.2090;

  // Cache durations
  static const int weatherCacheDurationHours = 1;
  static const int nasaCacheDurationHours = 6;
  static const int faoCacheDurationDays = 30;

  // Agricultural constants
  static const Map<String, double> cropCoefficients = {
    'Rice': 1.2,
    'Wheat': 1.0,
    'Maize': 1.1,
    'Soybean': 1.0,
    'Cotton': 1.15,
    'Sugarcane': 1.3,
    'Potato': 1.1,
    'Tomato': 1.05,
    'Barley': 0.9,
    'Millet': 0.8,
  };

  static const Map<String, List<String>> cropSeasons = {
    'Kharif': ['June', 'July', 'August', 'September', 'October'],
    'Rabi': ['November', 'December', 'January', 'February', 'March'],
    'Zaid': ['April', 'May'],
  };

  static const Map<String, String> soilTypeDescriptions = {
    'Clay': 'Fine particles, high water retention, poor drainage',
    'Loamy': 'Balanced mixture, good water retention and drainage',
    'Sandy': 'Large particles, excellent drainage, low water retention',
    'Clay Loam': 'More clay than loam, moderate drainage',
    'Sandy Loam': 'More sand than loam, good drainage',
    'Silt': 'Medium particles, good water retention',
  };

  // Weather thresholds
  static const double heatWaveThreshold = 35.0; // °C
  static const double frostThreshold = 5.0; // °C
  static const double heavyRainThreshold = 20.0; // mm/day
  static const double strongWindThreshold = 30.0; // km/h

  // Soil thresholds
  static const double drySoilMoistureThreshold = 30.0; // %
  static const double wetSoilMoistureThreshold = 80.0; // %
  static const double coldSoilTemperatureThreshold = 15.0; // °C
  static const double hotSoilTemperatureThreshold = 30.0; // °C

  // Solar radiation thresholds
  static const double lowSolarRadiationThreshold = 3.0; // kWh/m²/day
  static const double highSolarRadiationThreshold = 7.0; // kWh/m²/day

  // App settings
  static const int defaultChartDays = 30;
  static const int maxHistoricalDays = 365;
  static const int refreshIntervalMinutes = 15;

  // Colors for different advisory types
  static const Map<String, Color> advisoryColors = {
    'weather': Colors.blue,
    'soil': Colors.brown,
    'irrigation': Colors.lightBlue,
    'pest': Colors.red,
    'disease': Colors.purple,
    'harvest': Colors.orange,
    'general': Colors.green,
  };

  // Severity colors
  static final Map<String, Color> severityColors = {
    'critical': Colors.red,
    'alert': Colors.orange,
    'warning': Colors.amber,
    'info': Colors.blue,
  };
}

class CropConstants {
  // Growth stages in days
  static const Map<String, List<int>> growthStages = {
    'Rice': [7, 30, 60, 90, 120],
    'Wheat': [7, 30, 60, 90, 110],
    'Maize': [7, 25, 50, 75, 90],
    'Cotton': [10, 40, 80, 120, 180],
    'Soybean': [7, 30, 60, 80, 100],
    'Sugarcane': [30, 90, 180, 270, 365],
  };

  // Water requirements (mm/season)
  static const Map<String, int> waterRequirements = {
    'Rice': 1500,
    'Wheat': 450,
    'Maize': 600,
    'Cotton': 700,
    'Soybean': 500,
    'Sugarcane': 1500,
    'Potato': 400,
    'Tomato': 600,
  };

  // Optimal temperature ranges (°C)
  static const Map<String, List<double>> temperatureRanges = {
    'Rice': [20.0, 35.0],
    'Wheat': [10.0, 25.0],
    'Maize': [15.0, 30.0],
    'Cotton': [21.0, 35.0],
    'Soybean': [20.0, 30.0],
    'Sugarcane': [20.0, 35.0],
  };
}

class SoilConstants {
  // Soil moisture categories
  static const Map<String, List<double>> moistureCategories = {
    'Very Dry': [0.0, 20.0],
    'Dry': [20.0, 40.0],
    'Optimal': [40.0, 70.0],
    'Moist': [70.0, 85.0],
    'Saturated': [85.0, 100.0],
  };

  // Soil temperature categories
  static const Map<String, List<double>> temperatureCategories = {
    'Very Cold': [-10.0, 5.0],
    'Cold': [5.0, 15.0],
    'Optimal': [15.0, 25.0],
    'Warm': [25.0, 35.0],
    'Hot': [35.0, 50.0],
  };

  // Soil pH preferences
  static const Map<String, List<double>> phPreferences = {
    'Most Crops': [6.0, 7.5],
    'Acid Loving': [4.5, 6.5],
    'Alkaline Tolerant': [7.0, 8.5],
  };
}

class WeatherConstants {
  // Weather code mappings
  static const Map<int, String> weatherCodeDescriptions = {
    0: 'Clear sky',
    1: 'Mainly clear',
    2: 'Partly cloudy',
    3: 'Overcast',
    45: 'Fog',
    48: 'Depositing rime fog',
    51: 'Light drizzle',
    53: 'Moderate drizzle',
    55: 'Dense drizzle',
    61: 'Slight rain',
    63: 'Moderate rain',
    65: 'Heavy rain',
    71: 'Slight snow fall',
    73: 'Moderate snow fall',
    75: 'Heavy snow fall',
    80: 'Slight rain showers',
    81: 'Moderate rain showers',
    82: 'Violent rain showers',
    95: 'Thunderstorm',
    96: 'Thunderstorm with slight hail',
    99: 'Thunderstorm with heavy hail',
  };

  // Wind speed categories (km/h)
  static const Map<String, List<double>> windCategories = {
    'Calm': [0.0, 5.0],
    'Light Breeze': [5.0, 20.0],
    'Moderate Wind': [20.0, 40.0],
    'Strong Wind': [40.0, 60.0],
    'Gale': [60.0, 100.0],
    'Storm': [100.0, 200.0],
  };

  // Humidity categories
  static const Map<String, List<double>> humidityCategories = {
    'Very Dry': [0.0, 30.0],
    'Dry': [30.0, 50.0],
    'Comfortable': [50.0, 70.0],
    'Humid': [70.0, 85.0],
    'Very Humid': [85.0, 100.0],
  };
}