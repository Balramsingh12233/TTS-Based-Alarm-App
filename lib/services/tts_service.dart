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

  List<Map<String, String>> _deviceVoices = [];

  List<Map<String, String>> get deviceVoices => _deviceVoices;

  @visibleForTesting
  void setDeviceVoicesForTesting(List<Map<String, String>> voices) {
    _deviceVoices = voices;
  }

  @visibleForTesting
  Map<String, String>? findBestVoice({required String language, bool isMale = true}) {
    return _findBestVoice(language: language);
  }

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

      // Load all native TTS voices installed on the device
      await _loadDeviceVoices();

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

  Future<void> _loadDeviceVoices() async {
    try {
      dynamic voices = await _flutterTts.getVoices;
      if (voices == null || (voices is List && voices.isEmpty)) {
        await Future.delayed(const Duration(milliseconds: 300));
        voices = await _flutterTts.getVoices;
      }
      if (voices is List) {
        _deviceVoices = voices.map((v) {
          if (v is Map) {
            return {
              'name': (v['name'] ?? '').toString(),
              'locale': (v['locale'] ?? '').toString(),
            };
          }
          return <String, String>{};
        }).where((m) => m.isNotEmpty && m['name']!.isNotEmpty).toList();
        debugPrint('Loaded ${_deviceVoices.length} native device TTS voices');
      }
    } catch (e) {
      debugPrint('Error loading device voices: $e');
    }
  }

  /// Finds the best native voice on the device for the desired language.
  Map<String, String>? _findBestVoice({required String language}) {
    if (_deviceVoices.isEmpty) return null;

    final langPrefix = language.split('-').first.toLowerCase(); // 'hi' or 'en'
    final matchingLangVoices = _deviceVoices.where((v) {
      final loc = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
      return loc.startsWith(langPrefix);
    }).toList();

    if (matchingLangVoices.isEmpty) return null;

    // Match the exact natural voice that rings clearly and authentically (cfc, male, etc.)
    final candidate = matchingLangVoices.firstWhere(
      (v) {
        final n = (v['name'] ?? '').toLowerCase();
        return n.contains('cfc') ||
            n.contains('male') ||
            n.contains('#m') ||
            n.contains('-m-') ||
            n.contains('man') ||
            n.contains('-hib') ||
            n.contains('-hid') ||
            n.contains('-iom') ||
            n.contains('-iob') ||
            n.contains('-end') ||
            n.contains('-enc');
      },
      orElse: () => <String, String>{},
    );

    if (candidate.isNotEmpty) {
      return candidate;
    }

    return matchingLangVoices.first;
  }

  /// Configures native voice selection and acoustic settings
  Future<void> _applyVoiceAndPitch({
    required String? voiceName,
    required String language,
    required double pitch,
    required double rate,
    required double volume,
  }) async {
    // 1. Ensure device voices are loaded
    if (_deviceVoices.isEmpty) {
      await _loadDeviceVoices();
    }

    // 2. Language selection
    await _flutterTts.setLanguage(language);

    // 3. Find and bind distinct native voice
    final selectedDeviceVoice = _findBestVoice(language: language);

    if (selectedDeviceVoice != null &&
        selectedDeviceVoice['name'] != null &&
        selectedDeviceVoice['name']!.isNotEmpty) {
      try {
        await _flutterTts.setVoice({
          'name': selectedDeviceVoice['name']!,
          'locale': selectedDeviceVoice['locale'] ?? language,
        });
        debugPrint('Applied native voice: ${selectedDeviceVoice['name']} for $voiceName');
      } catch (e) {
        debugPrint('Error applying native voice: $e');
      }
    }

    // 4. Acoustic Pitch & Rate Tuning:
    // Natural pitch 1.0 delivers the full, crisp, authentic tone without distortion
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setVolume(volume.clamp(0.1, 1.0));
  }

  /// Start repeating the custom text continuously until user dismisses or snoozes
  Future<void> startAlarmLoop({
    required String text,
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String language = 'hi-IN',
    String? voiceName,
  }) async {
    _isLooping = true;
    _currentMessage = text;

    try {
      await _applyVoiceAndPitch(
        voiceName: voiceName,
        language: language,
        pitch: pitch,
        rate: rate,
        volume: volume,
      );

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
    String? voiceName,
  }) async {
    _isLooping = false;
    await stop();

    try {
      await _applyVoiceAndPitch(
        voiceName: voiceName,
        language: language,
        pitch: pitch,
        rate: rate,
        volume: volume,
      );

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
