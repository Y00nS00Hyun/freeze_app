// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/event_viewer_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Sense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FBFD),

        // ⬇️ CardTheme ➜ CardThemeData 로 변경
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent, // 틴트 제거
          elevation: 4,
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF78B8C4),
          surface: Colors.white, // surface도 흰색으로
        ),
      ),

      home: const EventViewerPage(
        endpoint: 'ws://13.55.215.70:8000/ws/app?topic=public',
      ),
    );
  }
}
