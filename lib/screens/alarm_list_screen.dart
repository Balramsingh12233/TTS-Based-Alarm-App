import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tts_alarm_model.dart';
import '../services/alarm_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import 'create_edit_alarm_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  List<TtsAlarmModel> _alarms = [];
  bool _isLoading = true;
  int? _previewingAlarmId;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await PermissionService.requestAlarmPermissions();
    await _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    final list = await StorageService.loadAlarms();
    // Sort alarms by next occurrence time
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (mounted) {
      setState(() {
        _alarms = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAlarm(TtsAlarmModel alarm, bool value) async {
    final updated = alarm.copyWith(isEnabled: value);
    if (value) {
      var targetTime = updated.dateTime;
      if (targetTime.isBefore(DateTime.now())) {
        targetTime = targetTime.add(const Duration(days: 1));
      }
      final toSchedule = updated.copyWith(dateTime: targetTime);
      await AlarmService().scheduleAlarm(toSchedule);
      await StorageService.upsertAlarm(toSchedule);
    } else {
      await AlarmService().stopAlarm(alarm.id);
      await StorageService.upsertAlarm(updated);
    }
    await _loadAlarms();
  }

  Future<void> _deleteAlarm(int id) async {
    await AlarmService().stopAlarm(id);
    await StorageService.deleteAlarm(id);
    await _loadAlarms();
  }

  Future<void> _openCreateScreen({TtsAlarmModel? alarm}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEditAlarmScreen(existingAlarm: alarm),
      ),
    );
    if (result == true) {
      await _loadAlarms();
    }
  }

  Future<void> _previewAlarmVoice(TtsAlarmModel alarm) async {
    if (_previewingAlarmId == alarm.id) {
      await TtsService().stop();
      setState(() => _previewingAlarmId = null);
      return;
    }

    setState(() => _previewingAlarmId = alarm.id);
    await TtsService().previewSpeech(
      text: alarm.ttsMessage,
      rate: alarm.speechRate,
      pitch: alarm.pitch,
      language: alarm.language,
    );
    if (mounted) {
      setState(() => _previewingAlarmId = null);
    }
  }

  String _formatRepeatDays(List<int> days) {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Weekdays (Mon-Fri)';
    }
    const dayNames = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};
    return days.map((d) => dayNames[d] ?? '').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Midnight Obsidian
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                    )
                  : _alarms.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _alarms.length,
                          itemBuilder: (context, index) {
                            return _buildAlarmCard(_alarms[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateScreen(),
        backgroundColor: const Color(0xFFF59E0B),
        elevation: 4,
        icon: const Icon(Icons.add_alarm_rounded, color: Colors.black, size: 24),
        label: const Text(
          'New Voice Alarm',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMART OFFLINE ALARMS',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Voice Alarms',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Exact alarm ON pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF062A20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(100)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF10B981),
                ),
                SizedBox(width: 6),
                Text(
                  'Exact alarm ON',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(TtsAlarmModel alarm) {
    final timeFormatted = DateFormat('hh:mm').format(alarm.dateTime);
    final amPm = DateFormat('a').format(alarm.dateTime);
    final isPreviewing = _previewingAlarmId == alarm.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: alarm.isEnabled ? const Color(0xFF243248) : const Color(0xFF1B2436),
        ),
      ),
      child: InkWell(
        onTap: () => _openCreateScreen(alarm: alarm),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Time & Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeFormatted,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: alarm.isEnabled ? Colors.white : Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amPm,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: alarm.isEnabled ? const Color(0xFFF59E0B) : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: alarm.isEnabled,
                    activeThumbColor: const Color(0xFFF59E0B),
                    activeTrackColor: const Color(0xFFF59E0B).withAlpha(100),
                    onChanged: (val) => _toggleAlarm(alarm, val),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Speech Message Quote Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1522),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: alarm.isEnabled
                        ? const Color(0xFFF59E0B).withAlpha(60)
                        : const Color(0xFF1E2A3E),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alarm.ttsMessage.isNotEmpty
                            ? '"${alarm.ttsMessage}"'
                            : '"Wake up! It is time."',
                        style: TextStyle(
                          color: alarm.isEnabled ? Colors.white : Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Details Row: Voice, Repeat, Preview & Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Voice & Repeat Details
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C273C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alarm.voiceName.split('•').first.trim(),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C273C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatRepeatDays(alarm.repeatDays),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions: Test Voice & Delete
                  Row(
                    children: [
                      IconButton(
                        tooltip: isPreviewing ? 'Stop' : 'Test voice',
                        icon: Icon(
                          isPreviewing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 26,
                        ),
                        onPressed: () => _previewAlarmVoice(alarm),
                      ),
                      IconButton(
                        tooltip: 'Delete alarm',
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 22),
                        onPressed: () => _deleteAlarm(alarm.id),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF131B2A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B).withAlpha(100), width: 1.5),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                size: 48,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Voice Alarms Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create your first alarm with custom text. It will speak your exact words aloud when ringing!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _openCreateScreen(),
              icon: const Icon(Icons.add_alarm_rounded, color: Colors.black),
              label: const Text(
                'Create First Voice Alarm',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
