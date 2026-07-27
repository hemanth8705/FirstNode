// Pool editor: drag-and-drop reordering and the frozen-songs picker.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firstnode/models/pool.dart';
import 'package:firstnode/screens/pool_editor_screen.dart';
import 'package:firstnode/services/storage.dart';
import 'package:firstnode/state/app_state.dart';
import 'package:firstnode/theme/app_theme.dart';

Pool threeSongPool({PoolOrder order = PoolOrder.shuffle, int frozenCount = 0}) =>
    Pool(
      id: 'p1',
      name: 'Test pool',
      order: order,
      frozenCount: frozenCount,
      songs: [
        PoolSong(name: 'Alpha', end: 10),
        PoolSong(name: 'Bravo', end: 10),
        PoolSong(name: 'Charlie', end: 10),
      ],
    );

List<String> names(Pool pool) => pool.songs.map((s) => s.name).toList();

Future<void> pumpEditor(WidgetTester tester, Pool pool) async {
  SharedPreferences.setMockInitialValues({});
  final appState = AppState(Storage());
  await appState.init();

  // Tall enough that the whole form and every song card are laid out — a sliver
  // list doesn't build children that are off-screen, so they'd be unfindable.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: PoolEditorScreen(pool: pool, isNew: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Drags the song at [from] onto the slot [to] currently occupies.
///
/// Distances come from where the drag handles actually are rather than an
/// assumed row height, so this still works when one card is expanded and much
/// taller than its neighbours. The movement is broken into small steps on
/// purpose: a reorderable list recalculates the drop slot on each pointer move
/// against geometry that is mid-animation, so teleporting the pointer in one
/// jump lands in edge cases a real finger never produces.
Future<void> dragSong(WidgetTester tester, int from, int to) async {
  final handles = find.byIcon(Icons.drag_indicator);
  final start = tester.getCenter(handles.at(from));
  final travel = tester.getCenter(handles.at(to)).dy - start.dy;

  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 20; i++) {
    await gesture.moveBy(Offset(0, travel / 20));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dragging a song down one place reorders it', (tester) async {
    final pool = threeSongPool();
    await pumpEditor(tester, pool);

    await dragSong(tester, 0, 1);

    expect(names(pool), ['Bravo', 'Alpha', 'Charlie']);
  });

  testWidgets('dragging a song down to the end reorders it', (tester) async {
    final pool = threeSongPool();
    await pumpEditor(tester, pool);

    await dragSong(tester, 0, 2);

    expect(names(pool), ['Bravo', 'Charlie', 'Alpha']);
  });

  testWidgets('dragging a song to the top makes it the first song', (
    tester,
  ) async {
    final pool = threeSongPool();
    await pumpEditor(tester, pool);

    await dragSong(tester, 2, 0);

    expect(names(pool), ['Charlie', 'Alpha', 'Bravo']);
  });

  testWidgets('a reorder is what the frozen songs then follow', (tester) async {
    final pool = threeSongPool(frozenCount: 1);
    await pumpEditor(tester, pool);

    await dragSong(tester, 2, 0); // make Charlie the favourite opener

    expect(names(pool), ['Charlie', 'Alpha', 'Bravo']);
    expect(resolvePlayOrder(pool).first.name, 'Charlie');
  });

  testWidgets('choosing First 1 freezes the top song and marks it', (
    tester,
  ) async {
    final pool = threeSongPool();
    await pumpEditor(tester, pool);

    expect(find.textContaining('frozen'), findsNothing);

    await tester.tap(find.text('First 1'));
    await tester.pumpAndSettle();

    expect(pool.frozenCount, 1);
    expect(find.textContaining('frozen'), findsOneWidget);
  });

  testWidgets('frozen songs are offered only for Shuffle order', (
    tester,
  ) async {
    await pumpEditor(tester, threeSongPool(order: PoolOrder.linear));

    expect(find.text('FROZEN SONGS'), findsNothing);

    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();

    expect(find.text('FROZEN SONGS'), findsOneWidget);
    // None plus one option per song, capped at kMaxFrozenSongs.
    expect(find.text('First 3'), findsOneWidget);
    expect(find.text('First 4'), findsNothing);
  });

  testWidgets('removing songs pulls an out-of-range frozen count back in', (
    tester,
  ) async {
    final pool = threeSongPool(frozenCount: 3);
    await pumpEditor(tester, pool);

    await tester.tap(find.byIcon(Icons.close).last); // remove Charlie
    await tester.pumpAndSettle();

    expect(names(pool), ['Alpha', 'Bravo']);
    expect(pool.frozenCount, 2);
    expect(find.text('First 3'), findsNothing);
  });

  testWidgets('expanded sliders stay with their song across a reorder', (
    tester,
  ) async {
    final pool = threeSongPool();
    await pumpEditor(tester, pool);

    await tester.tap(find.text('Alpha')); // open Alpha's trim/volume sliders
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(3));

    await dragSong(tester, 1, 0); // lift Bravo above the expanded Alpha

    // Still Alpha's card that is open, not whatever is now in first place.
    expect(names(pool), ['Bravo', 'Alpha', 'Charlie']);
    expect(find.byType(Slider), findsNWidgets(3));
    final alphaY = tester.getCenter(find.text('Alpha')).dy;
    final bravoY = tester.getCenter(find.text('Bravo')).dy;
    expect(bravoY, lessThan(alphaY));
    expect(tester.getCenter(find.byType(Slider).first).dy, greaterThan(alphaY));
  });
}
