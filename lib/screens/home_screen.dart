import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../models/song.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_card.dart';
import '../widgets/app_widgets.dart';
import 'edit_alarm_screen.dart';
import 'settings_screen.dart';

/// The Home screen: the list of alarms with an add button.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openNew(BuildContext context) {
    // Defaults for a brand-new alarm (id 0 means "not saved yet").
    final first = kSongCatalog.first;
    final draft = Alarm(
      id: 0,
      hour: 7,
      minute: 0,
      soundMode: SoundMode.specific,
      songName: first.name,
      start: 0,
      end: first.duration,
      volume: 70,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditAlarmScreen(draft: draft, isNew: true),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openEdit(BuildContext context, Alarm alarm) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Edit a *copy* so Cancel discards changes.
        builder: (_) => EditAlarmScreen(draft: alarm.clone(), isNew: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openSettings(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Tooltip(
                      message: 'Settings',
                      child: Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Alarms',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openNew(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.onAccent,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !app.loaded
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : app.alarms.isEmpty
                  ? _buildEmpty(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: app.alarms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final a = app.alarms[i];
                        return AlarmCard(
                          alarm: a,
                          soundSummary: app.soundSummary(a),
                          onOpen: () => _openEdit(context, a),
                          onToggle: () => app.toggleAlarm(a.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyState(
      icon: Icons.alarm_add_outlined,
      title: 'No alarms yet',
      subtitle: 'Tap Add to create your first alarm.',
      actionLabel: '+ Add alarm',
      onAction: () => _openNew(context),
    );
  }
}
