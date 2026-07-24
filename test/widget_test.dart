// Basic smoke test: the app builds and the Home screen renders.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firstnode/main.dart';
import 'package:firstnode/services/storage.dart';
import 'package:firstnode/state/app_state.dart';

void main() {
  testWidgets('Home screen shows the Alarms title', (tester) async {
    // Give shared_preferences an in-memory backing store for the test.
    SharedPreferences.setMockInitialValues({});

    final appState = AppState(Storage());
    await appState.init(); // seeds sample data on first run

    await tester.pumpWidget(FirstNodeApp(appState: appState));
    await tester.pump();

    expect(find.text('Alarms'), findsOneWidget);
    // One of the three seeded sample alarms should be visible.
    expect(find.text('Wake up · M T W T F'), findsOneWidget);
  });
}
