import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/weather_provider.dart';
import '../providers/nasa_power_provider.dart';
import '../providers/fao_provider.dart';
import '../providers/crop_provider.dart';
import '../models/weather_models.dart';

class CropRecommendationScreen extends StatefulWidget {
  @override
  _CropRecommendationScreenState createState() => _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  String? _selectedSeason;
  String? _selectedSoilType;
  String _searchQuery = '';
  bool _showDetailedView = false;

  final List<String> _seasons = ['Kharif', 'Rabi', 'Year Round'];
  final List<String> _soilTypes = ['Clay', 'Loamy', 'Sandy', 'Clay Loam', 'Sandy Loam', 'All'];

  @override
  void initState() {
    super.initState();
    _selectedSeason = _getCurrentSeason();
    _selectedSoilType = 'All';
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    return month >= 6 && month <= 10 ? 'Kharif' : 'Rabi';
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final nasaProvider = Provider.of<NASAPowerProvider>(context);
    final faoProvider = Provider.of<FAOProvider>(context);
    final cropProvider = Provider.of<CropProvider>(context);

    final weather = weatherProvider.currentWeather;
    final nasaData = nasaProvider.currentData;

    if (weather == null || nasaData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Weather Data Required',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Please fetch weather data from Home screen',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Crop Recommendations'),
        actions: [
          IconButton(
            icon: Icon(_showDetailedView ? Icons.grid_view : Icons.list),
            onPressed: () {
              setState(() {
                _showDetailedView = !_showDetailedView;
              });
            },
            tooltip: _showDetailedView ? 'Grid View' : 'Detailed View',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Crops',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),

                  // Season Filter
                  Row(
                    children: [
                      Text('Season:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: _seasons.map((season) {
                            return FilterChip(
                              label: Text(season),
                              selected: _selectedSeason == season,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSeason = selected ? season : null;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Soil Type Filter
                  Row(
                    children: [
                      Text('Soil Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: _soilTypes.map((soilType) {
                            return FilterChip(
                              label: Text(soilType),
                              selected: _selectedSoilType == soilType,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSoilType = selected ? soilType : null;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Get Recommendations Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                if (_selectedSeason != null) {
                  cropProvider.recommendCrops(
                    context,
                    temperature: nasaData.temperature,
                    rainfall: nasaData.precipitation * 365,
                    soilMoisture: nasaData.soilMoisture ?? 50,
                    soilTemperature: nasaData.soilTemperature ?? 20,
                    solarRadiation: nasaData.solarRadiation ?? 5,
                    soilType: _selectedSoilType ?? 'Loamy',
                    season: _selectedSeason!,
                  );
                }
              },
              icon: Icon(Icons.search),
              label: Text('Get Recommendations'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Results Section
          Expanded(
            child: _buildResultsSection(
              cropProvider,
              weatherProvider,
              nasaProvider,
              faoProvider,
              weather,
              nasaData,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(
      CropProvider cropProvider,
      WeatherProvider weatherProvider,
      NASAPowerProvider nasaProvider,
      FAOProvider faoProvider,
      WeatherData weather,
      WeatherData nasaData,
      ) {
    if (cropProvider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (cropProvider.recommendedCrops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No Crops Found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Try adjusting filters or check conditions',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Filter crops based on search query
    List<String> filteredCrops = cropProvider.recommendedCrops.where((cropName) {
      if (_searchQuery.isEmpty) return true;
      return cropName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredCrops.isEmpty) {
      return Center(
        child: Text('No crops match your search'),
      );
    }

    if (_showDetailedView) {
      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: filteredCrops.length,
        itemBuilder: (context, index) {
          final cropName = filteredCrops[index];
          final analysis = cropProvider.getCropAnalysis(
            context,
            cropName,
            temperature: nasaData.temperature,
            rainfall: nasaData.precipitation * 365,
            soilMoisture: nasaData.soilMoisture ?? 50,
            soilTemperature: nasaData.soilTemperature ?? 20,
            solarRadiation: nasaData.solarRadiation ?? 5,
            soilType: _selectedSoilType ?? 'Loamy',
            season: _selectedSeason ?? 'Year Round',
            humidity: nasaData.humidity,
          );

          return _buildCropDetailCard(
            cropName,
            analysis,
            cropProvider.cropAdvisories[cropName] ?? [],
          );
        },
      );
    } else {
      return GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: filteredCrops.length,
        itemBuilder: (context, index) {
          final cropName = filteredCrops[index];
          return _buildCropCard(
            cropName,
            cropProvider.cropAdvisories[cropName] ?? [],
            onTap: () {
              _showCropDetailsDialog(
                cropName,
                cropProvider,
                weatherProvider,
                nasaProvider,
                faoProvider,
                weather,
                nasaData,
              );
            },
          );
        },
      );
    }
  }

  Widget _buildCropCard(String cropName, List<String> advisories, {VoidCallback? onTap}) {
    final crop = _getCropFromName(cropName);
    if (crop == null) return SizedBox.shrink();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crop Icon and Name
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text(
                      cropName[0],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cropName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Scientific Name
              Text(
                crop.scientificName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 8),

              // Quick Info
              _buildCropInfoItem('Season', crop.season),
              _buildCropInfoItem('Days', '${crop.growthDays}'),
              _buildCropInfoItem('Water', crop.getWaterRequirementText()),

              // Advisories (if any)
              if (advisories.isNotEmpty) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${advisories.length} advisory(s)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropDetailCard(String cropName, Map<String, dynamic> analysis, List<String> advisories) {
    final crop = analysis['crop'] as CropRequirement?;
    if (crop == null) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with suitability badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        crop.scientificName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(analysis['suitabilityLevel'] ?? 'Unknown'),
                  backgroundColor: _getSuitabilityColor(analysis['suitabilityScore'] ?? 0),
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Crop Requirements
            Text(
              'Requirements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildRequirementCard(
                  'Temperature',
                  '${crop.minTemp}-${crop.maxTemp}°C',
                  Icons.thermostat,
                  Colors.red,
                ),
                _buildRequirementCard(
                  'Rainfall',
                  '${crop.minRainfall}-${crop.maxRainfall}mm',
                  Icons.water_drop,
                  Colors.blue,
                ),
                _buildRequirementCard(
                  'Soil Temp',
                  '${crop.optimalSoilTemp}°C',
                  Icons.grass,
                  Colors.brown,
                ),
                _buildRequirementCard(
                  'Soil Moisture',
                  '${crop.optimalSoilMoisture}%',
                  Icons.opacity,
                  Colors.blue[900]!,
                ),
                _buildRequirementCard(
                  'Solar',
                  '${crop.optimalSolarRadiation}kWh/m²',
                  Icons.wb_sunny,
                  Colors.orange,
                ),
                _buildRequirementCard(
                  'Season',
                  crop.season,
                  Icons.calendar_today,
                  Colors.green,
                ),
              ],
            ),

            SizedBox(height: 16),

            // Soil Compatibility
            Text(
              'Soil Compatibility',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: crop.soilTypes.map((soilType) => Chip(
                label: Text(soilType),
                backgroundColor: _selectedSoilType == soilType || _selectedSoilType == 'All'
                    ? Colors.green[100]
                    : Colors.grey[200],
              )).toList(),
            ),

            SizedBox(height: 16),

            // Advisories
            if (advisories.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Advisories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              SizedBox(height: 8),
              ...advisories.map((advice) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        advice,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],

            SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showCropAnalysisDialog(cropName, analysis);
                    },
                    icon: Icon(Icons.analytics),
                    label: Text('Detailed Analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showPlantingGuideDialog(crop);
                    },
                    icon: Icon(Icons.agriculture),
                    label: Text('Planting Guide'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getSuitabilityColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.blue;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  CropRequirement? _getCropFromName(String cropName) {
    final cropProvider = Provider.of<CropProvider>(context, listen: false);
    try {
      return cropProvider.crops.firstWhere((crop) => crop.name == cropName);
    } catch (e) {
      return null;
    }
  }

  void _showCropDetailsDialog(
      String cropName,
      CropProvider cropProvider,
      WeatherProvider weatherProvider,
      NASAPowerProvider nasaProvider,
      FAOProvider faoProvider,
      WeatherData weather,
      WeatherData nasaData,
      ) {
    final analysis = cropProvider.getCropAnalysis(
      context,
      cropName,
      temperature: nasaData.temperature,
      rainfall: nasaData.precipitation * 365,
      soilMoisture: nasaData.soilMoisture ?? 50,
      soilTemperature: nasaData.soilTemperature ?? 20,
      solarRadiation: nasaData.solarRadiation ?? 5,
      soilType: _selectedSoilType ?? 'Loamy',
      season: _selectedSeason ?? 'Year Round',
      humidity: nasaData.humidity,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cropName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Suitability Score
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSuitabilityColor(analysis['suitabilityScore'] ?? 0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getSuitabilityColor(analysis['suitabilityScore'] ?? 0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assessment,
                      color: _getSuitabilityColor(analysis['suitabilityScore'] ?? 0),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suitability: ${analysis['suitabilityLevel'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: analysis['suitabilityScore'] ?? 0,
                            backgroundColor: Colors.grey[200],
                            color: _getSuitabilityColor(analysis['suitabilityScore'] ?? 0),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Score: ${((analysis['suitabilityScore'] ?? 0) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Key Requirements
              Text(
                'Key Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              ..._getKeyRequirements(analysis['crop'] as CropRequirement?),

              // Irrigation Advice
              if (analysis['irrigationAdvice'] != null) ...[
                SizedBox(height: 16),
                Text(
                  'Irrigation Advice',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysis['irrigationAdvice']['advice'] ?? 'No advice available',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildIrrigationMetric(
                            'ET₀',
                            '${analysis['irrigationAdvice']['cropET']?.toStringAsFixed(1) ?? 'N/A'} mm/day',
                          ),
                          SizedBox(width: 16),
                          _buildIrrigationMetric(
                            'Need',
                            '${analysis['irrigationAdvice']['irrigationNeed']?.toStringAsFixed(1) ?? 'N/A'} mm/day',
                          ),
                          SizedBox(width: 16),
                          _buildIrrigationMetric(
                            'Interval',
                            analysis['irrigationAdvice']['irrigationInterval'] != null
                                ? '${analysis['irrigationAdvice']['irrigationInterval']} days'
                                : 'N/A',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Planting Window
              if (analysis['plantingWindow'] != null) ...[
                SizedBox(height: 16),
                Text(
                  'Planting Window',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    analysis['plantingWindow'],
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],

              // Advisories - FIXED SECTION
              if (analysis['advisories'] != null && (analysis['advisories'] as List<String>).isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Advisories',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange[800],
                  ),
                ),
                SizedBox(height: 8),
                ...(analysis['advisories'] as List<String>).map((advice) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          advice,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCropAnalysisDialog(cropName, analysis);
            },
            child: Text('Full Analysis'),
          ),
        ],
      ),
    );
  }

  List<Widget> _getKeyRequirements(CropRequirement? crop) {
    if (crop == null) return [Text('No crop data available')];

    return [
      _buildRequirementRow('Temperature Range', '${crop.minTemp}-${crop.maxTemp}°C'),
      _buildRequirementRow('Annual Rainfall', '${crop.minRainfall}-${crop.maxRainfall} mm'),
      _buildRequirementRow('Water Requirement', '${crop.waterRequirement} mm (${crop.getWaterRequirementText()})'),
      _buildRequirementRow('Growth Period', '${crop.growthDays} days'),
      _buildRequirementRow('Optimal Soil Temp', '${crop.optimalSoilTemp}°C'),
      _buildRequirementRow('Optimal Soil Moisture', '${crop.optimalSoilMoisture}%'),
      _buildRequirementRow('Season', crop.season),
      _buildRequirementRow('Suitable Soil Types', crop.soilTypes.join(', ')),
    ];
  }

  Widget _buildRequirementRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIrrigationMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  void _showCropAnalysisDialog(String cropName, Map<String, dynamic> analysis) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Detailed Analysis: $cropName',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // All analysis sections
                  ..._buildAllAnalysisSections(analysis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAllAnalysisSections(Map<String, dynamic> analysis) {
    final sections = <Widget>[];

    // Suitability Analysis
    sections.add(_buildAnalysisSection(
      'Suitability Analysis',
      Icons.assessment,
      Colors.blue,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score: ${((analysis['suitabilityScore'] ?? 0) * 100).toStringAsFixed(0)}%'),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: analysis['suitabilityScore'] ?? 0,
            backgroundColor: Colors.grey[200],
            color: _getSuitabilityColor(analysis['suitabilityScore'] ?? 0),
          ),
          SizedBox(height: 8),
          Text('Level: ${analysis['suitabilityLevel'] ?? 'Unknown'}'),
        ],
      ),
    ));

    // Irrigation Analysis
    final irrigation = analysis['irrigationAdvice'];
    if (irrigation != null) {
      sections.add(_buildAnalysisSection(
        'Irrigation Analysis',
        Icons.opacity,
        Colors.blue,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisRow('Crop ET', '${irrigation['cropET']?.toStringAsFixed(1) ?? 'N/A'} mm/day'),
            _buildAnalysisRow('Effective Rainfall', '${irrigation['effectiveRainfall']?.toStringAsFixed(1) ?? 'N/A'} mm/day'),
            _buildAnalysisRow('Irrigation Need', '${irrigation['irrigationNeed']?.toStringAsFixed(1) ?? 'N/A'} mm/day'),
            _buildAnalysisRow('Irrigation Interval', '${irrigation['irrigationInterval'] ?? 'N/A'} days'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                irrigation['advice'] ?? 'No advice available',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ));
    }

    // Soil Analysis
    final soil = analysis['soilAnalysis'];
    if (soil != null) {
      sections.add(_buildAnalysisSection(
        'Soil Analysis',
        Icons.grass,
        Colors.brown,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisRow('Average Moisture', '${soil['averageMoisture']?.toStringAsFixed(1) ?? 'N/A'}%'),
            _buildAnalysisRow('Moisture Status', soil['moistureStatus'] ?? 'Unknown'),
            _buildAnalysisRow('Average Temperature', '${soil['averageTemperature']?.toStringAsFixed(1) ?? 'N/A'}°C'),
            _buildAnalysisRow('Temperature Status', soil['temperatureStatus'] ?? 'Unknown'),
          ],
        ),
      ));
    }

    // Solar Analysis
    final solar = analysis['solarAnalysis'];
    if (solar != null) {
      sections.add(_buildAnalysisSection(
        'Solar Radiation Analysis',
        Icons.wb_sunny,
        Colors.orange,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisRow('Average Radiation', '${solar['average']?.toStringAsFixed(2) ?? 'N/A'} kWh/m²'),
            _buildAnalysisRow('Maximum', '${solar['max']?.toStringAsFixed(2) ?? 'N/A'} kWh/m²'),
            _buildAnalysisRow('Minimum', '${solar['min']?.toStringAsFixed(2) ?? 'N/A'} kWh/m²'),
            _buildAnalysisRow('Suitability for Solar', solar['suitableForSolar'] ? 'Good' : 'Low'),
          ],
        ),
      ));
    }

    // Soil Advice
    final soilAdvice = analysis['soilAdvice'];
    if (soilAdvice != null) {
      sections.add(_buildAnalysisSection(
        'Soil Management',
        Icons.agriculture,
        Colors.green,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisRow('Soil Type', soilAdvice['soilType'] ?? 'Unknown'),
            _buildAnalysisRow('Water Retention', soilAdvice['waterRetention'] ?? 'Unknown'),
            _buildAnalysisRow('Drainage', soilAdvice['drainage'] ?? 'Unknown'),
            _buildAnalysisRow('Fertility', soilAdvice['fertility'] ?? 'Unknown'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                soilAdvice['managementAdvice'] ?? 'No management advice available',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ));
    }

    // Fertilizer Recommendation
    final fertilizer = analysis['fertilizerRecommendation'];
    if (fertilizer != null && fertilizer.isNotEmpty) {
      sections.add(_buildAnalysisSection(
        'Fertilizer Recommendations',
        Icons.science,
        Colors.purple,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fertilizer.entries.map((entry) =>
              _buildAnalysisRow(entry.key, entry.value)
          ).toList(),
        ),
      ));
    }

    // Harvest Timeline
    final harvest = analysis['harvestTimeline'];
    if (harvest != null) {
      sections.add(_buildAnalysisSection(
        'Growth Timeline',
        Icons.timeline,
        Colors.teal,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(harvest, style: TextStyle(fontSize: 14)),
          ],
        ),
      ));
    }

    // Pest Risk
    final pestRisk = analysis['pestRisk'];
    if (pestRisk != null) {
      sections.add(_buildAnalysisSection(
        'Pest Risk Assessment',
        Icons.bug_report,
        Colors.red,
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pestRisk,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ));
    }

    return sections;
  }

  Widget _buildAnalysisSection(String title, IconData icon, Color color, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showPlantingGuideDialog(CropRequirement crop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${crop.name} Planting Guide'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideItem('Best Planting Time', _getPlantingTime(crop)),
              _buildGuideItem('Soil Preparation', _getSoilPreparation(crop)),
              _buildGuideItem('Planting Depth', _getPlantingDepth(crop)),
              _buildGuideItem('Spacing', _getPlantingSpacing(crop)),
              _buildGuideItem('Fertilization', _getFertilizationGuide(crop)),
              _buildGuideItem('Irrigation', _getIrrigationGuide(crop)),
              _buildGuideItem('Harvest Indicators', _getHarvestIndicators(crop)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String title, String content) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getPlantingTime(CropRequirement crop) {
    switch (crop.season) {
      case 'Kharif':
        return 'June-July (with monsoon onset)';
      case 'Rabi':
        return 'October-November (post-monsoon)';
      case 'Year Round':
        return 'Any time with proper irrigation';
      default:
        return 'Depends on local climate';
    }
  }

  String _getSoilPreparation(CropRequirement crop) {
    if (crop.soilTypes.contains('Clay')) {
      return 'Deep plowing, add sand/organic matter for drainage';
    } else if (crop.soilTypes.contains('Sandy')) {
      return 'Add organic matter/compost to improve water retention';
    }
    return 'Standard preparation: plow, level, add basal fertilizer';
  }

  String _getPlantingDepth(CropRequirement crop) {
    if (['Rice', 'Wheat', 'Barley'].contains(crop.name)) {
      return '2-3 cm depth';
    } else if (['Maize', 'Cotton', 'Soybean'].contains(crop.name)) {
      return '3-5 cm depth';
    } else if (['Potato', 'Groundnut'].contains(crop.name)) {
      return '5-8 cm depth';
    }
    return '3-4 cm depth (general guideline)';
  }

  String _getPlantingSpacing(CropRequirement crop) {
    if (crop.name == 'Rice') {
      return '20-25 cm between rows, 15-20 cm between plants';
    } else if (crop.name == 'Wheat') {
      return '15-20 cm between rows';
    } else if (crop.name == 'Maize') {
      return '60-75 cm between rows, 20-25 cm between plants';
    } else if (crop.name == 'Cotton') {
      return '60-90 cm between rows, 30-45 cm between plants';
    }
    return 'Refer to local agricultural guidelines';
  }

  String _getFertilizationGuide(CropRequirement crop) {
    final fertilizers = <String>[];

    if (crop.nutrients.contains('Nitrogen')) {
      fertilizers.add('Nitrogen: 100-150 kg/ha in split doses');
    }
    if (crop.nutrients.contains('Phosphorus')) {
      fertilizers.add('Phosphorus: 50-80 kg/ha as basal dose');
    }
    if (crop.nutrients.contains('Potassium')) {
      fertilizers.add('Potassium: 60-100 kg/ha in split doses');
    }

    return fertilizers.join('\n');
  }

  String _getIrrigationGuide(CropRequirement crop) {
    final waterReq = crop.getWaterRequirementText();

    switch (waterReq) {
      case 'Low':
        return 'Irrigate when soil moisture drops below 40%. Interval: 7-10 days';
      case 'Moderate':
        return 'Regular irrigation needed. Interval: 5-7 days';
      case 'High':
        return 'Frequent irrigation required. Interval: 3-5 days';
      case 'Very High':
        return 'Continuous moisture needed. Consider drip irrigation';
      default:
        return 'Monitor soil moisture regularly';
    }
  }

  String _getHarvestIndicators(CropRequirement crop) {
    if (crop.name == 'Rice') {
      return 'Grains hard, 80-85% of panicles straw-colored';
    } else if (crop.name == 'Wheat') {
      return 'Grains hard, plants golden brown, moisture < 20%';
    } else if (crop.name == 'Maize') {
      return 'Black layer at kernel base, moisture 25-30%';
    } else if (crop.name == 'Cotton') {
      return 'Bolls fully open, fibers dry and fluffy';
    } else if (crop.name == 'Potato') {
      return 'Vines dead, tubers skin set';
    }
    return 'Refer to crop-specific maturity indicators';
  }
}