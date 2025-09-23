// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/event_viewer_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

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

        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9FBFD),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF78B8C4),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
      ),
      home: const EventViewerPage(
        endpoint: 'ws://13.55.215.70:8000/ws/app?topic=public',
      ),
    );
  }
}
