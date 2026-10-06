import 'package:flutter_test/flutter_test.dart';
import 'package:tts_alarm/main.dart';

void main() {
  testWidgets('TTS Alarm App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TtsAlarmApp());
    expect(find.text('TTS Alarm'), findsWidgets);
  });
}
