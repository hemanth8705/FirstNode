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
import 'services/post_alarm_reminder.dart';
import 'services/puzzle_engine.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Lets the alarm ring handler navigate from outside the widget tree (e.g. when
/// the app is launched by a firing alarm).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Lets us show a snack bar from outside the widget tree — used to confirm a
/// post-alarm reminder was acknowledged, which can happen on a cold start.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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

class _FirstNodeAppState extends State<FirstNodeApp>
    with WidgetsBindingObserver {
  StreamSubscription<AlarmSet>? _ringSub;
  bool _handlingRing = false;

  /// Alarm ids ringing as of the last stream event, so we can spot the moment
  /// one *stops* — which is when a post-alarm reminder chain begins. Watching
  /// the transition (rather than only the in-app Dismiss button) means the
  /// reminder also starts when the alarm is stopped from its notification.
  Set<int> _ringingIds = {};

  final PostAlarmReminderService _reminders = PostAlarmReminderService();

  @override
  void initState() {
    super.initState();
    if (widget.scheduler != null) {
      WidgetsBinding.instance.addObserver(this);
      _ringSub = Alarm.ringing.listen(_onRingingChanged);
      _bootstrap();
    }
  }

  /// After data loads: request permissions, keep the OS schedule in sync with
  /// our alarm list, and schedule everything once.
  Future<void> _bootstrap() async {
    await widget.appState.ready;
    widget.appState.onAlarmsChanged = () {
      widget.scheduler!.syncAll(
        widget.appState.alarms,
        widget.appState.pools,
        widget.appState.allSongs,
      );
      _syncRemindersWithAlarms();
    };
    await AlarmPermissions.ensure();
    await widget.scheduler!.syncAll(
      widget.appState.alarms,
      widget.appState.pools,
      widget.appState.allSongs,
    );
    // Covers a cold start caused by tapping a reminder notification, where no
    // lifecycle change ever fires because the app starts up already resumed.
    await _checkReminderAcknowledged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tapping a reminder notification brings the app forward; that's where the
    // native side left the acknowledgement for us.
    if (state == AppLifecycleState.resumed) _checkReminderAcknowledged();
  }

  // ------------------------------------------------------------- Ringing ----

  /// Every change to the set of ringing alarms: an alarm that has just started
  /// ringing gets the ring/puzzle screen, and one that has just stopped starts
  /// its post-alarm reminder chain.
  void _onRingingChanged(AlarmSet alarmSet) {
    final ids = alarmSet.alarms.map((a) => a.id).toSet();
    final stopped = _ringingIds.difference(ids);
    _ringingIds = ids;

    for (final id in stopped) {
      _onAlarmStopped(id);
    }
    if (ids.isNotEmpty) _onRing(alarmSet);
  }

  /// A real alarm is ringing: find our alarm, show the ring/puzzle screen, and
  /// stop + reschedule it when the user dismisses/solves.
  Future<void> _onRing(AlarmSet alarmSet) async {
    if (_handlingRing || alarmSet.alarms.isEmpty) return;
    _handlingRing = true;

    // A fresh alarm supersedes any reminder chain still running from an earlier
    // one — it would otherwise nudge over the top of the alarm.
    await _reminders.cancel();

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
    // The native alarm engine can only loop one fixed audio file — it has no
    // way to cycle through a pool's songs. For "Pools" mode it plays true
    // silence natively (see AlarmScheduler.kSilentPlaceholderAsset) and Dart
    // drives the actual sequenced playback here instead; every other mode
    // keeps relying on the native side's already-playing loop.
    final needsDartPlayback = alarm.soundMode == model.SoundMode.pool;
    await nav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => queue.isEmpty
            ? RingingScreen(
                alarm: alarm,
                playInApp: needsDartPlayback,
                onStop: () => _dismissReal(alarm),
              )
            : PuzzleSolveScreen(
                alarm: alarm,
                queue: queue,
                playInApp: needsDartPlayback,
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

  // ------------------------------------------------- Post-alarm reminders ----

  /// An alarm stopped ringing (dismissed in-app, or stopped from its
  /// notification): hand off to the native reminder chain if this alarm asks
  /// for one. From here on the nudges are Android's job, so they keep coming
  /// even if this process goes away.
  Future<void> _onAlarmStopped(int alarmId) async {
    await widget.appState.ready;
    for (final a in widget.appState.alarms) {
      if (a.id == alarmId) {
        if (a.reminder.enabled) {
          await _reminders.start(
            a,
            widget.appState.pools,
            widget.appState.allSongs,
          );
        }
        return;
      }
    }
  }

  /// Stop a running chain whose alarm was deleted, or had its reminder switched
  /// off, while it was still nudging.
  Future<void> _syncRemindersWithAlarms() async {
    final activeId = await _reminders.activeAlarmId();
    if (activeId == null) return;
    for (final a in widget.appState.alarms) {
      if (a.id == activeId) {
        if (!a.reminder.enabled) await _reminders.cancel();
        return;
      }
    }
    await _reminders.cancel(); // alarm deleted
  }

  Future<void> _checkReminderAcknowledged() async {
    if (widget.scheduler == null) return;
    final alarmId = await _reminders.consumeAcknowledgement();
    if (alarmId == null) return;
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Good morning — reminders stopped."),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: 'FirstNode',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
