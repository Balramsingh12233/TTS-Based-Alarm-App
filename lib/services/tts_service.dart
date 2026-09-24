import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  // Direct channel to flutter_tts plugin for methods not exposed in Dart API
  static const MethodChannel _ttsChannel = MethodChannel('flutter_tts');
  bool _isLooping = false;
  bool _isSpeaking = false;
  String? _currentMessage;

  /// ValueNotifier to reactively notify UI when speaking starts/stops in real-time
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  bool get isSpeaking => _isSpeaking;
  bool get isLooping => _isLooping;

  /// Initialize TTS engine & configure audio focus
  Future<void> init() async {
    try {
      // Set awaitSpeakCompletion to ensure proper lifecycle callback timing
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setSharedInstance(true);

      // *** CRITICAL FIX: Route TTS through STREAM_ALARM, not STREAM_MUSIC ***
      // Calls the patched native method in flutter_tts plugin:
      //   AudioAttributes.USAGE_ALARM + CONTENT_TYPE_SONIFICATION + FLAG_AUDIBILITY_ENFORCED
      // This bypasses ALL Android AudioFocus rules — TTS plays on BOTH locked & unlocked screens.
      await _ttsChannel.invokeMethod('setAudioAttributesForAlarm');

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
        isSpeakingNotifier.value = true;
      });

      _flutterTts.setCompletionHandler(() async {
        _isSpeaking = false;
        // If looping is active, wait briefly and speak again
        if (_isLooping && _currentMessage != null && _currentMessage!.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 1000));
          if (_isLooping) {
            _isSpeaking = true;
            isSpeakingNotifier.value = true;
            await _flutterTts.speak(_currentMessage!, focus: true);
          }
        } else {
          isSpeakingNotifier.value = false;
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
        isSpeakingNotifier.value = false;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        isSpeakingNotifier.value = false;
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
    String language = 'hi-IN',
  }) async {
    _isLooping = true;
    _currentMessage = text;

    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume.clamp(0.1, 1.0));

      _isSpeaking = true;
      isSpeakingNotifier.value = true;

      // focus: true requests Android audio focus with ducking of other audio (Spotify, etc.)
      await _flutterTts.speak(text, focus: true);
    } catch (e) {
      debugPrint('Error starting TTS alarm loop: $e');
      _isSpeaking = false;
      isSpeakingNotifier.value = false;
    }
  }

  /// Stop any ongoing speech and terminate the loop
  Future<void> stop() async {
    _isLooping = false;
    _isSpeaking = false;
    _currentMessage = null;
    isSpeakingNotifier.value = false;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  /// Preview speech once (for testing sound in UI with real-time state)
  Future<void> previewSpeech({
    required String text,
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String language = 'hi-IN',
  }) async {
    _isLooping = false;
    await stop();

    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume.clamp(0.1, 1.0));

      _isSpeaking = true;
      isSpeakingNotifier.value = true;

      await _flutterTts.speak(text, focus: true);
      _isSpeaking = false;
      isSpeakingNotifier.value = false;
    } catch (e) {
      debugPrint('Error in previewSpeech: $e');
      _isSpeaking = false;
      isSpeakingNotifier.value = false;
    }
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
