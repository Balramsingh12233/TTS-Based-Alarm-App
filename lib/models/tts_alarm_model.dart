import 'dart:convert';

/// Model representing a TTS-powered alarm.
class TtsAlarmModel {
  final int id;
  final DateTime dateTime;
  final String ttsMessage;
  final String label;
  final bool isEnabled;
  final double speechRate;
  final double pitch;
  final double volume;
  final String language;
  final int snoozeDurationMinutes;
  final List<int> repeatDays; // 1 = Mon, 7 = Sun
  final bool isLoopEnabled;
  final String voiceName;
  final bool fullScreenIntent;
  final bool isSpecificDate;

  const TtsAlarmModel({
    required this.id,
    required this.dateTime,
    required this.ttsMessage,
    this.label = 'Alarm',
    this.isEnabled = true,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.language = 'hi-IN',
    this.snoozeDurationMinutes = 5,
    this.repeatDays = const [1, 2, 3, 4, 5],
    this.isLoopEnabled = true,
    this.voiceName = 'Aarav • Hindi',
    this.fullScreenIntent = true,
    this.isSpecificDate = false,
  });

  /// Computes the next valid trigger DateTime from a given reference point [from] (default: DateTime.now()).
  DateTime getNextOccurrence({DateTime? from}) {
    final now = from ?? DateTime.now();

    // 1. If it's a specific date / event alarm, keep the user-chosen date
    if (isSpecificDate) {
      return dateTime;
    }

    // 2. If it's a recurring alarm with designated repeatDays (1 = Mon ... 7 = Sun)
    if (repeatDays.isNotEmpty) {
      for (int dayOffset = 0; dayOffset <= 7; dayOffset++) {
        final candidateDate = now.add(Duration(days: dayOffset));
        final candidate = DateTime(
          candidateDate.year,
          candidateDate.month,
          candidateDate.day,
          dateTime.hour,
          dateTime.minute,
          0,
        );

        if (repeatDays.contains(candidate.weekday)) {
          if (dayOffset == 0) {
            if (candidate.isAfter(now.add(const Duration(seconds: 10)))) {
              return candidate;
            }
          } else {
            return candidate;
          }
        }
      }
    }

    // 3. One-time alarm (no specific repeat days): Today if still upcoming, else Tomorrow
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      dateTime.hour,
      dateTime.minute,
      0,
    );
    if (target.isBefore(now.add(const Duration(seconds: 10)))) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// Copy with helper for immutability
  TtsAlarmModel copyWith({
    int? id,
    DateTime? dateTime,
    String? ttsMessage,
    String? label,
    bool? isEnabled,
    double? speechRate,
    double? pitch,
    double? volume,
    String? language,
    int? snoozeDurationMinutes,
    List<int>? repeatDays,
    bool? isLoopEnabled,
    String? voiceName,
    bool? fullScreenIntent,
    bool? isSpecificDate,
  }) {
    return TtsAlarmModel(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      ttsMessage: ttsMessage ?? this.ttsMessage,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      language: language ?? this.language,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      repeatDays: repeatDays ?? this.repeatDays,
      isLoopEnabled: isLoopEnabled ?? this.isLoopEnabled,
      voiceName: voiceName ?? this.voiceName,
      fullScreenIntent: fullScreenIntent ?? this.fullScreenIntent,
      isSpecificDate: isSpecificDate ?? this.isSpecificDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'ttsMessage': ttsMessage,
      'label': label,
      'isEnabled': isEnabled,
      'speechRate': speechRate,
      'pitch': pitch,
      'volume': volume,
      'language': language,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'repeatDays': repeatDays,
      'isLoopEnabled': isLoopEnabled,
      'voiceName': voiceName,
      'fullScreenIntent': fullScreenIntent,
      'isSpecificDate': isSpecificDate,
    };
  }

  factory TtsAlarmModel.fromMap(Map<String, dynamic> map) {
    return TtsAlarmModel(
      id: map['id'] as int,
      dateTime: DateTime.parse(map['dateTime'] as String),
      ttsMessage: (map['ttsMessage'] as String?) ?? '',
      label: (map['label'] as String?) ?? 'Alarm',
      isEnabled: (map['isEnabled'] as bool?) ?? true,
      speechRate: (map['speechRate'] as num?)?.toDouble() ?? 0.5,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 1.0,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      language: (map['language'] as String?) ?? 'hi-IN',
      snoozeDurationMinutes: (map['snoozeDurationMinutes'] as int?) ?? 5,
      repeatDays: map['repeatDays'] != null
          ? List<int>.from(map['repeatDays'] as List)
          : const [1, 2, 3, 4, 5],
      isLoopEnabled: (map['isLoopEnabled'] as bool?) ?? true,
      voiceName: _normalizeVoiceName(map['voiceName'] as String?),
      fullScreenIntent: (map['fullScreenIntent'] as bool?) ?? true,
      isSpecificDate: (map['isSpecificDate'] as bool?) ?? false,
    );
  }

  static String _normalizeVoiceName(String? name) {
    if (name == null || name.isEmpty) return 'Aarav • Hindi';
    if (name.contains('Alex') || name.toLowerCase().contains('english') || name.contains('Sophia')) {
      return 'Alex • English';
    }
    return 'Aarav • Hindi';
  }

  String toJson() => json.encode(toMap());

  factory TtsAlarmModel.fromJson(String source) =>
      TtsAlarmModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
