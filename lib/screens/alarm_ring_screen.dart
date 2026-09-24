import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tts_alarm_model.dart';
import '../services/alarm_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final TtsAlarmModel alarm;

  const AlarmRingScreen({
    super.key,
    required this.alarm,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    await AlarmService().stopAlarm(widget.alarm.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _snoozeAlarm() async {
    await AlarmService().snoozeAlarm(widget.alarm);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent accidental dismissal via back gesture
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19), // Midnight Obsidian
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Header: Label & Live Clock
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF243248)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.graphic_eq_rounded, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            widget.alarm.label.isNotEmpty ? widget.alarm.label : 'Voice Alarm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _currentTime,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                // Center: Animated Glowing Speaker & Speaking Box
                Column(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFFFBBF24),
                              Color(0xFFF59E0B),
                              Color(0xFFD97706),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withAlpha(140),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.record_voice_over_rounded,
                          color: Colors.black,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Golden Border Speaking Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2A),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_up_rounded, color: Color(0xFFF59E0B), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'SPEAKING ALOUD NOW',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.alarm.ttsMessage.isNotEmpty
                                ? widget.alarm.ttsMessage
                                : 'Wake up! It is time for your alarm.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B2920),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'STREAM_ALARM • Full Volume Active',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom Action Buttons (Snooze & Stop)
                Column(
                  children: [
                    // Snooze Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _snoozeAlarm,
                        icon: const Icon(Icons.snooze_rounded, color: Colors.white),
                        label: Text(
                          'Snooze (${widget.alarm.snoozeDurationMinutes} mins)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF162030),
                          side: const BorderSide(color: Color(0xFF243248)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Stop Alarm Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: _stopAlarm,
                        icon: const Icon(Icons.alarm_off_rounded, color: Colors.white, size: 24),
                        label: const Text(
                          'STOP ALARM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          elevation: 6,
                          shadowColor: const Color(0xFFEF4444).withAlpha(128),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
