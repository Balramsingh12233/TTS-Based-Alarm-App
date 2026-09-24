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

  const TtsAlarmModel({
    required this.id,
    required this.dateTime,
    required this.ttsMessage,
    this.label = 'Alarm',
    this.isEnabled = true,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.language = 'en-US',
    this.snoozeDurationMinutes = 5,
  });

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
      language: (map['language'] as String?) ?? 'en-US',
      snoozeDurationMinutes: (map['snoozeDurationMinutes'] as int?) ?? 5,
    );
  }

  String toJson() => json.encode(toMap());

  factory TtsAlarmModel.fromJson(String source) =>
      TtsAlarmModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
