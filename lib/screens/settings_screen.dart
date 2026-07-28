import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'library_screen.dart';
import 'pool_picker_screen.dart';

/// The app's central management/preferences page: Library, Pools, and General
/// sections, reachable from the gear icon on Home. Designed so a future
/// setting is just one more row, not a new navigation pattern.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openLibrary(BuildContext context, {bool autoImport = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryScreen(autoImport: autoImport),
      ),
    );
  }

  void _openPools(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PoolPickerScreen(selectable: false)),
    );
  }

  Future<void> _showStorageInfo(BuildContext context) async {
    final app = context.read<AppState>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Storage',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: FutureBuilder<int>(
          future: _importedBytes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }
            final mb = snapshot.data! / (1024 * 1024);
            return Text(
              '${app.customSongs.length} imported song'
              '${app.customSongs.length == 1 ? '' : 's'} using '
              '${mb < 0.1 ? '<0.1' : mb.toStringAsFixed(1)} MB.',
              style: TextStyle(color: AppColors.w(0.6), fontSize: 14),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<int> _importedBytes() async {
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'imported_sounds'),
    );
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'About',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '${info.appName}\nVersion ${info.version} (${info.buildNumber})',
          style: TextStyle(color: AppColors.w(0.6), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  const SectionLabel('LIBRARY'),
                  const SizedBox(height: 10),
                  _section([
                    _row(
                      icon: Icons.library_music_outlined,
                      label: 'Manage Music Library',
                      onTap: () => _openLibrary(context),
                    ),
                    _row(
                      icon: Icons.add_circle_outline,
                      label: 'Import Songs',
                      onTap: () => _openLibrary(context, autoImport: true),
                    ),
                    _row(
                      icon: Icons.storage_outlined,
                      label: 'Storage Information',
                      onTap: () => _showStorageInfo(context),
                      last: true,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  const SectionLabel('POOLS'),
                  const SizedBox(height: 10),
                  _section([
                    _row(
                      icon: Icons.queue_music_outlined,
                      label: 'Manage Pools',
                      onTap: () => _openPools(context),
                    ),
                    _row(
                      icon: Icons.playlist_add,
                      label: 'Create Pool',
                      onTap: () => openNewPool(context),
                      last: true,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  const SectionLabel('GENERAL'),
                  const SizedBox(height: 10),
                  _section([
                    _row(
                      icon: Icons.notifications_none,
                      label: 'Notification Settings',
                      onTap: () => openAppSettings(),
                    ),
                    _row(
                      icon: Icons.info_outline,
                      label: 'About',
                      onTap: () => _showAbout(context),
                      last: true,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    'More settings coming soon.',
                    style: TextStyle(color: AppColors.w(0.3), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: AppColors.cardBorder,
      ),
      child: Column(children: rows),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool last = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AppColors.w(0.06))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.w(0.6)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.w(0.3)),
          ],
        ),
      ),
    );
  }
}
