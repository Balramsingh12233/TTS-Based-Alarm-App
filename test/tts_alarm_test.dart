import 'package:flutter_test/flutter_test.dart';
import 'package:tts_alarm/models/tts_alarm_model.dart';
import 'package:tts_alarm/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsAlarmModel - Next Occurrence and Specific Date Scheduling', () {
    test('Specific date alarm returns exact date and time', () {
      final specificDateTime = DateTime(2026, 10, 25, 14, 30);
      final alarm = TtsAlarmModel(
        id: 1,
        dateTime: specificDateTime,
        ttsMessage: 'Meeting reminder',
        label: 'Client Meeting',
        isSpecificDate: true,
        repeatDays: const [],
      );

      final next = alarm.getNextOccurrence(from: DateTime(2026, 10, 6, 9, 0));
      expect(next, equals(specificDateTime));
      expect(alarm.isSpecificDate, isTrue);
    });

    test('Recurring daily alarm schedules tomorrow when time has passed today', () {
      final now = DateTime(2026, 10, 6, 11, 30); // 11:30 AM
      final alarm = TtsAlarmModel(
        id: 2,
        dateTime: DateTime(2026, 10, 6, 7, 0), // 7:00 AM
        ttsMessage: 'Morning routine',
        repeatDays: const [1, 2, 3, 4, 5, 6, 7], // Every day
        isSpecificDate: false,
      );

      final next = alarm.getNextOccurrence(from: now);
      expect(next.year, equals(2026));
      expect(next.month, equals(10));
      expect(next.day, equals(7)); // Tomorrow!
      expect(next.hour, equals(7));
      expect(next.minute, equals(0));
    });

    test('Recurring daily alarm schedules today when time is still upcoming', () {
      final now = DateTime(2026, 10, 6, 11, 30); // 11:30 AM
      final alarm = TtsAlarmModel(
        id: 3,
        dateTime: DateTime(2026, 10, 6, 18, 0), // 6:00 PM
        ttsMessage: 'Evening workout',
        repeatDays: const [1, 2, 3, 4, 5, 6, 7], // Every day
        isSpecificDate: false,
      );

      final next = alarm.getNextOccurrence(from: now);
      expect(next.year, equals(2026));
      expect(next.month, equals(10));
      expect(next.day, equals(6)); // Today!
      expect(next.hour, equals(18));
      expect(next.minute, equals(0));
    });

    test('Recurring weekday alarm jumps from Friday evening to Monday morning', () {
      // 2026-10-09 is a Friday (weekday 5)
      final fridayEvening = DateTime(2026, 10, 9, 20, 0); // 8:00 PM Friday
      final alarm = TtsAlarmModel(
        id: 4,
        dateTime: DateTime(2026, 10, 9, 7, 0), // 7:00 AM
        ttsMessage: 'Workday alarm',
        repeatDays: const [1, 2, 3, 4, 5], // Monday through Friday
        isSpecificDate: false,
      );

      final next = alarm.getNextOccurrence(from: fridayEvening);
      // Next occurrence must be Monday (2026-10-12, weekday 1)
      expect(next.year, equals(2026));
      expect(next.month, equals(10));
      expect(next.day, equals(12));
      expect(next.weekday, equals(DateTime.monday));
      expect(next.hour, equals(7));
      expect(next.minute, equals(0));
    });

    test('One-time alarm with no repeat days targets tomorrow if time passed', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final alarm = TtsAlarmModel(
        id: 5,
        dateTime: DateTime(2026, 10, 6, 8, 0),
        ttsMessage: 'One-off alarm',
        repeatDays: const [],
        isSpecificDate: false,
      );

      final next = alarm.getNextOccurrence(from: now);
      expect(next.day, equals(7));
      expect(next.hour, equals(8));
    });

    test('Serialization backward compatibility and isSpecificDate persistence', () {
      // Legacy map without isSpecificDate
      final legacyMap = {
        'id': 101,
        'dateTime': '2026-10-06T07:00:00.000',
        'ttsMessage': 'Good morning',
        'label': 'TTS Alarm',
        'isEnabled': true,
        'speechRate': 0.5,
        'pitch': 1.0,
        'volume': 1.0,
        'language': 'hi-IN',
        'snoozeDurationMinutes': 5,
        'repeatDays': [1, 2, 3, 4, 5],
        'isLoopEnabled': true,
        'voiceName': 'Aarav • Male • Hindi',
        'fullScreenIntent': true,
      };

      final legacyModel = TtsAlarmModel.fromMap(legacyMap);
      expect(legacyModel.isSpecificDate, isFalse);

      // New map with isSpecificDate = true
      final newMap = Map<String, dynamic>.from(legacyMap);
      newMap['isSpecificDate'] = true;
      newMap['label'] = 'Dentist Appointment';

      final newModel = TtsAlarmModel.fromMap(newMap);
      expect(newModel.isSpecificDate, isTrue);
      expect(newModel.label, equals('Dentist Appointment'));

      // Check toMap preserves isSpecificDate
      final serialized = newModel.toMap();
      expect(serialized['isSpecificDate'], isTrue);
      expect(serialized['label'], equals('Dentist Appointment'));
    });
  });

  group('TtsService - Voice Resolution', () {
    final tts = TtsService();

    setUp(() {
      tts.setDeviceVoicesForTesting([
        {'name': 'hi-in-x-cfc#male_1-local', 'locale': 'hi-IN'},
        {'name': 'hi-in-x-cfc-local', 'locale': 'hi-IN'},
        {'name': 'hi-in-x-hia-local', 'locale': 'hi-IN'},
        {'name': 'en-us-x-iom-local', 'locale': 'en-US'},
        {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
      ]);
    });

    test('Hindi voice resolves to natural voice (cfc)', () {
      final hindiVoice = tts.findBestVoice(language: 'hi-IN');
      expect(hindiVoice, isNotNull);
      expect(hindiVoice!['name'], equals('hi-in-x-cfc#male_1-local'));
    });

    test('English voice resolves to natural voice (iom)', () {
      final englishVoice = tts.findBestVoice(language: 'en-US');
      expect(englishVoice, isNotNull);
      expect(englishVoice!['name'], equals('en-us-x-iom-local'));
    });
  });
}
