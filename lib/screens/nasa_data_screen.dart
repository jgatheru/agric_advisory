import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../models/weather_models.dart';
import '../providers/nasa_power_provider.dart';
import '../providers/weather_provider.dart';

class NASADataScreen extends StatefulWidget {
  @override
  _NASADataScreenState createState() => _NASADataScreenState();
}

class _NASADataScreenState extends State<NASADataScreen> {
  int _selectedChartDays = 30;
  String _selectedParameter = 'solar';
  bool _showRawData = false;

  final Map<String, String> _parameterTitles = {
    'solar': 'Solar Radiation',
    'temperature': 'Temperature',
    'moisture': 'Soil Moisture',
    'soil_temp': 'Soil Temperature',
    'precipitation': 'Precipitation',
  };

  final Map<String, String> _parameterUnits = {
    'solar': 'kWh/m²',
    'temperature': '°C',
    'moisture': '%',
    'soil_temp': '°C',
    'precipitation': 'mm',
  };

  @override
  Widget build(BuildContext context) {
    final nasaProvider = Provider.of<NASAPowerProvider>(context);
    final weatherProvider = Provider.of<WeatherProvider>(context);

    if (nasaProvider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (nasaProvider.error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.satellite, size: 64, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'NASA Data Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                nasaProvider.error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (weatherProvider.currentPosition != null) {
                    nasaProvider.fetchNASAData(
                      weatherProvider.currentPosition!.latitude,
                      weatherProvider.currentPosition!.longitude,
                      forceRefresh: true,
                    );
                  }
                },
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (nasaProvider.historicalData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.satellite, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No NASA Data Available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Fetch data from Home screen',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final data = nasaProvider.getLastNDays(_selectedChartDays);
    final soilAnalysis = nasaProvider.getSoilAnalysis();
    final solarAnalysis = nasaProvider.getSolarAnalysis();

    return Scaffold(
      appBar: AppBar(
        title: Text('NASA POWER Data'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (weatherProvider.currentPosition != null) {
                nasaProvider.fetchNASAData(
                  weatherProvider.currentPosition!.latitude,
                  weatherProvider.currentPosition!.longitude,
                  forceRefresh: true,
                );
              }
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with info
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.satellite, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NASA POWER Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Solar, meteorological, and agricultural parameters',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Parameter Selection
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Parameter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _parameterTitles.entries.map((entry) {
                        return FilterChip(
                          label: Text(entry.value),
                          selected: _selectedParameter == entry.key,
                          onSelected: (selected) {
                            setState(() {
                              _selectedParameter = selected ? entry.key : _selectedParameter;
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _selectedParameter == entry.key ? Colors.white : Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Time Period',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTimePeriodChip('7D', 7),
                        SizedBox(width: 8),
                        _buildTimePeriodChip('14D', 14),
                        SizedBox(width: 8),
                        _buildTimePeriodChip('30D', 30),
                        SizedBox(width: 8),
                        _buildTimePeriodChip('60D', 60),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Main Chart
            _buildParameterChart(data),

            // Current Values
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Values',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildCurrentValues(nasaProvider.currentData),
                  ],
                ),
              ),
            ),

            // Analysis Summary
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildAnalysisSummary(soilAnalysis, solarAnalysis),
                  ],
                ),
              ),
            ),

            // Raw Data Toggle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showRawData = !_showRawData;
                        });
                      },
                      icon: Icon(_showRawData ? Icons.show_chart : Icons.table_chart),
                      label: Text(_showRawData ? 'Show Chart' : 'Show Raw Data'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Raw Data Table
            if (_showRawData) _buildDataTable(data),

            // Data Source Information
            Card(
              margin: EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About NASA POWER Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'NASA POWER (Prediction of Worldwide Energy Resources) provides solar, '
                          'meteorological, and agricultural parameters derived from satellite '
                          'observations and atmospheric models.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    _buildInfoItem('• Data Source: NASA satellites and models'),
                    _buildInfoItem('• Spatial Resolution: 0.5° × 0.5° (≈55 km)'),
                    _buildInfoItem('• Temporal Resolution: Daily'),
                    _buildInfoItem('• Parameters: Solar radiation, temperature, precipitation, humidity'),
                    _buildInfoItem('• Applications: Agriculture, renewable energy, climate studies'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePeriodChip(String label, int days) {
    return FilterChip(
      label: Text(label),
      selected: _selectedChartDays == days,
      onSelected: (selected) {
        setState(() {
          _selectedChartDays = selected ? days : _selectedChartDays;
        });
      },
    );
  }

  Widget _buildParameterChart(List<WeatherData> data) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _parameterTitles[_selectedParameter] ?? 'Parameter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('MMM d'),
                  labelStyle: TextStyle(fontSize: 10),
                  majorGridLines: MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(
                    text: _parameterUnits[_selectedParameter] ?? '',
                  ),
                  numberFormat: NumberFormat('#.##'),
                  majorGridLines: MajorGridLines(width: 0.5),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x : point.y ${_parameterUnits[_selectedParameter]}',
                ),
                zoomPanBehavior: ZoomPanBehavior(
                  enablePinching: true,
                  enablePanning: true,
                  zoomMode: ZoomMode.x,
                ),
                series: <CartesianSeries<WeatherData, DateTime>>[
                  _getChartSeries(data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  CartesianSeries<WeatherData, DateTime> _getChartSeries(List<WeatherData> data) {
    switch (_selectedParameter) {
      case 'solar':
        return LineSeries<WeatherData, DateTime>(
          dataSource: data,
          xValueMapper: (WeatherData d, _) => d.time,
          yValueMapper: (WeatherData d, _) => d.solarRadiation ?? 0,
          name: 'Solar Radiation',
          color: Colors.orange,
          markerSettings: MarkerSettings(isVisible: true),
        );
      case 'temperature':
        return LineSeries<WeatherData, DateTime>(
          dataSource: data,
          xValueMapper: (WeatherData d, _) => d.time,
          yValueMapper: (WeatherData d, _) => d.temperature,
          name: 'Temperature',
          color: Colors.red,
          markerSettings: MarkerSettings(isVisible: true),
        );
      case 'moisture':
        return LineSeries<WeatherData, DateTime>(
          dataSource: data,
          xValueMapper: (WeatherData d, _) => d.time,
          yValueMapper: (WeatherData d, _) => d.soilMoisture ?? 0,
          name: 'Soil Moisture',
          color: Colors.blue,
          markerSettings: MarkerSettings(isVisible: true),
        );
      case 'soil_temp':
        return LineSeries<WeatherData, DateTime>(
          dataSource: data,
          xValueMapper: (WeatherData d, _) => d.time,
          yValueMapper: (WeatherData d, _) => d.soilTemperature ?? 0,
          name: 'Soil Temperature',
          color: Colors.brown,
          markerSettings: MarkerSettings(isVisible: true),
        );
      case 'precipitation':
        return ColumnSeries<WeatherData, DateTime>(
          dataSource: data,
          xValueMapper: (WeatherData d, _) => d.time,
          yValueMapper: (WeatherData d, _) => d.precipitation,
          name: 'Precipitation',
          color: Colors.lightBlue,
        );
      default:
        return LineSeries<WeatherData, DateTime>(
          dataSource: data,
          xValueMapper: (WeatherData d, _) => d.time,
          yValueMapper: (WeatherData d, _) => d.temperature,
          name: 'Temperature',
          color: Colors.red,
        );
    }
  }

  Widget _buildCurrentValues(WeatherData? currentData) {
    if (currentData == null) {
      return Center(child: Text('No current data available'));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildValueCard(
          'Solar Radiation',
          '${currentData.solarRadiation?.toStringAsFixed(2) ?? 'N/A'} kWh/m²',
          Colors.orange,
          Icons.wb_sunny,
        ),
        _buildValueCard(
          'Temperature',
          '${currentData.temperature.toStringAsFixed(1)}°C',
          Colors.red,
          Icons.thermostat,
        ),
        _buildValueCard(
          'Soil Moisture',
          currentData.soilMoisture != null
              ? '${currentData.soilMoisture!.toStringAsFixed(1)}%'
              : 'N/A',
          Colors.blue,
          Icons.opacity,
        ),
        _buildValueCard(
          'Soil Temperature',
          currentData.soilTemperature != null
              ? '${currentData.soilTemperature!.toStringAsFixed(1)}°C'
              : 'N/A',
          Colors.brown,
          Icons.grass,
        ),
        _buildValueCard(
          'Humidity',
          '${currentData.humidity.toStringAsFixed(0)}%',
          Colors.lightBlue,
          Icons.water_drop,
        ),
        _buildValueCard(
          'Precipitation',
          '${currentData.precipitation.toStringAsFixed(1)} mm',
          Colors.blue[900]!,
          Icons.cloudy_snowing,
        ),
      ],
    );
  }

  Widget _buildValueCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary(Map<String, dynamic> soilAnalysis, Map<String, dynamic> solarAnalysis) {
    return Column(
      children: [
        // Soil Analysis
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.brown[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Soil Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown[800],
                ),
              ),
              SizedBox(height: 8),
              _buildAnalysisRow('Average Moisture', '${soilAnalysis['averageMoisture']?.toStringAsFixed(1) ?? 'N/A'}%'),
              _buildAnalysisRow('Moisture Status', soilAnalysis['moistureStatus'] ?? 'Unknown'),
              _buildAnalysisRow('Average Temperature', '${soilAnalysis['averageTemperature']?.toStringAsFixed(1) ?? 'N/A'}°C'),
              _buildAnalysisRow('Temperature Status', soilAnalysis['temperatureStatus'] ?? 'Unknown'),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Solar Analysis
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solar Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              SizedBox(height: 8),
              _buildAnalysisRow('Average Radiation', '${solarAnalysis['average']?.toStringAsFixed(2) ?? 'N/A'} kWh/m²'),
              _buildAnalysisRow('Maximum', '${solarAnalysis['max']?.toStringAsFixed(2) ?? 'N/A'} kWh/m²'),
              _buildAnalysisRow('Minimum', '${solarAnalysis['min']?.toStringAsFixed(2) ?? 'N/A'} kWh/m²'),
              _buildAnalysisRow('Total', '${solarAnalysis['total']?.toStringAsFixed(1) ?? 'N/A'} kWh/m²'),
              _buildAnalysisRow('Suitability', solarAnalysis['suitableForSolar'] ? 'Good for Solar' : 'Limited Solar'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<WeatherData> data) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raw Data (Last $_selectedChartDays Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Container(
              height: 400,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 20,
                  columns: [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Solar\nkWh/m²', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    DataColumn(label: Text('Temp\n°C', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    DataColumn(label: Text('Soil\nMoist %', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    DataColumn(label: Text('Soil\nTemp °C', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    DataColumn(label: Text('Rain\nmm', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                  rows: data.map((d) {
                    return DataRow(cells: [
                      DataCell(Text(DateFormat('MMM d').format(d.time))),
                      DataCell(Text(d.solarRadiation?.toStringAsFixed(2) ?? 'N/A', textAlign: TextAlign.center)),
                      DataCell(Text(d.temperature.toStringAsFixed(1), textAlign: TextAlign.center)),
                      DataCell(Text(d.soilMoisture?.toStringAsFixed(1) ?? 'N/A', textAlign: TextAlign.center)),
                      DataCell(Text(d.soilTemperature?.toStringAsFixed(1) ?? 'N/A', textAlign: TextAlign.center)),
                      DataCell(Text(d.precipitation.toStringAsFixed(1), textAlign: TextAlign.center)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _exportDataToCSV(data);
              },
              icon: Icon(Icons.download),
              label: Text('Export Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  void _exportDataToCSV(List<WeatherData> data) {
    final csvData = StringBuffer();

    // Headers
    csvData.writeln('Date,Solar Radiation (kWh/m²),Temperature (°C),Soil Moisture (%),Soil Temperature (°C),Precipitation (mm)');

    // Data rows
    for (final d in data) {
      csvData.writeln('${DateFormat('yyyy-MM-dd').format(d.time)},'
          '${d.solarRadiation?.toStringAsFixed(2) ?? ""},'
          '${d.temperature.toStringAsFixed(1)},'
          '${d.soilMoisture?.toStringAsFixed(1) ?? ""},'
          '${d.soilTemperature?.toStringAsFixed(1) ?? ""},'
          '${d.precipitation.toStringAsFixed(1)}');
    }

    // In a real app, you would save this to a file
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV data generated (${data.length} rows)'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // Copy to clipboard
          },
        ),
      ),
    );
  }
}