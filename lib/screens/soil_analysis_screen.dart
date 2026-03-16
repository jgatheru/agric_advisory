import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide Position;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../models/soil_data.dart';
import '../providers/soil_hive_provider.dart';
import '../providers/soil_api_provider.dart';
import '../providers/weather_provider.dart';

class SoilAnalysisScreen extends StatefulWidget {
  @override
  _SoilAnalysisScreenState createState() => _SoilAnalysisScreenState();
}

class _SoilAnalysisScreenState extends State<SoilAnalysisScreen> {
  int _selectedDays = 30;
  bool _showCharts = true;
  bool _fetchingLocation = false;
  Position? _currentPosition;
  String _locationName = 'Unknown Location';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _fetchingLocation = true;
    });

    try {
      // Check permissions
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

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Update local state
      setState(() {
        _currentPosition = position;
      });

      // Get providers
      final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);

      // Update weather provider with position
      weatherProvider.currentPosition = position;

      // Try to get location name
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final newLocationName = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}';
          if (newLocationName.trim().isEmpty || newLocationName == ', ') {
            weatherProvider.locationName = '${position.latitude.toStringAsFixed(4)}, '
                '${position.longitude.toStringAsFixed(4)}';
            setState(() {
              _locationName = weatherProvider.locationName;
            });
          } else {
            weatherProvider.locationName = newLocationName;
            setState(() {
              _locationName = newLocationName;
            });
          }
        } else {
          weatherProvider.locationName = '${position.latitude.toStringAsFixed(4)}, '
              '${position.longitude.toStringAsFixed(4)}';
          setState(() {
            _locationName = weatherProvider.locationName;
          });
        }
      } catch (e) {
        weatherProvider.locationName = '${position.latitude.toStringAsFixed(4)}, '
            '${position.longitude.toStringAsFixed(4)}';
        setState(() {
          _locationName = weatherProvider.locationName;
        });
      }

      // Fetch API data
      _fetchApiData();

    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _fetchingLocation = false;
      });
    }
  }

  Future<void> _fetchApiData() async {
    if (_currentPosition != null) {
      final soilApiProvider = context.read<SoilApiProvider>();

      await soilApiProvider.fetchSoilData(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        verbose: false,
      );

      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: _selectedDays));

      // await soilApiProvider.fetchHistoricalData(
      //   latitude: _currentPosition!.latitude,
      //   longitude: _currentPosition!.longitude,
      //   startDate: startDate,
      //   endDate: endDate,
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    final soilHiveProvider = context.watch<SoilHiveProvider>();
    final soilApiProvider = context.watch<SoilApiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Soil Analysis'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchApiData,
            tooltip: 'Refresh API Data',
          ),
          IconButton(
            icon: Icon(Icons.location_on),
            onPressed: () => _showLocationInputDialog(),
            tooltip: 'Set Location',
          ),
          IconButton(
            icon: Icon(_showCharts ? Icons.list : Icons.show_chart),
            onPressed: () {
              setState(() {
                _showCharts = !_showCharts;
              });
            },
            tooltip: _showCharts ? 'Show List' : 'Show Charts',
          ),
          PopupMenuButton<int>(
            onSelected: (days) async {
              setState(() {
                _selectedDays = days;
              });
              await _fetchHistoricalDataForPeriod(days, soilApiProvider);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 60, child: Text('Last 60 days')),
            ],
          ),
        ],
      ),
      body: _buildContent(context, soilHiveProvider, soilApiProvider),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showApiFetchOptions(context, soilApiProvider),
            child: Icon(Icons.cloud_download),
            tooltip: 'Fetch Soil Data',
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _saveApiDataToLocal(context, soilApiProvider, soilHiveProvider),
            child: Icon(Icons.save),
            tooltip: 'Save API Data Locally',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      SoilHiveProvider soilHiveProvider,
      SoilApiProvider soilApiProvider,
      ) {
    final localData = soilHiveProvider.getLastNDays(_selectedDays);
    final apiCurrentData = soilApiProvider.currentSoilData;
    final apiHistoricalData = soilApiProvider.historicalSoilData;

    // Combine all data
    final allData = <SoilData>[];
    allData.addAll(localData);
    allData.addAll(apiHistoricalData);
    if (apiCurrentData != null && !apiHistoricalData.contains(apiCurrentData)) {
      allData.add(apiCurrentData);
    }

    // Sort by date (newest first)
    allData.sort((a, b) => b.date.compareTo(a.date));

    final nutrientAnalysis = soilApiProvider.getNutrientAnalysis();

    if (_fetchingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Getting your location...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_currentPosition == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.orange),
              SizedBox(height: 20),
              Text(
                'Location Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Soil nutrient data requires your location coordinates',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.location_on),
                label: Text('Set Location'),
                onPressed: () => _showLocationInputDialog(),
              ),
            ],
          ),
        ),
      );
    }

    if (soilApiProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Fetching Soil Data from API...',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              _locationName,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (soilApiProvider.error.isNotEmpty && localData.isEmpty && allData.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'API Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                soilApiProvider.error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchApiData,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (allData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grass, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No Soil Data Available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Fetch soil data using the download button',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Location Info Card
          _buildLocationCard(),

          // Latest Soil Data Card
          if (allData.isNotEmpty) _buildLatestSoilDataCard(allData.first),

          // Nutrient Dashboard
          if (nutrientAnalysis['averages'].isNotEmpty)
            _buildNutrientDashboard(nutrientAnalysis),

          // Charts Section
          if (_showCharts && apiHistoricalData.isNotEmpty)
            _buildNutrientCharts(apiHistoricalData),

          // Data Table
          if (allData.isNotEmpty) _buildDataTable(allData),

          // Local Data Section
          if (localData.isNotEmpty) _buildLocalDataSection(localData, soilHiveProvider),

          // Recommendations Section
          _buildRecommendationsSection(nutrientAnalysis),

          // Soil Health Score
          // if (soilApiProvider.soilHealthScore != null)
          //   _buildSoilHealthCard(soilApiProvider.soilHealthScore!),

          // Add some bottom padding
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_currentPosition!.latitude.toStringAsFixed(6)}, '
                        '${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, size: 20),
              onPressed: () => _showLocationInputDialog(),
              tooltip: 'Change Location',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestSoilDataCard(SoilData latestData) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.purple, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest Soil Analysis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(
                    latestData.source.contains('api') ? 'API' : 'Local',
                    style: TextStyle(fontSize: 10),
                  ),
                  backgroundColor: latestData.source.contains('api')
                      ? Colors.blue[100]
                      : Colors.orange[100],
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Build nutrient items without GridView - use Column with Wrap
            _buildNutrientItems(latestData),

            SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(latestData.date)}',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientItems(SoilData latestData) {
    final List<Widget> nutrientWidgets = [];

    // Create nutrient tiles
    if (latestData.pH != null) {
      nutrientWidgets.add(
        Flexible(
          child: _buildNutrientTile(
            'pH',
            latestData.pH!.toStringAsFixed(1),
            latestData.getNutrientAnalysis()['pH'] ?? 'Unknown',
            Colors.purple,
            Icons.thermostat,
          ),
        ),
      );
    }

    if (latestData.nitrogen != null) {
      nutrientWidgets.add(
        Flexible(
          child: _buildNutrientTile(
            'Nitrogen',
            latestData.nitrogen!.toStringAsFixed(0),
            latestData.getNutrientAnalysis()['nitrogen'] ?? 'Unknown',
            Colors.green,
            Icons.grass,
          ),
        ),
      );
    }

    if (latestData.phosphorus != null) {
      nutrientWidgets.add(
        Flexible(
          child: _buildNutrientTile(
            'Phosphorus',
            latestData.phosphorus!.toStringAsFixed(0),
            latestData.getNutrientAnalysis()['phosphorus'] ?? 'Unknown',
            Colors.orange,
            Icons.whatshot,
          ),
        ),
      );
    }

    if (latestData.potassium != null) {
      nutrientWidgets.add(
        Flexible(
          child: _buildNutrientTile(
            'Potassium',
            latestData.potassium!.toStringAsFixed(0),
            latestData.getNutrientAnalysis()['potassium'] ?? 'Unknown',
            Colors.blue,
            Icons.opacity,
          ),
        ),
      );
    }

    if (latestData.organicMatter != null) {
      nutrientWidgets.add(
        Flexible(
          child: _buildNutrientTile(
            'Organic Matter',
            latestData.organicMatter!.toStringAsFixed(1),
            latestData.getNutrientAnalysis()['organicMatter'] ?? 'Unknown',
            Colors.brown,
            Icons.eco,
          ),
        ),
      );
    }

    if (latestData.soilType != null) {
      nutrientWidgets.add(
        Flexible(
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.terrain, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Soil Type',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  latestData.soilType!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If no nutrient data, return empty container
    if (nutrientWidgets.isEmpty) {
      return Container();
    }

    // Create a responsive grid layout using Wrap or GridView
    if (nutrientWidgets.length <= 3) {
      // For small number of items, use Wrap
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nutrientWidgets,
      );
    } else {
      // For more items, use GridView with calculated height
      int rows = (nutrientWidgets.length / 2).ceil();
      double gridHeight = rows * 70 + (rows - 1) * 8;

      return SizedBox(
        height: gridHeight,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: nutrientWidgets,
        ),
      );
    }
  }

  Widget _buildNutrientTile(String title, String value, String status, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientDashboard(Map<String, dynamic> nutrientAnalysis) {
    final averages = nutrientAnalysis['averages'];

    // Count the number of progress tiles
    int tileCount = 0;
    if (averages['nitrogen'] != null) tileCount++;
    if (averages['phosphorus'] != null) tileCount++;
    if (averages['potassium'] != null) tileCount++;
    if (averages['organicMatter'] != null) tileCount++;

    // Calculate rows needed (2 items per row)
    int rows = (tileCount / 2).ceil();
    double gridHeight = rows * 85 + (rows - 1) * 8; // 85px per row + spacing

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(12), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for preventing overflow
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple, size: 20), // Smaller icon
                SizedBox(width: 8),
                Text(
                  'Nutrient Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Smaller font
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            SizedBox(height: 12),

            // pH Progress
            if (averages['pH'] != null)
              _buildProgressIndicator(
                'pH Level',
                averages['pH']!,
                14.0,
                nutrientAnalysis['pHStatus'] ?? 'Unknown',
                Colors.purple,
                Icons.thermostat,
              ),

            if (averages['pH'] != null) SizedBox(height: 12),

            // Wrap GridView in SizedBox with fixed height
            if (tileCount > 0)
              SizedBox(
                height: gridHeight.clamp(85, 200), // Minimum 85px, maximum 200px
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2, // Reduced from 2.5
                  mainAxisSpacing: 6, // Reduced from 8
                  crossAxisSpacing: 6, // Reduced from 8
                  children: [
                    if (averages['nitrogen'] != null)
                      _buildNutrientProgressTile(
                        'Nitrogen',
                        averages['nitrogen']!,
                        100.0,
                        nutrientAnalysis['nitrogenStatus'] ?? 'Unknown',
                        Colors.green,
                        Icons.grass,
                        'mg/kg',
                      ),

                    if (averages['phosphorus'] != null)
                      _buildNutrientProgressTile(
                        'Phosphorus',
                        averages['phosphorus']!,
                        50.0,
                        nutrientAnalysis['phosphorusStatus'] ?? 'Unknown',
                        Colors.orange,
                        Icons.whatshot,
                        'mg/kg',
                      ),

                    if (averages['potassium'] != null)
                      _buildNutrientProgressTile(
                        'Potassium',
                        averages['potassium']!,
                        300.0,
                        nutrientAnalysis['potassiumStatus'] ?? 'Unknown',
                        Colors.blue,
                        Icons.opacity,
                        'mg/kg',
                      ),

                    if (averages['organicMatter'] != null)
                      _buildNutrientProgressTile(
                        'Organic Matter',
                        averages['organicMatter']!,
                        10.0,
                        nutrientAnalysis['organicMatterStatus'] ?? 'Unknown',
                        Colors.brown,
                        Icons.eco,
                        '%',
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientCharts(List<SoilData> data) {
    final List<ChartData> phData = [];
    final List<ChartData> nitrogenData = [];
    final List<ChartData> potassiumData = [];

    for (var soilData in data) {
      if (soilData.pH != null) {
        phData.add(ChartData(soilData.date, soilData.pH!));
      }
      if (soilData.nitrogen != null) {
        nitrogenData.add(ChartData(soilData.date, soilData.nitrogen!));
      }
      if (soilData.potassium != null) {
        potassiumData.add(ChartData(soilData.date, soilData.potassium!));
      }
    }

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nutrient Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('MMM d'),
                  labelStyle: TextStyle(fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Concentration'),
                ),
                legend: Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <LineSeries<ChartData, DateTime>>[
                  if (phData.isNotEmpty)
                    LineSeries<ChartData, DateTime>(
                      dataSource: phData,
                      xValueMapper: (ChartData data, _) => data.date,
                      yValueMapper: (ChartData data, _) => data.value,
                      name: 'pH',
                      color: Colors.purple,
                      markerSettings: MarkerSettings(isVisible: true),
                    ),
                  if (nitrogenData.isNotEmpty)
                    LineSeries<ChartData, DateTime>(
                      dataSource: nitrogenData,
                      xValueMapper: (ChartData data, _) => data.date,
                      yValueMapper: (ChartData data, _) => data.value,
                      name: 'Nitrogen (mg/kg)',
                      color: Colors.green,
                      markerSettings: MarkerSettings(isVisible: true),
                    ),
                  if (potassiumData.isNotEmpty)
                    LineSeries<ChartData, DateTime>(
                      dataSource: potassiumData,
                      xValueMapper: (ChartData data, _) => data.date,
                      yValueMapper: (ChartData data, _) => data.value,
                      name: 'Potassium (mg/kg)',
                      color: Colors.blue,
                      markerSettings: MarkerSettings(isVisible: true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<SoilData> data) {
    final sortedData = List<SoilData>.from(data)..sort((a, b) => b.date.compareTo(a.date));

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Soil Data History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('pH')),
                  DataColumn(label: Text('N (mg/kg)')),
                  DataColumn(label: Text('P (mg/kg)')),
                  DataColumn(label: Text('K (mg/kg)')),
                  DataColumn(label: Text('OM (%)')),
                  DataColumn(label: Text('Type')),
                ],
                rows: sortedData.take(10).map((soilData) {
                  return DataRow(cells: [
                    DataCell(Text(DateFormat('MM/dd').format(soilData.date))),
                    DataCell(_buildSourceChip(soilData.source)),
                    DataCell(Text(soilData.pH?.toStringAsFixed(1) ?? 'N/A')),
                    DataCell(Text(soilData.nitrogen?.toStringAsFixed(0) ?? 'N/A')),
                    DataCell(Text(soilData.phosphorus?.toStringAsFixed(0) ?? 'N/A')),
                    DataCell(Text(soilData.potassium?.toStringAsFixed(0) ?? 'N/A')),
                    DataCell(Text(soilData.organicMatter?.toStringAsFixed(1) ?? 'N/A')),
                    DataCell(Text(soilData.soilType ?? 'N/A')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChip(String source) {
    Color color;
    String label;

    if (source.contains('api')) {
      color = Colors.blue;
      label = 'API';
    } else {
      color = Colors.orange;
      label = 'Local';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 10),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLocalDataSection(List<SoilData> localData, SoilHiveProvider soilHiveProvider) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Local Data Storage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                ElevatedButton.icon(
                  icon: Icon(Icons.delete, size: 16),
                  label: Text('Clear'),
                  onPressed: () => _clearLocalData(context, soilHiveProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(maxHeight: 200), // Fixed max height for the list
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: localData.length,
                itemBuilder: (context, index) {
                  final data = localData[index];
                  return ListTile(
                    leading: Icon(Icons.agriculture, color: Colors.orange),
                    title: Text(DateFormat('yyyy-MM-dd HH:mm').format(data.date)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data.pH != null) Text('pH: ${data.pH!.toStringAsFixed(1)}'),
                        if (data.nitrogen != null) Text('N: ${data.nitrogen!.toStringAsFixed(0)} mg/kg'),
                      ],
                    ),
                    dense: true, // Make list tiles denser
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection(Map<String, dynamic> nutrientAnalysis) {
    final recommendations = _generateRecommendations(nutrientAnalysis);
    if (recommendations.isEmpty) return SizedBox();

    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.green[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...recommendations,
          ],
        ),
      ),
    );
  }

  Widget _buildSoilHealthCard(Map<String, dynamic> healthScore) {
    final score = healthScore['score'] ?? 0;
    final status = healthScore['status'] ?? 'Unknown';

    Color color;
    if (score >= 80) color = Colors.green;
    else if (score >= 60) color = Colors.orange;
    else color = Colors.red;

    return Card(
      margin: EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: color),
                SizedBox(width: 8),
                Text(
                  'Soil Health Score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '$score/100',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientProgressTile(String title, double value, double maxValue,
      String status, Color color, IconData icon, String unit) {
    final percentage = (value / maxValue * 100).clamp(0.0, 100.0);

    return Container(
      padding: EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6), // Smaller radius
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color), // Smaller icon
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10, // Smaller font
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: 10, // Smaller font
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / maxValue,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status,
                style: TextStyle(fontSize: 9, color: Colors.grey), // Smaller font
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 9, color: Colors.grey), // Smaller font
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String title, double value, double maxValue,
      String status, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20), // Smaller icon
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14, // Smaller font
                ),
              ),
              Spacer(),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16, // Smaller font
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: value / maxValue,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<Widget> _generateRecommendations(Map<String, dynamic> nutrientAnalysis) {
    final recommendations = <Widget>[];
    final averages = nutrientAnalysis['averages'];

    // pH recommendations
    final pH = averages['pH'] ?? 0.0;
    if (pH < 6.0) {
      recommendations.add(_buildRecommendationItem(
        'Acidic Soil (pH: ${pH.toStringAsFixed(1)})',
        'Consider adding agricultural lime to raise pH.',
        Icons.warning,
        Colors.orange,
      ));
    } else if (pH > 7.5) {
      recommendations.add(_buildRecommendationItem(
        'Alkaline Soil (pH: ${pH.toStringAsFixed(1)})',
        'Consider adding sulfur or organic matter to lower pH.',
        Icons.warning,
        Colors.orange,
      ));
    }

    // Nutrient recommendations
    final nitrogen = averages['nitrogen'] ?? 0.0;
    if (nitrogen < 20) {
      recommendations.add(_buildRecommendationItem(
        'Low Nitrogen',
        'Consider nitrogen fertilizer or legume cover crops.',
        Icons.grass,
        Colors.green,
      ));
    }

    final phosphorus = averages['phosphorus'] ?? 0.0;
    if (phosphorus < 10) {
      recommendations.add(_buildRecommendationItem(
        'Low Phosphorus',
        'Consider phosphorus fertilizer or bone meal.',
        Icons.whatshot,
        Colors.orange,
      ));
    }

    return recommendations;
  }

  Widget _buildRecommendationItem(String title, String content, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationInputDialog() async {
    final locationController = TextEditingController(text: _locationName);
    final latController = TextEditingController(
        text: _currentPosition?.latitude.toStringAsFixed(6) ?? '');
    final lngController = TextEditingController(
        text: _currentPosition?.longitude.toStringAsFixed(6) ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Location Name',
                  hintText: 'e.g., My Farm, Nairobi',
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: latController,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g., -1.2921',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: lngController,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g., 36.8219',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                icon: Icon(Icons.gps_fixed),
                label: Text('Use Current Location'),
                onPressed: () async {
                  Navigator.pop(context);
                  await _getCurrentLocation();
                },
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
              final lng = double.tryParse(lngController.text);

              if (lat != null && lng != null) {
                final position = Position(
                  latitude: lat,
                  longitude: lng,
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                );

                // Update WeatherProvider
                final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
                weatherProvider.currentPosition = position;

                // Try to get location name
                if (locationController.text.isNotEmpty) {
                  weatherProvider.locationName = locationController.text;
                  setState(() {
                    _currentPosition = position;
                    _locationName = locationController.text;
                  });
                } else {
                  // Try to get location name from coordinates
                  try {
                    final placemarks = await placemarkFromCoordinates(lat, lng);
                    if (placemarks.isNotEmpty) {
                      final placemark = placemarks.first;
                      final newLocationName = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}';
                      if (newLocationName.trim().isEmpty || newLocationName == ', ') {
                        weatherProvider.locationName = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
                        setState(() {
                          _currentPosition = position;
                          _locationName = weatherProvider.locationName;
                        });
                      } else {
                        weatherProvider.locationName = newLocationName;
                        setState(() {
                          _currentPosition = position;
                          _locationName = newLocationName;
                        });
                      }
                    } else {
                      weatherProvider.locationName = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
                      setState(() {
                        _currentPosition = position;
                        _locationName = weatherProvider.locationName;
                      });
                    }
                  } catch (e) {
                    weatherProvider.locationName = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
                    setState(() {
                      _currentPosition = position;
                      _locationName = weatherProvider.locationName;
                    });
                  }
                }

                Navigator.pop(context);
                _fetchApiData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter valid coordinates')),
                );
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHistoricalDataForPeriod(int days, SoilApiProvider soilApiProvider) async {
    if (_currentPosition != null) {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      // await soilApiProvider.fetchHistoricalData(
      //   latitude: _currentPosition!.latitude,
      //   longitude: _currentPosition!.longitude,
      //   startDate: startDate,
      //   endDate: endDate,
      // );
    }
  }

  Future<void> _showApiFetchOptions(BuildContext context, SoilApiProvider soilApiProvider) async {
    final selectedOption = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Fetch Soil Data'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Current Nutrients'),
              subtitle: Text('Get latest soil nutrient data'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 2),
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('Historical Data'),
              subtitle: Text('Get past 30 days data'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 3),
            child: ListTile(
              leading: Icon(Icons.health_and_safety),
              title: Text('Soil Health Score'),
              subtitle: Text('Get soil health assessment'),
            ),
          ),
        ],
      ),
    );

    if (selectedOption != null && _currentPosition != null) {
      switch (selectedOption) {
        case 1:
          await soilApiProvider.fetchSoilData(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            verbose: false,
          );
          break;
        case 2:
          await _fetchHistoricalDataForPeriod(30, soilApiProvider);
          break;
        case 3:
          // await soilApiProvider.fetchSoilHealthScore(
          //   _currentPosition!.latitude,  // Positional parameter
          //   _currentPosition!.longitude, // Positional parameter
          // );
          break;
      }
    }
  }

  Future<void> _saveApiDataToLocal(
      BuildContext context,
      SoilApiProvider soilApiProvider,
      SoilHiveProvider soilHiveProvider,
      ) async {
    if (soilApiProvider.currentSoilData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No API data to save')),
      );
      return;
    }

    try {
      // Save the current API data
      final apiData = soilApiProvider.currentSoilData!;
      await soilHiveProvider.saveSoilData(apiData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API data saved to local storage'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearLocalData(BuildContext context, SoilHiveProvider soilHiveProvider) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Local Data?'),
        content: Text('This will delete all soil data stored on your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await soilHiveProvider.clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Local data cleared'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class ChartData {
  final DateTime date;
  final double value;

  ChartData(this.date, this.value);
}