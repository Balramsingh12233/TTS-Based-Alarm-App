import 'dart:async';
import 'package:flutter/material.dart';
import 'models/tts_alarm_model.dart';
import 'screens/alarm_list_screen.dart';
import 'screens/alarm_ring_screen.dart';
import 'services/alarm_service.dart';
import 'services/tts_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Queued alarm triggered while navigator wasn't ready yet (app waking from background)
TtsAlarmModel? pendingAlarm;

/// Robustly push the AlarmRingScreen, retrying up to [maxRetries] times with [retryDelay]
/// This handles the case where the app is in the background (unlocked screen) and the
/// Flutter navigator is not yet attached when the alarm fires.
Future<void> navigateToAlarmScreen(TtsAlarmModel alarm) async {
  const retryDelay = Duration(milliseconds: 200);
  const maxRetries = 20; // Try for up to 4 seconds

  for (int i = 0; i < maxRetries; i++) {
    final nav = navigatorKey.currentState;
    if (nav != null && nav.mounted) {
      // Check if AlarmRingScreen is already on top to avoid duplicate pushes
      bool alreadyOnTop = false;
      nav.popUntil((route) {
        if (route.settings.name == '/alarm_ring_${alarm.id}') {
          alreadyOnTop = true;
        }
        return true; // Don't actually pop anything
      });

      if (!alreadyOnTop) {
        nav.push(
          MaterialPageRoute(
            settings: RouteSettings(name: '/alarm_ring_${alarm.id}'),
            builder: (_) => AlarmRingScreen(alarm: alarm),
          ),
        );
      }
      pendingAlarm = null;
      return;
    }
    // Navigator not ready yet - store as pending and wait
    pendingAlarm = alarm;
    await Future.delayed(retryDelay);
  }

  // After max retries, store as pending (will be shown when app resumes via observer)
  pendingAlarm = alarm;
  debugPrint('Navigator not ready after $maxRetries retries — alarm queued as pending.');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize TTS Engine & Alarm System
  await TtsService().init();
  await AlarmService().init(
    onTriggered: (alarm) {
      // Use async navigation with retry so it works on locked AND unlocked screens
      navigateToAlarmScreen(alarm);
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
