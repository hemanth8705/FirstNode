import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/alarm.dart' as model;
import 'screens/home_screen.dart';
import 'screens/puzzle_solve_screen.dart';
import 'screens/ringing_screen.dart';
import 'services/alarm_scheduler.dart';
import 'services/audio_service.dart';
import 'services/permissions.dart';
import 'services/puzzle_engine.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Lets the alarm ring handler navigate from outside the widget tree (e.g. when
/// the app is launched by a firing alarm).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the native alarm engine before anything schedules alarms.
  final scheduler = AlarmScheduler();
  await scheduler.init();

  // Create the store and kick off loading (Home shows a spinner until loaded).
  final appState = AppState(Storage())..init();

  runApp(FirstNodeApp(appState: appState, scheduler: scheduler));
}

class FirstNodeApp extends StatefulWidget {
  final AppState appState;

  /// The alarm engine. Null in widget tests (no native platform), which disables
  /// scheduling + the ring listener so tests don't touch platform channels.
  final AlarmScheduler? scheduler;

  const FirstNodeApp({required this.appState, this.scheduler, super.key});

  @override
  State<FirstNodeApp> createState() => _FirstNodeAppState();
}

class _FirstNodeAppState extends State<FirstNodeApp> {
  StreamSubscription<AlarmSet>? _ringSub;
  bool _handlingRing = false;

  @override
  void initState() {
    super.initState();
    if (widget.scheduler != null) {
      _ringSub = Alarm.ringing.listen(_onRing);
      _bootstrap();
    }
  }

  /// After data loads: request permissions, keep the OS schedule in sync with
  /// our alarm list, and schedule everything once.
  Future<void> _bootstrap() async {
    await widget.appState.ready;
    widget.appState.onAlarmsChanged = () => widget.scheduler!.syncAll(
      widget.appState.alarms,
      widget.appState.pools,
      widget.appState.allSongs,
    );
    await AlarmPermissions.ensure();
    await widget.scheduler!.syncAll(
      widget.appState.alarms,
      widget.appState.pools,
      widget.appState.allSongs,
    );
  }

  @override
  void dispose() {
    _ringSub?.cancel();
    super.dispose();
  }

  /// A real alarm is ringing: find our alarm, show the ring/puzzle screen, and
  /// stop + reschedule it when the user dismisses/solves.
  Future<void> _onRing(AlarmSet alarmSet) async {
    if (_handlingRing || alarmSet.alarms.isEmpty) return;
    _handlingRing = true;

    await widget.appState.ready;
    final ringingId = alarmSet.alarms.first.id;

    model.Alarm? found;
    for (final a in widget.appState.alarms) {
      if (a.id == ringingId) {
        found = a;
        break;
      }
    }
    if (found == null) {
      await Alarm.stop(ringingId); // unknown alarm — just silence it
      _handlingRing = false;
      return;
    }

    final alarm = found;
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _handlingRing = false;
      return;
    }

    final queue = PuzzleEngine().resolveQueue(alarm);
    await nav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => queue.isEmpty
            ? RingingScreen(
                alarm: alarm,
                playInApp: false,
                onStop: () => _dismissReal(alarm),
              )
            : PuzzleSolveScreen(
                alarm: alarm,
                queue: queue,
                playInApp: false,
                blockBack: true,
                onStop: () => _dismissReal(alarm),
              ),
      ),
    );
    _handlingRing = false;
  }

  Future<void> _dismissReal(model.Alarm alarm) async {
    await Alarm.stop(alarm.id);
    if (alarm.days.isEmpty) {
      // A one-off alarm turns itself off after ringing.
      await widget.appState.setEnabled(alarm.id, false);
    } else {
      // A repeating alarm schedules its next occurrence.
      await widget.scheduler!.scheduleOne(
        alarm,
        widget.appState.pools,
        widget.appState.allSongs,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: widget.appState),
        Provider<AudioService>(
          create: (_) => AudioService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'FirstNode',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
