import 'package:flutter_test/flutter_test.dart';
import 'package:midistems/ui/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MidiStemsApp());
    expect(find.text('MidiStems'), findsOneWidget);
  });
}
