import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    primaryColor: Colors.green[800],
    scaffoldBackgroundColor: Colors.green[50],
    appBarTheme: AppBarTheme(
      color: Colors.green[800],
      elevation: 4,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.green),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.green, width: 2),
      ),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      buttonColor: Colors.green[800],
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.green[900],
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.green[800],
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.grey[800],
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
      ),
    ),
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(background: Colors.green[50]),
  );

  static final darkTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: Colors.green[700],
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    appBarTheme: AppBarTheme(
      color: Colors.green[900],
      elevation: 4,
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.green[100],
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.green[200],
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.grey[300],
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Colors.grey[400],
      ),
    ),
  );
}