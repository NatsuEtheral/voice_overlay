import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_voice_notes/main.dart';

void main() {
  testWidgets('App renders HomeView with title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoiceNotesApp()));
    await tester.pumpAndSettle();

    expect(find.text('VoiceNotes'), findsOneWidget);
  });
}
