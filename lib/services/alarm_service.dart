import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import '../models/tts_alarm_model.dart';
import 'tts_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final TtsService _ttsService = TtsService();
  StreamSubscription<dynamic>? _ringSubscription;
  final Set<int> _activeRingingIds = {};

  /// Callback when an alarm starts ringing (useful for UI navigation)
  Function(TtsAlarmModel alarm)? onAlarmTriggered;

  /// Initialize Alarm system
  Future<void> init({Function(TtsAlarmModel alarm)? onTriggered}) async {
    onAlarmTriggered = onTriggered;
    await Alarm.init();

    // Listen to ringing alarms stream from Alarm package
    _ringSubscription?.cancel();
    _ringSubscription = Alarm.ringing.listen((alarmSet) {
      final currentAlarms = alarmSet.alarms;
      if (currentAlarms.isEmpty) {
        _activeRingingIds.clear();
        _ttsService.stop();
        return;
      }

      for (final alarmSettings in currentAlarms) {
        if (!_activeRingingIds.contains(alarmSettings.id)) {
          _activeRingingIds.add(alarmSettings.id);
          _handleAlarmRing(alarmSettings);
        }
      }
    });
  }

  void _handleAlarmRing(AlarmSettings settings) {
    debugPrint('Alarm ringing for ID: ${settings.id}');
    final textToSpeak = settings.notificationSettings.body;
    final title = settings.notificationSettings.title;

    // Start repeating TTS custom message
    _ttsService.startAlarmLoop(
      text: textToSpeak.isNotEmpty ? textToSpeak : 'Wake up! It is time for your alarm.',
    );

    if (onAlarmTriggered != null) {
      final model = TtsAlarmModel(
        id: settings.id,
        dateTime: settings.dateTime,
        ttsMessage: textToSpeak,
        label: title,
      );
      onAlarmTriggered!(model);
    }
  }

  /// Schedule an exact alarm using the alarm package
  Future<bool> scheduleAlarm(TtsAlarmModel model) async {
    try {
      final alarmSettings = AlarmSettings(
        id: model.id,
        dateTime: model.dateTime,
        // Silent audio asset keeps native Android AlarmManager foreground service & wake-lock active
        assetAudioPath: 'assets/audio/silent.wav',
        loopAudio: false,
        vibrate: true,
        volumeSettings: const VolumeSettings.fixed(
          volume: 0.1,
          volumeEnforced: true,
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(
          title: model.label.isNotEmpty ? model.label : 'TTS Alarm',
          body: model.ttsMessage.isNotEmpty ? model.ttsMessage : 'Time to wake up!',
          stopButton: 'Stop Alarm',
          icon: 'notification_icon',
        ),
      );

      final success = await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('Scheduled alarm id: ${model.id}, success: $success at ${model.dateTime}');
      return success;
    } catch (e) {
      debugPrint('Error scheduling alarm: $e');
      return false;
    }
  }

  /// Stop the alarm sound and TTS speech
  Future<void> stopAlarm(int id) async {
    try {
      _activeRingingIds.remove(id);
      await Alarm.stop(id);
      if (_activeRingingIds.isEmpty) {
        await _ttsService.stop();
      }
      debugPrint('Alarm $id stopped successfully');
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  /// Snooze the alarm for given minutes
  Future<void> snoozeAlarm(TtsAlarmModel model, {int? snoozeMinutes}) async {
    final minutes = snoozeMinutes ?? model.snoozeDurationMinutes;
    await stopAlarm(model.id);

    final snoozedTime = DateTime.now().add(Duration(minutes: minutes));
    final snoozedModel = model.copyWith(dateTime: snoozedTime);
    await scheduleAlarm(snoozedModel);
    debugPrint('Alarm ${model.id} snoozed for $minutes minutes until $snoozedTime');
  }

  /// Check if a specific alarm is currently ringing
  Future<bool> isRinging(int id) async {
    return Alarm.isRinging(id);
  }

  void dispose() {
    _ringSubscription?.cancel();
  }
}
