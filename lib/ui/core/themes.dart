import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color lightBg = Color(0xFFF9FAFB);
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightPrimary = Color(0xFF1E3A8A); // Royal Blue
  static const Color lightAccent = Color(0xFFD97706); // Amber

  // Sepia Theme Colors
  static const Color sepiaBg = Color(0xFFF4ECD8);
  static const Color sepiaSurface = Color(0xFFEFE6CF);
  static const Color sepiaTextPrimary = Color(0xFF433422);
  static const Color sepiaTextSecondary = Color(0xFF705E47);
  static const Color sepiaPrimary = Color(0xFF5D4037); // Dark Brown
  static const Color sepiaAccent = Color(0xFF8D6E63);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkPrimary = Color(0xFF60A5FA); // Ice Blue
  static const Color darkAccent = Color(0xFFFBBF24); // Gold

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        primary: lightPrimary,
        secondary: lightAccent,
      ),
      fontFamily: 'serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(color: lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary, fontSize: 18, height: 1.6, fontFamily: 'serif'),
        bodyMedium: TextStyle(color: lightTextSecondary, fontSize: 16, height: 1.5, fontFamily: 'sans-serif'),
        titleLarge: TextStyle(color: lightTextPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif'),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkPrimary,
      colorScheme: const ColorScheme.dark(
        surface: darkSurface,
        primary: darkPrimary,
        secondary: darkAccent,
      ),
      fontFamily: 'serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary, fontSize: 18, height: 1.6, fontFamily: 'serif'),
        bodyMedium: TextStyle(color: darkTextSecondary, fontSize: 16, height: 1.5, fontFamily: 'sans-serif'),
        titleLarge: TextStyle(color: darkTextPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif'),
      ),
    );
  }

  static ThemeData get sepiaTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: sepiaBg,
      primaryColor: sepiaPrimary,
      colorScheme: const ColorScheme.light(
        surface: sepiaSurface,
        primary: sepiaPrimary,
        secondary: sepiaAccent,
      ),
      fontFamily: 'serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: sepiaSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: sepiaTextPrimary),
        titleTextStyle: TextStyle(color: sepiaTextPrimary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: sepiaTextPrimary, fontSize: 18, height: 1.6, fontFamily: 'serif'),
        bodyMedium: TextStyle(color: sepiaTextSecondary, fontSize: 16, height: 1.5, fontFamily: 'sans-serif'),
        titleLarge: TextStyle(color: sepiaTextPrimary, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif'),
      ),
    );
  }
}
