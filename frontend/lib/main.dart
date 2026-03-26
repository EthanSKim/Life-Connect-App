import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() => runApp(const LifeConnectApp());

class LifeConnectApp extends StatelessWidget {
  const LifeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 기존 블루의 색감을 살리되 쨍함만 뺀 '컴포트 블루'
    const Color primaryBlue = Color(0xFF6397B5);
    // 2. 노란기를 낮춘 따뜻한 '웜 골드'
    const Color secondaryGold = Color(0xFFE8B65D);
    // 3. 눈이 편안한 미색 배경
    const Color background = Color(0xFFF7F8FA);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Connect',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: secondaryGold,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: background,

        // 텍스트도 너무 시커먼 색 대신, 깊은 네이비 그레이를 써서 고급스럽게
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: Color(0xFF3E4E59),
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Color(0xFF3E4E59)),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: primaryBlue),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
