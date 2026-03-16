import 'package:agric_advisory/providers/soil_api_provider.dart';
import 'package:agric_advisory/providers/soil_hive_provider.dart';
import 'package:agric_advisory/screens/crop_analysis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';

import 'models/soil_data.dart';
import 'models/soil_data.g.dart';
import 'providers/weather_provider.dart';
import 'providers/crop_provider.dart';
import 'providers/nasa_power_provider.dart';
import 'providers/fao_provider.dart';

import 'screens/home_screen.dart';
import 'screens/soil_analysis_screen.dart';
import 'screens/crop_recommendation_screen.dart';
import 'screens/advisory_screen.dart';
import 'screens/nasa_data_screen.dart';
import 'screens/api_info_screen.dart';

import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await dotenv.load(fileName: ".env");

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(SoilDataAdapter());

  // Open boxes
  await Hive.openBox<SoilData>('soilData');
  await Hive.openBox('soilSettings');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => CropProvider()),
        ChangeNotifierProvider(create: (_) => NASAPowerProvider()),
        ChangeNotifierProvider(create: (_) => FAOProvider()),
        ChangeNotifierProvider(create: (_) => SoilHiveProvider()),
        ChangeNotifierProvider(create: (_) => SoilApiProvider(
          soilHiveApiKey: 'eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJFV0NOLVhZSm1NejBvak5EbUFwNmhzcm1iOEVGMVdiNHJCU0xURWNVS1JVIn0.eyJleHAiOjE3NzA4ODkzNDIsImlhdCI6MTc3MDgwMjk0MiwianRpIjoiZWU2OWQ5MDYtMjlkNy00ODdmLThkYWQtZjcxNTc4MDdhYjg1IiwiaXNzIjoiaHR0cHM6Ly9hdXRoLnNvaWxoaXZlLmFnL3JlYWxtcy9zb2lsaGl2ZSIsImF1ZCI6Imh0dHBzOi8vYXBpLnNvaWxoaXZlLmFnLyIsInN1YiI6ImFiZDk0YmRkLWY2MWQtNDRlNi1iNWY5LTYwNTAyMDY0ZTRkYSIsInR5cCI6IkJlYXJlciIsImF6cCI6IjAxOWJiYWJmNWIwNjc2MDBiMWZlZTU5MjhmM2M4MDY4Iiwic2NvcGUiOiJzb2lsaGl2ZS1hcGktc2VydmljZXMiLCJjbGllbnRIb3N0IjoiMzUuMTU5LjE1LjY3IiwiZ3R5IjoiY2xpZW50X2NyZWRlbnRpYWxzIiwiY2xpZW50QWRkcmVzcyI6IjM1LjE1OS4xNS42NyIsImNsaWVudF9pZCI6IjAxOWJiYWJmNWIwNjc2MDBiMWZlZTU5MjhmM2M4MDY4In0.YKH8wMvGwgqnkeEI5mfGsZRx0q3uTUhylCZJsyumvJOIlvZtx977Uq565iWsUEDBhrXPsrdBWV4_GaO--7YFdi7gZB3y8pSiAVbuT5mgSPYb5ahqPFujfyYgv4AgLQ4v448JM-xaAvRAhfzzs6v9LfJoZ5wSWDqgPdsWM_xMCnHGgV2XBN8dMyCPdN757w1kBYA9MiqYguJjVC4xbbiwJw4QEw7q8QSFnqS-4M4ABSgJx_PWcM0toI1118NsfJBJeNC9C4LzJJVjDVge6BB-ggsFCXj0hRhAfCv27wRnTWSyIEMFZfznPXizVhGCB8vggnuVXmBFIQ8v01nYRtXA0A',
          openWeatherApiKey: null, // Add your OpenWeather API key if needed
          useMultiSourceFallback: true,
          useLocalApi: true,
        )),
      ],
      child: MaterialApp(
        title: 'AgriWeather Advisor',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => HomeScreen(),
          '/soil': (context) => SoilAnalysisScreen(),
          '/crop_analysis': (context) => CropAnalysisScreen(),
          '/crops': (context) => CropRecommendationScreen(),
          '/advisory': (context) => AdvisoryScreen(),
          '/nasa': (context) => NASADataScreen(),
          '/api_info': (context) => APIInfoScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}