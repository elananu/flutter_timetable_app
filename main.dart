// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const TimetableApp());

class TimetableApp extends StatelessWidget {
  const TimetableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeTable Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: const ColorScheme.light(
          primary:   Color(0xFF1A56DB),   // deep professional blue
          secondary: Color(0xFF0E9F6E),   // teal-green accent
          tertiary:  Color(0xFFF05252),   // red for alerts/absent
          surface:   Color(0xFFFFFFFF),
          error:     Color(0xFFF05252),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1F36),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A56DB),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A56DB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1A1F36),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
