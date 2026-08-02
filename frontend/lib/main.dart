import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() => runApp(const LifeConnectApp());

// Modernized palette - flat, confident blue as the primary action color,
// warm amber-yellow as a secondary accent (badges, highlights), generous
// light-grey/white surfaces instead of heavy shadows. Inspired by the
// clean, whitespace-first style of apps like Toss, Cash App, and Revolut.
const Color kPrimaryBlue = Color(0xFF2F6FED);
const Color kAccentYellow = Color(0xFFFFC229);
const Color kBackground = Color(0xFFF7F8FB);
const Color kTextPrimary = Color(0xFF111827);
const Color kTextSecondary = Color(0xFF9CA3AF);
const Color kFieldFill = Color(0xFFF3F4F6);
const Color kBorder = Color(0xFFEDEEF1);

class LifeConnectApp extends StatelessWidget {
  const LifeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Connect',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: kPrimaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryBlue,
          primary: kPrimaryBlue,
          secondary: kAccentYellow,
          surface: Colors.white,
          error: const Color(0xFFE24B4A),
        ),
        scaffoldBackgroundColor: kBackground,

        textTheme: const TextTheme(
          displayLarge: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: kTextPrimary),
          bodyMedium: TextStyle(color: kTextPrimary),
          bodySmall: TextStyle(color: kTextSecondary),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          foregroundColor: kTextPrimary,
          iconTheme: IconThemeData(color: kTextPrimary),
          titleTextStyle: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: kBorder),
          ),
          margin: EdgeInsets.zero,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kPrimaryBlue,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kFieldFill,
          hintStyle: const TextStyle(color: kTextSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimaryBlue, width: 1.5),
          ),
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: kPrimaryBlue,
          unselectedItemColor: kTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),

        dividerTheme: const DividerThemeData(color: kBorder, thickness: 1, space: 1),
      ),
      home: const LoginScreen(),
    );
  }
}
