import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tts_alarm_model.dart';
import '../services/alarm_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';

class CreateEditAlarmScreen extends StatefulWidget {
  final TtsAlarmModel? existingAlarm;

  const CreateEditAlarmScreen({super.key, this.existingAlarm});

  @override
  State<CreateEditAlarmScreen> createState() => _CreateEditAlarmScreenState();
}

class _CreateEditAlarmScreenState extends State<CreateEditAlarmScreen>
    with SingleTickerProviderStateMixin {
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isAm;
  late TextEditingController _textController;
  late bool _isLoopOn;
  late String _selectedVoice;
  late String _selectedLanguage;
  late Set<int> _repeatDays; // 1 = Mon ... 7 = Sun
  late int _snoozeMinutes;
  late bool _isFullScreenPopUp;

  bool _isPlayingPreview = false;
  late AnimationController _waveController;
  Timer? _countdownTimer;

  final List<Map<String, String>> _availableVoices = [
    {'name': 'Aarav • Male • Hindi', 'lang': 'hi-IN'},
    {'name': 'Priya • Female • Hindi', 'lang': 'hi-IN'},
    {'name': 'Alex • Male • English', 'lang': 'en-US'},
    {'name': 'Sophia • Female • English', 'lang': 'en-US'},
  ];

  @override
  void initState() {
    super.initState();

    final alarm = widget.existingAlarm;
    if (alarm != null) {
      final hour24 = alarm.dateTime.hour;
      _isAm = hour24 < 12;
      _selectedHour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      _selectedMinute = alarm.dateTime.minute;
      _textController = TextEditingController(text: alarm.ttsMessage);
      _isLoopOn = alarm.isLoopEnabled;
      _selectedVoice = alarm.voiceName;
      _selectedLanguage = alarm.language;
      _repeatDays = alarm.repeatDays.toSet();
      _snoozeMinutes = alarm.snoozeDurationMinutes;
      _isFullScreenPopUp = alarm.fullScreenIntent;
    } else {
      _selectedHour = 6;
      _selectedMinute = 30;
      _isAm = true;
      _textController = TextEditingController(
        text: 'Wake up, Gym time! Protein shake is on the table.',
      );
      _isLoopOn = true;
      _selectedVoice = 'Aarav • Male • Hindi';
      _selectedLanguage = 'hi-IN';
      _repeatDays = {1, 2, 3, 4, 5};
      _snoozeMinutes = 5;
      _isFullScreenPopUp = true;
    }

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _countdownTimer?.cancel();
    _textController.dispose();
    TtsService().stop();
    super.dispose();
  }

  DateTime _getTargetDateTime() {
    final now = DateTime.now();
    int hour24 = _selectedHour;
    if (_isAm) {
      if (hour24 == 12) hour24 = 0;
    } else {
      if (hour24 != 12) hour24 += 12;
    }

    var target = DateTime(now.year, now.month, now.day, hour24, _selectedMinute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  String _calculateTimeRemaining() {
    final target = _getTargetDateTime();
    final diff = target.difference(DateTime.now());
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return 'Rings in ${hours}h ${mins}m';
  }

  String _getSubtitle() {
    final target = _getTargetDateTime();
    final now = DateTime.now();
    if (target.day == now.day) {
      return 'Tonight';
    } else {
      return 'Tomorrow';
    }
  }

  void _adjustMinutes(int delta) {
    setState(() {
      int totalMinutes = (_selectedHour % 12) * 60 + _selectedMinute;
      if (!_isAm) totalMinutes += 12 * 60;

      totalMinutes += delta;
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      totalMinutes %= 24 * 60;

      final newHour24 = totalMinutes ~/ 60;
      _selectedMinute = totalMinutes % 60;

      _isAm = newHour24 < 12;
      _selectedHour = newHour24 == 0 ? 12 : (newHour24 > 12 ? newHour24 - 12 : newHour24);
    });
  }

  Future<void> _togglePreviewVoice() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_isPlayingPreview) {
      await TtsService().stop();
      setState(() => _isPlayingPreview = false);
    } else {
      setState(() => _isPlayingPreview = true);
      await TtsService().previewSpeech(
        text: text,
        language: _selectedLanguage,
      );
      setState(() => _isPlayingPreview = false);
    }
  }

  void _openVoicePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select TTS Voice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._availableVoices.map((voice) {
                final isSelected = _selectedVoice == voice['name'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF59E0B).withAlpha(35) : const Color(0xFF1A2333),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF26334D),
                      child: Icon(
                        Icons.record_voice_over_rounded,
                        color: isSelected ? Colors.black : Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      voice['name']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Language: ${voice['lang']}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedVoice = voice['name']!;
                        _selectedLanguage = voice['lang']!;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAlarm() async {
    final target = _getTargetDateTime();
    final id = widget.existingAlarm?.id ?? (DateTime.now().millisecondsSinceEpoch % 100000);
    final text = _textController.text.trim();

    final alarmModel = TtsAlarmModel(
      id: id,
      dateTime: target,
      ttsMessage: text.isNotEmpty ? text : 'Wake up! It is time for your alarm.',
      label: 'Voice Alarm',
      isEnabled: true,
      language: _selectedLanguage,
      repeatDays: _repeatDays.toList(),
      isLoopEnabled: _isLoopOn,
      voiceName: _selectedVoice,
      fullScreenIntent: _isFullScreenPopUp,
      snoozeDurationMinutes: _snoozeMinutes,
    );

    await AlarmService().scheduleAlarm(alarmModel);
    await StorageService.upsertAlarm(alarmModel);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted =
        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} ${_isAm ? 'AM' : 'PM'}';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Deep Midnight Obsidian
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Card 1: Time Picker Card
                    _buildTimePickerCard(),
                    const SizedBox(height: 16),

                    // Card 2: "Alarm will speak" Card (Gold Border)
                    _buildAlarmWillSpeakCard(),
                    const SizedBox(height: 16),

                    // Card 3: Voice & Settings Card
                    _buildSettingsCard(),
                    const SizedBox(height: 16),

                    // Card 4: Guarantee / Doze Banner
                    _buildGuaranteeBanner(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Save Button & Footer
            _buildBottomBar(timeFormatted),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141C2B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF222E42)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              // Title & Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSubtitle(),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Voice Alarm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Exact alarm ON Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF062A20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(100)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
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

  Widget _buildTimePickerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF202C3F)),
      ),
      child: Column(
        children: [
          // Top Row: Rings in Xh Ym & Doze-proof badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _calculateTimeRemaining(),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2436),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: Color(0xFFF59E0B), size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Doze-proof',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Digits row: [06] : [30]  [AM/PM]
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hour Box
              _buildDigitBox(
                value: _selectedHour.toString().padLeft(2, '0'),
                label: 'Hour',
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: _isAm ? (_selectedHour == 12 ? 0 : _selectedHour) : (_selectedHour == 12 ? 12 : _selectedHour + 12),
                      minute: _selectedMinute,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _isAm = picked.period == DayPeriod.am;
                      _selectedHour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
                      _selectedMinute = picked.minute;
                    });
                  }
                },
              ),
              const SizedBox(width: 12),

              // Colon
              const Text(
                ':',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),

              // Minute Box
              _buildDigitBox(
                value: _selectedMinute.toString().padLeft(2, '0'),
                label: 'Minute',
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: _isAm ? (_selectedHour == 12 ? 0 : _selectedHour) : (_selectedHour == 12 ? 12 : _selectedHour + 12),
                      minute: _selectedMinute,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _isAm = picked.period == DayPeriod.am;
                      _selectedHour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
                      _selectedMinute = picked.minute;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),

              // AM / PM Column
              Column(
                children: [
                  _buildAmPmButton('AM', _isAm),
                  const SizedBox(height: 8),
                  _buildAmPmButton('PM', !_isAm),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick adjust buttons row: [-15 min] [-5 min] [+5 min] [+15 min]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickAdjustChip('-15 min', -15, isHighlighted: false),
              _buildQuickAdjustChip('-5 min', -5, isHighlighted: false),
              _buildQuickAdjustChip('+5 min', 5, isHighlighted: true),
              _buildQuickAdjustChip('+15 min', 15, isHighlighted: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox({
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 88,
        height: 94,
        decoration: BoxDecoration(
          color: const Color(0xFF162030),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF243248)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmPmButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _isAm = label == 'AM';
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 60,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF162030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF243248),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAdjustChip(String label, int delta, {required bool isHighlighted}) {
    return InkWell(
      onTap: () => _adjustMinutes(delta),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFF162030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFF243248),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isHighlighted ? Colors.black : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmWillSpeakCard() {
    final charCount = _textController.text.length;
    final estimatedSeconds = ((charCount * 0.18) + 2).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5), // Prominent Gold Border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: [Audio Icon] Alarm will speak   [Loop ON badge]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Alarm will speak',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() => _isLoopOn = !_isLoopOn);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isLoopOn ? const Color(0xFF0B2920) : const Color(0xFF1F293D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isLoopOn ? const Color(0xFF10B981).withAlpha(120) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: _isLoopOn ? const Color(0xFF10B981) : Colors.white54,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isLoopOn ? 'Loop ON' : 'Loop OFF',
                        style: TextStyle(
                          color: _isLoopOn ? const Color(0xFF34D399) : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Text Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1522),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1E2A3E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Enter text for alarm to speak...',
                    hintStyle: TextStyle(color: Colors.white30),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Audio waveform visualizer bars
                Row(
                  children: List.generate(16, (i) {
                    final heights = [10, 16, 24, 20, 26, 18, 28, 22, 14, 20, 16, 22, 12, 18, 14, 10];
                    final isGold = i < 6;
                    final h = _isPlayingPreview
                        ? (heights[i] * (_waveController.value * 0.4 + 0.8)).clamp(8.0, 30.0)
                        : heights[i].toDouble();

                    return Expanded(
                      child: Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isGold ? const Color(0xFFF59E0B) : const Color(0xFF223046),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),

                // Sub info: characters & loop duration
                Text(
                  '$charCount characters • ~$estimatedSeconds sec per loop Hindi + English',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action row: [▶ Test voice]  [Mic]  [Translate]
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _togglePreviewVoice,
                    icon: Icon(
                      _isPlayingPreview ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                    label: Text(
                      _isPlayingPreview ? 'Stop voice' : 'Test voice',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Mic Button
              _buildIconButton(
                icon: Icons.mic_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Speech input feature ready! You can type any sentence.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),

              // Language Translate Button
              _buildIconButton(
                icon: Icons.translate_rounded,
                onTap: _openVoicePicker,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF162030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF243248)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildSettingsCard() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF202C3F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice Row Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Voice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: _openVoicePicker,
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected Voice Card
          InkWell(
            onTap: _openVoicePicker,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1522),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2A3E)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedVoice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'STREAM_ALARM • Full volume',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Repeat Row Header
          const Text(
            'Repeat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Days chips: [M] [T] [W] [T] [F] [S] [S]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNum = index + 1; // 1 = Mon ... 7 = Sun
              final isSelected = _repeatDays.contains(dayNum);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _repeatDays.remove(dayNum);
                    } else {
                      _repeatDays.add(dayNum);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF162030),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF243248),
                    ),
                  ),
                  child: Text(
                    days[index],
                    style: TextStyle(
                      color: isSelected ? Colors.black : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Snooze selector row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Snooze',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF162030),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF243248)),
                ),
                child: Row(
                  children: [
                    _buildSnoozeSegment(5),
                    _buildSnoozeSegment(10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Full-screen pop-up switch row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Full-screen pop-up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isFullScreenPopUp,
                activeThumbColor: const Color(0xFFF59E0B),
                activeTrackColor: const Color(0xFFF59E0B).withAlpha(100),
                onChanged: (val) {
                  setState(() => _isFullScreenPopUp = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnoozeSegment(int mins) {
    final isSelected = _snoozeMinutes == mins;
    return InkWell(
      onTap: () => setState(() => _snoozeMinutes = mins),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF223048) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$mins min',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGuaranteeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101927),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2D44)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Wakes from Doze via setAlarmClock. Stays loud on STREAM_ALARM even in silent mode.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(String timeFormatted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        border: Border(top: BorderSide(color: Color(0xFF1A2333))),
      ),
      child: Column(
        children: [
          // Save Voice Alarm button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saveAlarm,
              icon: const Icon(Icons.notifications_active_rounded, color: Colors.black, size: 22),
              label: Text(
                'Save voice alarm • $timeFormatted',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B), // Warm Gold
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 4,
                shadowColor: const Color(0xFFF59E0B).withAlpha(100),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Footer guarantee text
          const Text(
            'Saved locally • No ringtone needed • Works offline',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
