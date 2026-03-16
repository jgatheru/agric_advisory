import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/weather_provider.dart';
import '../providers/nasa_power_provider.dart';
import '../providers/fao_provider.dart';
import '../providers/crop_provider.dart';
import '../models/weather_models.dart';

class AdvisoryScreen extends StatefulWidget {
  @override
  _AdvisoryScreenState createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  String? _selectedCrop;
  String _selectedAdvisoryType = 'all';
  bool _showHistorical = false;

  final List<String> _advisoryTypes = [
    'all',
    'weather',
    'soil',
    'irrigation',
    'pest',
    'harvest'
  ];

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
            Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Weather Data Required',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Please fetch weather data first',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final advisories = _generateAdvisories(
      weatherProvider,
      nasaProvider,
      faoProvider,
      cropProvider,
      weather,
      nasaData,
    );

    final filteredAdvisories = _filterAdvisories(advisories);

    return Scaffold(
      appBar: AppBar(
        title: Text('Farm Advisory'),
        actions: [
          IconButton(
            icon: Icon(_showHistorical ? Icons.today : Icons.history),
            onPressed: () {
              setState(() {
                _showHistorical = !_showHistorical;
              });
            },
            tooltip: _showHistorical ? 'Current' : 'Historical',
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
                  // Crop Selection
                  Row(
                    children: [
                      Text('Crop:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCrop,
                          decoration: InputDecoration(
                            labelText: 'Select Crop (Optional)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('All Crops')),
                            ...cropProvider.crops.map((crop) =>
                                DropdownMenuItem(
                                  value: crop.name,
                                  child: Text(crop.name),
                                )
                            ).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCrop = value;
                            });
                          },
                          isExpanded: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Advisory Type Filter
                  Row(
                    children: [
                      Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _buildAdvisoryTypeChip('All', 'all'),
                            _buildAdvisoryTypeChip('Weather', 'weather'),
                            _buildAdvisoryTypeChip('Soil', 'soil'),
                            _buildAdvisoryTypeChip('Irrigation', 'irrigation'),
                            _buildAdvisoryTypeChip('Pest', 'pest'),
                            _buildAdvisoryTypeChip('Harvest', 'harvest'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Advisories Count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Advisories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text('${filteredAdvisories.length} found'),
                  backgroundColor: Colors.green[100],
                ),
              ],
            ),
          ),

          // Advisories List
          Expanded(
            child: filteredAdvisories.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 20),
                  Text(
                    'No Active Advisories',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Conditions are favorable',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredAdvisories.length,
              itemBuilder: (context, index) {
                final advisory = filteredAdvisories[index];
                return _buildAdvisoryCard(advisory, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryTypeChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedAdvisoryType == value,
      onSelected: (selected) {
        setState(() {
          _selectedAdvisoryType = selected ? value : 'all';
        });
      },
      backgroundColor: _getAdvisoryColor(value).withOpacity(0.1),
      selectedColor: _getAdvisoryColor(value),
      labelStyle: TextStyle(
        color: _selectedAdvisoryType == value ? Colors.white : Colors.black,
      ),
    );
  }

  Color _getAdvisoryColor(String type) {
    switch (type) {
      case 'weather':
        return Colors.blue;
      case 'soil':
        return Colors.brown;
      case 'irrigation':
        return Colors.lightBlue;
      case 'pest':
        return Colors.red;
      case 'harvest':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _getAdvisoryIcon(String type) {
    switch (type) {
      case 'weather':
        return Icons.cloud;
      case 'soil':
        return Icons.grass;
      case 'irrigation':
        return Icons.opacity;
      case 'pest':
        return Icons.bug_report;
      case 'harvest':
        return Icons.agriculture;
      default:
        return Icons.lightbulb;
    }
  }

  List<Map<String, dynamic>> _generateAdvisories(
      WeatherProvider weatherProvider,
      NASAPowerProvider nasaProvider,
      FAOProvider faoProvider,
      CropProvider cropProvider,
      WeatherData weather,
      WeatherData nasaData,
      ) {
    final advisories = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // Weather-based advisories
    if (weather.temperature > 35) {
      advisories.add({
        'type': 'weather',
        'title': 'Heat Wave Warning',
        'message': 'Temperatures above 35°C may cause heat stress to crops. '
            'Consider increasing irrigation frequency and providing shade for sensitive plants.',
        'severity': 'warning',
        'icon': Icons.whatshot,
        'color': Colors.orange,
        'date': now,
        'affectedCrops': ['All heat-sensitive crops'],
        'actions': [
          'Increase irrigation frequency',
          'Water in early morning or late evening',
          'Consider shade nets for sensitive crops',
          'Monitor for heat stress symptoms',
        ],
      });
    }

    if (weather.temperature < 5) {
      advisories.add({
        'type': 'weather',
        'title': 'Frost Alert',
        'message': 'Low temperatures may damage sensitive crops. '
            'Protect plants with covers or use frost protection methods.',
        'severity': 'warning',
        'icon': Icons.ac_unit,
        'color': Colors.lightBlue,
        'date': now,
        'affectedCrops': ['Tomato', 'Potato', 'Other sensitive vegetables'],
        'actions': [
          'Cover plants with frost cloth',
          'Use row covers or cold frames',
          'Water plants before frost',
          'Consider greenhouse cultivation',
        ],
      });
    }

    if (weather.precipitation > 20) {
      advisories.add({
        'type': 'weather',
        'title': 'Heavy Rainfall Expected',
        'message': 'Significant rainfall may cause waterlogging. '
            'Ensure proper field drainage and monitor for disease outbreaks.',
        'severity': 'alert',
        'icon': Icons.cloudy_snowing,
        'color': Colors.blue,
        'date': now,
        'affectedCrops': ['All crops'],
        'actions': [
          'Check and clear drainage channels',
          'Monitor for waterlogging',
          'Watch for fungal diseases',
          'Delay field work if soil is saturated',
        ],
      });
    }

    if (weather.windSpeed > 30) {
      advisories.add({
        'type': 'weather',
        'title': 'Strong Wind Warning',
        'message': 'High winds may damage crops and affect pollination. '
            'Secure plants and protect sensitive crops.',
        'severity': 'warning',
        'icon': Icons.air,
        'color': Colors.grey,
        'date': now,
        'affectedCrops': ['Tall crops', 'Fruit trees', 'Vegetables'],
        'actions': [
          'Stake tall plants',
          'Use windbreaks',
          'Protect flowering crops',
          'Check for physical damage',
        ],
      });
    }

    // Soil-based advisories
    if (nasaData.soilMoisture != null) {
      if (nasaData.soilMoisture! < 30) {
        advisories.add({
          'type': 'soil',
          'title': 'Low Soil Moisture',
          'message': 'Soil moisture is critically low. '
              'Immediate irrigation is recommended to prevent crop stress.',
          'severity': 'critical',
          'icon': Icons.water_drop,
          'color': Colors.blue,
          'date': now,
          'affectedCrops': ['All crops'],
          'actions': [
            'Schedule irrigation immediately',
            'Use drip irrigation for efficiency',
            'Consider mulching to retain moisture',
            'Monitor soil moisture daily',
          ],
        });
      } else if (nasaData.soilMoisture! > 80) {
        advisories.add({
          'type': 'soil',
          'title': 'Excessive Soil Moisture',
          'message': 'Soil is saturated. Risk of waterlogging and root diseases. '
              'Improve drainage and avoid additional irrigation.',
          'severity': 'warning',
          'icon': Icons.waves, // Changed from Icons.drainage to Icons.waves
          'color': Colors.blue,
          'date': now,
          'affectedCrops': ['Crops sensitive to waterlogging'],
          'actions': [
            'Improve field drainage',
            'Avoid additional irrigation',
            'Monitor for root diseases',
            'Consider raised beds',
          ],
        });
      }
    }

    if (nasaData.soilTemperature != null) {
      if (nasaData.soilTemperature! < 15) {
        advisories.add({
          'type': 'soil',
          'title': 'Cold Soil Conditions',
          'message': 'Soil temperature is low for optimal plant growth. '
              'Germination and root development may be slow.',
          'severity': 'info',
          'icon': Icons.thermostat,
          'color': Colors.lightBlue,
          'date': now,
          'affectedCrops': ['Warm-season crops'],
          'actions': [
            'Use black plastic mulch',
            'Consider delayed planting',
            'Use row covers',
            'Choose cold-tolerant varieties',
          ],
        });
      } else if (nasaData.soilTemperature! > 30) {
        advisories.add({
          'type': 'soil',
          'title': 'High Soil Temperature',
          'message': 'Soil temperature is high. May affect root function and '
              'increase water requirements.',
          'severity': 'warning',
          'icon': Icons.thermostat,
          'color': Colors.red,
          'date': now,
          'affectedCrops': ['Cool-season crops'],
          'actions': [
            'Increase irrigation frequency',
            'Use light-colored mulch',
            'Provide shade if possible',
            'Water in early morning',
          ],
        });
      }
    }

    // Solar radiation advisories
    if (nasaData.solarRadiation != null) {
      if (nasaData.solarRadiation! < 3) {
        advisories.add({
          'type': 'weather',
          'title': 'Low Solar Radiation',
          'message': 'Limited sunlight may reduce photosynthesis. '
              'Consider crop selection and management adjustments.',
          'severity': 'info',
          'icon': Icons.wb_cloudy,
          'color': Colors.grey,
          'date': now,
          'affectedCrops': ['High-light requiring crops'],
          'actions': [
            'Choose shade-tolerant crops',
            'Prune for better light penetration',
            'Monitor growth rates',
            'Consider supplemental lighting (greenhouse)',
          ],
        });
      } else if (nasaData.solarRadiation! > 7) {
        advisories.add({
          'type': 'weather',
          'title': 'High Solar Radiation',
          'message': 'Intense sunlight may cause sunburn and heat stress. '
              'Protect sensitive plants.',
          'severity': 'warning',
          'icon': Icons.wb_sunny,
          'color': Colors.orange,
          'date': now,
          'affectedCrops': ['Shade-sensitive crops'],
          'actions': [
            'Use shade nets if available',
            'Water in early morning',
            'Monitor for sunburn damage',
            'Consider intercropping with tall crops',
          ],
        });
      }
    }

    // Crop-specific advisories based on season
    final month = now.month;
    final season = month >= 6 && month <= 10 ? 'Kharif' : 'Rabi';

    if (season == 'Kharif') {
      advisories.add({
        'type': 'pest',
        'title': 'Monsoon Pest Alert',
        'message': 'Humid conditions during monsoon increase pest activity. '
            'Monitor for common pests and use integrated pest management.',
        'severity': 'warning',
        'icon': Icons.bug_report,
        'color': Colors.red,
        'date': now,
        'affectedCrops': ['Rice', 'Cotton', 'Vegetables'],
        'actions': [
          'Monitor for leaf folders, stem borers',
          'Use pheromone traps',
          'Practice crop rotation',
          'Consider biological controls',
        ],
      });
    } else if (season == 'Rabi') {
      advisories.add({
        'type': 'pest',
        'title': 'Winter Pest Management',
        'message': 'Cooler temperatures may increase certain pest populations. '
            'Regular monitoring is essential.',
        'severity': 'info',
        'icon': Icons.bug_report,
        'color': Colors.red,
        'date': now,
        'affectedCrops': ['Wheat', 'Potato', 'Vegetables'],
        'actions': [
          'Check for aphids, mites',
          'Use yellow sticky traps',
          'Maintain field hygiene',
          'Consider neem-based pesticides',
        ],
      });
    }

    // Irrigation advisories based on ET
    final et = weatherProvider.calculateEvapotranspiration(
      nasaData.temperature,
      nasaData.humidity,
      nasaData.windSpeed,
      nasaData.solarRadiation ?? 0,
    );

    if (et > 5) {
      advisories.add({
        'type': 'irrigation',
        'title': 'High Evapotranspiration',
        'message': 'High water loss through evaporation and transpiration. '
            'Increase irrigation frequency to meet crop water demand.',
        'severity': 'warning',
        'icon': Icons.opacity,
        'color': Colors.lightBlue,
        'date': now,
        'affectedCrops': ['All crops'],
        'actions': [
          'Increase irrigation frequency',
          'Water in early morning',
          'Use mulch to reduce evaporation',
          'Monitor soil moisture closely',
        ],
      });
    }

    // Add harvest advisories for common crops based on typical harvest times
    if (month == 10 || month == 11) {
      advisories.add({
        'type': 'harvest',
        'title': 'Kharif Season Harvest',
        'message': 'Harvest time for Kharif crops is approaching. '
            'Prepare for harvest operations and post-harvest management.',
        'severity': 'info',
        'icon': Icons.agriculture,
        'color': Colors.orange,
        'date': now,
        'affectedCrops': ['Rice', 'Maize', 'Cotton', 'Soybean'],
        'actions': [
          'Check crop maturity',
          'Prepare harvesting equipment',
          'Arrange drying facilities',
          'Plan storage or marketing',
        ],
      });
    } else if (month == 3 || month == 4) {
      advisories.add({
        'type': 'harvest',
        'title': 'Rabi Season Harvest',
        'message': 'Harvest time for Rabi crops is approaching. '
            'Monitor weather conditions for optimal harvest timing.',
        'severity': 'info',
        'icon': Icons.agriculture,
        'color': Colors.orange,
        'date': now,
        'affectedCrops': ['Wheat', 'Barley', 'Potato', 'Vegetables'],
        'actions': [
          'Monitor grain moisture',
          'Check for proper maturity',
          'Schedule harvest operations',
          'Prepare storage facilities',
        ],
      });
    }

    // Add general farming advisories
    advisories.add({
      'type': 'general',
      'title': 'Regular Soil Testing',
      'message': 'Regular soil testing helps maintain optimal fertility. '
          'Test soil pH and nutrient levels at least once a year.',
      'severity': 'info',
      'icon': Icons.science,
      'color': Colors.green,
      'date': now.subtract(Duration(days: 30)),
      'affectedCrops': ['All crops'],
      'actions': [
        'Collect soil samples from different areas',
        'Test for pH, N, P, K levels',
        'Apply fertilizers based on test results',
        'Maintain soil health records',
      ],
    });

    advisories.add({
      'type': 'general',
      'title': 'Crop Rotation Planning',
      'message': 'Plan crop rotation to improve soil health and reduce pests. '
          'Rotate between different crop families.',
      'severity': 'info',
      'icon': Icons.autorenew,
      'color': Colors.green,
      'date': now.subtract(Duration(days: 15)),
      'affectedCrops': ['All crops'],
      'actions': [
        'Plan rotation sequence',
        'Include legume crops for nitrogen fixation',
        'Avoid consecutive similar crops',
        'Consider cover crops',
      ],
    });

    return advisories;
  }

  List<Map<String, dynamic>> _filterAdvisories(List<Map<String, dynamic>> advisories) {
    List<Map<String, dynamic>> filtered = List.from(advisories);

    // Filter by crop
    if (_selectedCrop != null) {
      filtered = filtered.where((advisory) {
        final affectedCrops = advisory['affectedCrops'] as List<String>;
        return affectedCrops.contains('All crops') ||
            affectedCrops.contains(_selectedCrop);
      }).toList();
    }

    // Filter by type
    if (_selectedAdvisoryType != 'all') {
      filtered = filtered.where((advisory) {
        return advisory['type'] == _selectedAdvisoryType;
      }).toList();
    }

    // Filter by time (current vs historical)
    if (!_showHistorical) {
      filtered = filtered.where((advisory) {
        final date = advisory['date'] as DateTime;
        return date.isAfter(DateTime.now().subtract(Duration(days: 7)));
      }).toList();
    }

    // Sort by severity and date
    filtered.sort((a, b) {
      final severityOrder = {'critical': 0, 'alert': 1, 'warning': 2, 'info': 3};
      final severityA = severityOrder[a['severity']] ?? 3;
      final severityB = severityOrder[b['severity']] ?? 3;

      if (severityA != severityB) {
        return severityA.compareTo(severityB);
      }

      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  Widget _buildAdvisoryCard(Map<String, dynamic> advisory, int index) {
    final severity = advisory['severity'] as String;
    final type = advisory['type'] as String;
    final date = advisory['date'] as DateTime;

    Color getSeverityColor() {
      switch (severity) {
        case 'critical':
          return Colors.red;
        case 'alert':
          return Colors.orange;
        case 'warning':
          return Colors.amber;
        case 'info':
          return Colors.blue;
        default:
          return Colors.green;
      }
    }

    String getSeverityText() {
      switch (severity) {
        case 'critical':
          return 'Critical';
        case 'alert':
          return 'Alert';
        case 'warning':
          return 'Warning';
        case 'info':
          return 'Information';
        default:
          return 'General';
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: getSeverityColor().withOpacity(0.3), width: 1),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: getSeverityColor().withOpacity(0.1),
          child: Icon(
            advisory['icon'] ?? _getAdvisoryIcon(type),
            color: getSeverityColor(),
          ),
        ),
        title: Text(
          advisory['title'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Chip(
              label: Text(
                getSeverityText(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              backgroundColor: getSeverityColor(),
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(date),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Advisory Message
                Text(
                  advisory['message'],
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),

                // Affected Crops
                if (advisory['affectedCrops'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Affected Crops:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: (advisory['affectedCrops'] as List<String>)
                            .map((crop) => Chip(
                          label: Text(crop),
                          backgroundColor: Colors.grey[200],
                          labelStyle: TextStyle(fontSize: 12),
                        ))
                            .toList(),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),

                // Recommended Actions
                if (advisory['actions'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Actions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(advisory['actions'] as List<String>).map((action) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                action,
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),

                // Action Buttons
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _shareAdvisory(advisory);
                        },
                        icon: Icon(Icons.share),
                        label: Text('Share'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _markAsResolved(index);
                        },
                        icon: Icon(Icons.check),
                        label: Text('Resolved'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareAdvisory(Map<String, dynamic> advisory) {
    final message = '${advisory['title']}\n\n${advisory['message']}\n\n'
        'Recommended Actions:\n' +
        (advisory['actions'] as List<String>).map((a) => '• $a').join('\n');

    // In a real app, you would use a sharing package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Advisory copied to clipboard'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _markAsResolved(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Advisory marked as resolved'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {},
        ),
      ),
    );
  }
}