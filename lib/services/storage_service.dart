import 'package:shared_preferences/shared_preferences.dart';
import '../models/tts_alarm_model.dart';

class StorageService {
  static const String _alarmsKey = 'saved_tts_alarms';

  /// Save the full list of alarms to local persistent storage
  static Future<void> saveAlarms(List<TtsAlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = alarms.map((a) => a.toJson()).toList();
    await prefs.setStringList(_alarmsKey, jsonList);
  }

  /// Load all saved alarms from local persistent storage
  static Future<List<TtsAlarmModel>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_alarmsKey);
    if (jsonList == null || jsonList.isEmpty) {
      return [];
    }
    return jsonList.map((str) => TtsAlarmModel.fromJson(str)).toList();
  }

  /// Add or update a single alarm
  static Future<void> upsertAlarm(TtsAlarmModel alarm) async {
    final list = await loadAlarms();
    final index = list.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      list[index] = alarm;
    } else {
      list.add(alarm);
    }
    await saveAlarms(list);
  }

  /// Remove an alarm by ID
  static Future<void> deleteAlarm(int id) async {
    final list = await loadAlarms();
    list.removeWhere((a) => a.id == id);
    await saveAlarms(list);
  }
}
