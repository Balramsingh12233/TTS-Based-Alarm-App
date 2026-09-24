import 'package:flutter/material.dart';
import 'screens/alarm_list_screen.dart';
import 'screens/alarm_ring_screen.dart';
import 'services/alarm_service.dart';
import 'services/tts_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize TTS Engine & Alarm System
  await TtsService().init();
  await AlarmService().init(
    onTriggered: (alarm) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlarmRingScreen(alarm: alarm),
        ),
      );
    },
  );

  runApp(const TtsAlarmApp());
}

class TtsAlarmApp extends StatelessWidget {
  const TtsAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TTS Voice Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Midnight Obsidian
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B), // Warm Radiant Amber
          secondary: Color(0xFFFBBF24),
          surface: Color(0xFF131B2A),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const AlarmListScreen(),
    );
  }
}
