import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class APIInfoScreen extends StatelessWidget {
  final List<Map<String, dynamic>> apiInfo = [
    {
      'title': 'NASA POWER API',
      'description': 'NASA Prediction of Worldwide Energy Resources provides solar, meteorological, and agricultural parameters.',
      'links': [
        {
          'text': 'Official Documentation',
          'url': 'https://power.larc.nasa.gov/docs/',
        },
        {
          'text': 'API Documentation',
          'url': 'https://power.larc.nasa.gov/docs/services/api/',
        },
        {
          'text': 'Data Parameters',
          'url': 'https://power.larc.nasa.gov/docs/services/api/data-parameters/',
        },
        {
          'text': 'Agricultural Parameters',
          'url': 'https://power.larc.nasa.gov/docs/services/api/data-parameters/#agriculture-parameters',
        },
      ],
      'color': Colors.blue,
      'icon': Icons.satellite,
    },
    {
      'title': 'Open-Meteo API',
      'description': 'Free weather API providing weather forecasts and historical data.',
      'links': [
        {
          'text': 'Documentation',
          'url': 'https://open-meteo.com/en/docs',
        },
        {
          'text': 'Weather API',
          'url': 'https://open-meteo.com/en/docs#api-documentation',
        },
        {
          'text': 'Historical Weather API',
          'url': 'https://open-meteo.com/en/docs/historical-weather-api',
        },
      ],
      'color': Colors.green,
      'icon': Icons.cloud,
    },
    {
      'title': 'FAO Data',
      'description': 'Food and Agriculture Organization provides agricultural data, water requirements, and crop calendars.',
      'links': [
        {
          'text': 'FAO AQUASTAT',
          'url': 'http://www.fao.org/aquastat/en/',
        },
        {
          'text': 'FAO Crop Calendar',
          'url': 'http://www.fao.org/ag/AGP/AGPC/doc/Cropcalender/cropcal.htm',
        },
        {
          'text': 'FAO Statistical Data',
          'url': 'http://www.fao.org/faostat/en/',
        },
        {
          'text': 'FAO Climate Data',
          'url': 'http://www.fao.org/climate-change/en/',
        },
      ],
      'color': Colors.green[800]!,
      'icon': Icons.agriculture,
    },
    {
      'title': 'Additional Resources',
      'description': 'Other useful agricultural and weather data sources.',
      'links': [
        {
          'text': 'SoilGrids API',
          'url': 'https://www.isric.org/explore/soilgrids',
        },
        {
          'text': 'World Bank Climate Data',
          'url': 'https://climateknowledgeportal.worldbank.org/',
        },
        {
          'text': 'NOAA Climate Data',
          'url': 'https://www.ncdc.noaa.gov/cdo-web/',
        },
        {
          'text': 'USDA Agricultural Data',
          'url': 'https://www.usda.gov/topics/data',
        },
      ],
      'color': Colors.purple,
      'icon': Icons.public,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Documentation'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // App Information
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AgriWeather Advisor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This app integrates multiple data sources to provide comprehensive agricultural weather advisories:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  _buildInfoItem('• Real-time weather data from Open-Meteo'),
                  _buildInfoItem('• Solar and agricultural parameters from NASA POWER'),
                  _buildInfoItem('• Crop requirements and water data from FAO'),
                  _buildInfoItem('• Location-based soil and climate analysis'),
                  _buildInfoItem('• Intelligent crop recommendations'),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // API Cards
          ...apiInfo.map((api) => _buildAPICard(api, context)).toList(),

          // Data Usage Disclaimer
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Usage Notes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildInfoItem('• NASA POWER: Free for research and non-commercial use'),
                  _buildInfoItem('• Open-Meteo: Free with rate limits'),
                  _buildInfoItem('• FAO Data: Publicly available agricultural data'),
                  _buildInfoItem('• Data is cached locally to reduce API calls'),
                  _buildInfoItem('• Historical data is available for 30+ years'),
                  _buildInfoItem('• Agricultural parameters are estimated for advisory purposes'),
                ],
              ),
            ),
          ),

          // Contact/Support
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support & Feedback',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _launchEmail(context);
                    },
                    icon: Icon(Icons.email),
                    label: Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showAboutDialog(context);
                    },
                    icon: Icon(Icons.info),
                    label: Text('About This App'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildAPICard(Map<String, dynamic> api, BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: api['color'].withOpacity(0.1),
                  child: Icon(api['icon'], color: api['color']),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    api['title'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: api['color'],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              api['description'],
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            ...(api['links'] as List).map((link) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => _launchURL(link['url'], context),
                icon: Icon(Icons.open_in_new, size: 16),
                label: Text(link['text']),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 40),
                  side: BorderSide(color: api['color']),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final email = 'support@agriweather.com';
    final subject = 'AgriWeather Advisor Support';
    final body = 'Dear Support Team,\n\n';

    final url = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch email client'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About AgriWeather Advisor'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version: 1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'AgriWeather Advisor integrates multiple data sources to provide '
                    'comprehensive agricultural weather advisories for farmers and '
                    'agricultural professionals.',
              ),
              SizedBox(height: 12),
              Text(
                'Key Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildAboutItem('• Real-time weather data integration'),
              _buildAboutItem('• NASA POWER agricultural parameters'),
              _buildAboutItem('• FAO crop and water requirement data'),
              _buildAboutItem('• Soil moisture and temperature analysis'),
              _buildAboutItem('• Intelligent crop recommendations'),
              _buildAboutItem('• Farming advisories and alerts'),
              SizedBox(height: 12),
              Text(
                'Developed for agricultural decision support.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
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

  Widget _buildAboutItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: TextStyle(fontSize: 14)),
    );
  }
}