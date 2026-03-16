// screens/crop_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/crop_model.dart';
import '../providers/weather_provider.dart';
import '../providers/nasa_power_provider.dart';
import '../providers/fao_provider.dart';
import '../providers/soil_api_provider.dart';

class CropAnalysisScreen extends StatefulWidget {
  @override
  _CropAnalysisScreenState createState() => _CropAnalysisScreenState();
}

class _CropAnalysisScreenState extends State<CropAnalysisScreen> {
  String _selectedSeason = 'Kharif';
  bool _isAnalyzing = false;
  List<Crop> _recommendedCrops = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentSeason();
  }

  void _loadCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 10) {
      _selectedSeason = 'Kharif';
    } else {
      _selectedSeason = 'Rabi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = context.watch<WeatherProvider>();
    final nasaProvider = context.watch<NASAPowerProvider>();
    final faoProvider = context.watch<FAOProvider>();
    final soilApiProvider = context.watch<SoilApiProvider>();

    final weather = weatherProvider.currentWeather;
    final nasaData = nasaProvider.currentData;
    final soilData = soilApiProvider.currentSoilData;
    final integratedRecommendations = faoProvider.integratedRecommendations;

    return Scaffold(
      appBar: AppBar(
        title: Text('Crop Analysis'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Conditions Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Conditions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildConditionItem(
                            'Temperature',
                            '${weather?.temperature.toStringAsFixed(1) ?? 'N/A'}°C',
                            Icons.thermostat,
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _buildConditionItem(
                            'Rainfall',
                            nasaData?.precipitation != null
                                ? '${(nasaData!.precipitation * 365).toStringAsFixed(0)} mm/yr'
                                : weather?.precipitation != null
                                ? '${(weather!.precipitation * 365).toStringAsFixed(0)} mm/yr'
                                : 'N/A',
                            Icons.water_drop,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildConditionItem(
                            'Soil pH',
                            '${soilData?.pH?.toStringAsFixed(1) ?? 'N/A'}',
                            Icons.assessment,
                            Colors.purple,
                          ),
                        ),
                        Expanded(
                          child: _buildConditionItem(
                            'Soil Type',
                            soilData?.soilType ?? 'N/A',
                            Icons.terrain,
                            Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (soilData?.organicMatter != null)
                      Row(
                        children: [
                          Expanded(
                            child: _buildConditionItem(
                              'Organic Matter',
                              '${soilData!.organicMatter!.toStringAsFixed(1)}%',
                              Icons.eco,
                              Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildConditionItem(
                              'Season',
                              _selectedSeason,
                              Icons.calendar_today,
                              Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Season Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Season',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    SegmentedButton(
                      segments: [
                        ButtonSegment(
                          value: 'Kharif',
                          label: Text('Kharif (Jun-Oct)'),
                          icon: Icon(Icons.wb_sunny),
                        ),
                        ButtonSegment(
                          value: 'Rabi',
                          label: Text('Rabi (Nov-Apr)'),
                          icon: Icon(Icons.ac_unit),
                        ),
                        ButtonSegment(
                          value: 'Year Round',
                          label: Text('Year Round'),
                          icon: Icon(Icons.autorenew),
                        ),
                      ],
                      selected: {_selectedSeason},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedSeason = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Analyze Button
            Center(
              child: ElevatedButton.icon(
                icon: _isAnalyzing
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(Icons.analytics),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Crops'),
                onPressed: () async {
                  if (weather == null || nasaData == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please wait for weather data to load')),
                    );
                    return;
                  }

                  setState(() {
                    _isAnalyzing = true;
                  });

                  try {
                    await faoProvider.analyzeWithWeatherAndSoil(
                      weather: weather!,
                      soilAnalysis: soilData,
                      annualRainfall: nasaData.precipitation * 365,
                      latitude: weatherProvider.currentPosition?.latitude ?? 0.0,
                      longitude: weatherProvider.currentPosition?.longitude ?? 0.0,
                      prioritizeDroughtTolerance: nasaData.precipitation * 365 < 600,
                      specificSeason: _selectedSeason,
                    );

                    // Extract crops from integrated recommendations
                    _recommendedCrops = faoProvider.integratedRecommendations
                        .map((rec) => rec.crop)
                        .toList();

                    if (_recommendedCrops.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No suitable crops found for current conditions'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Analysis failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() {
                      _isAnalyzing = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Show integrated recommendations if available
            if (integratedRecommendations.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integrated Crop Recommendations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Based on weather, soil analysis, and season',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  SizedBox(height: 12),
                  ...integratedRecommendations.map((recommendation) {
                    return _buildCropRecommendationCard(recommendation as CropRecommendation);
                  }).toList(),
                ],
              ),

            // Show simple crop recommendations if integrated ones are empty but we have crops
            if (integratedRecommendations.isEmpty && _recommendedCrops.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended Crops',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  ..._recommendedCrops.map((crop) {
                    return _buildDetailedCropCard(crop);
                  }).toList(),
                ],
              ),

            // No recommendations yet
            if (integratedRecommendations.isEmpty && _recommendedCrops.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.agriculture, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No crop recommendations yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Click "Analyze Crops" to get recommendations',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCropRecommendationCard(CropRecommendation recommendation) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getScoreColor(recommendation.score),
                  child: Text(
                    recommendation.score.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.crop.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${recommendation.suitabilityLevel} • ${recommendation.crop.scientificName}',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(recommendation.crop.season),
                  backgroundColor: recommendation.crop.season == 'Kharif'
                      ? Colors.green[100]
                      : Colors.orange[100],
                ),
              ],
            ),

            SizedBox(height: 12),

            // Reasons for recommendation
            if (recommendation.reasons.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why this crop:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  ...recommendation.reasons.take(3).map((reason) =>
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(child: Text(reason)),
                          ],
                        ),
                      )
                  ).toList(),
                ],
              ),

            SizedBox(height: 12),

            // Planting Advice
            if (recommendation.plantingAdvice.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planting Advice:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    recommendation.plantingAdvice,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),

            SizedBox(height: 12),

            // Risk Factors
            if (recommendation.riskFactors.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Factors:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  SizedBox(height: 4),
                  ...recommendation.riskFactors.take(2).map((risk) =>
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(child: Text(risk)),
                          ],
                        ),
                      )
                  ).toList(),
                ],
              ),

            SizedBox(height: 12),

            // Estimated Yield
            if (recommendation.estimatedYield['estimated'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Yield:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${recommendation.estimatedYield['estimated'].toStringAsFixed(1)} ${recommendation.estimatedYield['unit']} '
                        '(${recommendation.estimatedYield['confidence']} confidence)',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedCropCard(Crop crop) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    crop.name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(crop.season),
                  backgroundColor: crop.season == 'Kharif' ? Colors.green[100] : Colors.orange[100],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              crop.scientificName,
              style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 12),
            if (crop.description.isNotEmpty)
              Text(
                crop.description,
                style: TextStyle(fontSize: 14),
              ),
            SizedBox(height: 16),

            // Climate Requirements
            Text(
              'Climate Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (crop.climateRequirements['tempMin'] != null && crop.climateRequirements['tempMax'] != null)
                  _buildRequirementChip(
                    'Temperature',
                    '${crop.climateRequirements['tempMin']}-${crop.climateRequirements['tempMax']}°C',
                    Colors.orange,
                  ),
                if (crop.climateRequirements['rainfallMin'] != null && crop.climateRequirements['rainfallMax'] != null)
                  _buildRequirementChip(
                    'Rainfall',
                    '${crop.climateRequirements['rainfallMin']}-${crop.climateRequirements['rainfallMax']} mm/yr',
                    Colors.blue,
                  ),
                if (crop.climateRequirements['waterRequirement'] != null)
                  _buildRequirementChip(
                    'Water Need',
                    '${crop.climateRequirements['waterRequirement']} mm',
                    Colors.lightBlue,
                  ),
              ].where((chip) => chip != null).toList(),
            ),

            SizedBox(height: 16),

            // Soil Requirements
            Text(
              'Soil Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (crop.soilRequirements['phMin'] != null && crop.soilRequirements['phMax'] != null)
                  _buildRequirementChip(
                    'pH',
                    '${crop.soilRequirements['phMin']}-${crop.soilRequirements['phMax']}',
                    Colors.purple,
                  ),
                if (crop.soilRequirements['soilTypes'] != null && (crop.soilRequirements['soilTypes'] as List).isNotEmpty)
                  _buildRequirementChip(
                    'Soil Type',
                    (crop.soilRequirements['soilTypes'] as List).join(', '),
                    Colors.brown,
                  ),
                if (crop.soilRequirements['nitrogen'] != null)
                  _buildRequirementChip(
                    'Nitrogen',
                    crop.soilRequirements['nitrogen'] ?? 'Medium',
                    Colors.green,
                  ),
                if (crop.soilRequirements['phosphorus'] != null)
                  _buildRequirementChip(
                    'Phosphorus',
                    crop.soilRequirements['phosphorus'] ?? 'Medium',
                    Colors.orange,
                  ),
                if (crop.soilRequirements['potassium'] != null)
                  _buildRequirementChip(
                    'Potassium',
                    crop.soilRequirements['potassium'] ?? 'Medium',
                    Colors.blue,
                  ),
              ].where((chip) => chip != null).toList(),
            ),

            SizedBox(height: 16),

            // Regions
            if (crop.regions.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commonly Grown In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: crop.regions.map((region) => Chip(
                      label: Text(region),
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(fontSize: 12),
                    )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementChip(String label, String value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Text(
          label.substring(0, 1),
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
      label: Text('$label: $value'),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(fontSize: 12, color: Colors.black87),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.lightGreen;
    if (score >= 55) return Colors.orange;
    if (score >= 40) return Colors.orangeAccent;
    return Colors.red;
  }
}

// Add CropRecommendation class if not already defined
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
}