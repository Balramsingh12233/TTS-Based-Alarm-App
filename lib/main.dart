import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/tts_alarm_model.dart';
import 'services/alarm_service.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';
import 'screens/alarm_ring_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize TTS Engine & Alarm Service
  await TtsService().init();
  await AlarmService().init(onTriggered: (alarm) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmRingScreen(alarm: alarm),
      ),
    );
  });

  runApp(const TtsAlarmApp());
}

class TtsAlarmApp extends StatelessWidget {
  const TtsAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TTS Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const AlarmListScreen(),
    );
  }
}

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  List<TtsAlarmModel> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await PermissionService.requestAlarmPermissions();
    await _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    final list = await StorageService.loadAlarms();
    setState(() {
      _alarms = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleAlarm(TtsAlarmModel alarm, bool value) async {
    final updated = alarm.copyWith(isEnabled: value);
    if (value) {
      // If time has passed today, schedule for tomorrow
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

  void _openAddAlarmDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddAlarmSheet(
        onAlarmSaved: () => _loadAlarms(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.mic_rounded, color: Color(0xFF38BDF8), size: 28),
            SizedBox(width: 10),
            Text(
              'TTS Voice Alarms',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = _alarms[index];
                    final timeFormatted = DateFormat('hh:mm a').format(alarm.dateTime);

                    return Card(
                      color: const Color(0xFF131C2E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: alarm.isEnabled
                              ? const Color(0xFF38BDF8).withAlpha(80)
                              : Colors.white.withAlpha(15),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  timeFormatted,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: alarm.isEnabled ? Colors.white : Colors.white38,
                                  ),
                                ),
                                Switch(
                                  value: alarm.isEnabled,
                                  activeTrackColor: const Color(0xFF38BDF8),
                                  onChanged: (val) => _toggleAlarm(alarm, val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.record_voice_over_outlined,
                                    size: 16, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    alarm.ttsMessage.isNotEmpty
                                        ? '"${alarm.ttsMessage}"'
                                        : 'No custom text',
                                    style: TextStyle(
                                      color: alarm.isEnabled ? Colors.white70 : Colors.white30,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    TtsService().previewSpeech(
                                      text: alarm.ttsMessage,
                                      rate: alarm.speechRate,
                                      pitch: alarm.pitch,
                                    );
                                  },
                                  icon: const Icon(Icons.volume_up, size: 18),
                                  label: const Text('Test Voice'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF38BDF8),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteAlarm(alarm.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAlarmDialog,
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.add_alarm, color: Colors.black),
        label: const Text(
          'New TTS Alarm',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alarm_add_rounded, size: 72, color: Colors.white.withAlpha(50)),
          const SizedBox(height: 16),
          const Text(
            'No TTS Alarms Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add an alarm and write any sentence. It will speak aloud exact words at that time!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAlarmSheet extends StatefulWidget {
  final VoidCallback onAlarmSaved;

  const _AddAlarmSheet({required this.onAlarmSaved});

  @override
  State<_AddAlarmSheet> createState() => _AddAlarmSheetState();
}

class _AddAlarmSheetState extends State<_AddAlarmSheet> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _textController = TextEditingController(
    text: 'Wake up! Today is an amazing day.',
  );
  final TextEditingController _labelController = TextEditingController(text: 'Morning Alarm');

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveAlarm() async {
    final now = DateTime.now();
    var alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // If time is before now, schedule for tomorrow
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    final alarm = TtsAlarmModel(
      id: id,
      dateTime: alarmDateTime,
      ttsMessage: _textController.text.trim(),
      label: _labelController.text.trim(),
    );

    await AlarmService().scheduleAlarm(alarm);
    await StorageService.upsertAlarm(alarm);
    widget.onAlarmSaved();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create TTS Alarm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Time picker card
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Alarm Time', style: TextStyle(fontSize: 16)),
                  Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Label input
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Alarm Label',
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          // TTS custom text input
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Custom Text To Speak Aloud',
              hintText: 'e.g. Utho bhai, running par chalte hain!',
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Set Alarm', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
