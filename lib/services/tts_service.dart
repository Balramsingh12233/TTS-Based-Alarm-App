import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isLooping = false;
  bool _isSpeaking = false;
  String? _currentMessage;

  bool get isSpeaking => _isSpeaking;
  bool get isLooping => _isLooping;

  /// Initialize TTS engine & configure audio focus / stream
  Future<void> init() async {
    try {
      // Configure audio attributes:
      // Uses navigation/alarm level attributes and shared audio instance for audio ducking
      await _flutterTts.setAudioAttributesForNavigation();
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      // Default speech settings
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() async {
        _isSpeaking = false;
        // If looping is active, wait briefly and speak again
        if (_isLooping && _currentMessage != null && _currentMessage!.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 1200));
          if (_isLooping) {
            // focus: true enforces audio focus ducking on Android
            await _flutterTts.speak(_currentMessage!, focus: true);
          }
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });
    } catch (e) {
      debugPrint('Failed to initialize TTS service: $e');
    }
  }

  /// Start repeating the custom text continuously until user dismisses or snoozes
  Future<void> startAlarmLoop({
    required String text,
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String language = 'en-US',
  }) async {
    _isLooping = true;
    _currentMessage = text;

    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);

      // focus: true requests Android audio focus with ducking of other audio
      await _flutterTts.speak(text, focus: true);
    } catch (e) {
      debugPrint('Error starting TTS alarm loop: $e');
    }
  }

  /// Stop any ongoing speech and terminate the loop
  Future<void> stop() async {
    _isLooping = false;
    _currentMessage = null;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  /// Preview speech once (for testing sound in UI)
  Future<void> previewSpeech({
    required String text,
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String language = 'en-US',
  }) async {
    _isLooping = false;
    await _flutterTts.stop();

    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setVolume(volume);

    await _flutterTts.speak(text, focus: true);
  }

  /// Get list of available TTS languages on device
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      if (languages is List) {
        return languages.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error getting languages: $e');
    }
    return ['en-US', 'hi-IN'];
  }
}
