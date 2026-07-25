import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// A single alarm row on the Home screen: time + label/repeat + sound summary
/// on the left, a TEST button and on/off toggle on the right.
class AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final String soundSummary;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onTest;

  const AlarmCard({
    required this.alarm,
    required this.soundSummary,
    required this.onOpen,
    required this.onToggle,
    required this.onTest,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: AppColors.cardBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmtTime(alarm.hour, alarm.minute),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1,
                      height: 1,
                      color: alarm.enabled ? Colors.white : AppColors.w(0.35),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${alarm.label.isEmpty ? 'Alarm' : alarm.label} · ${repeatSummary(alarm.days)}',
                    style: TextStyle(fontSize: 13, color: AppColors.w(0.5)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    soundSummary,
                    style: TextStyle(fontSize: 12, color: AppColors.w(0.32)),
                  ),
                ],
              ),
            ),
          ),
          // Dev-only preview button — compiled out of release builds so end
          // users never see it, per the "remove TEST before release" request.
          if (kDebugMode) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onTest,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.w(0.18)),
                ),
                child: Text(
                  'TEST',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.3,
                    color: AppColors.w(0.6),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          AppToggle(value: alarm.enabled, onTap: onToggle),
        ],
      ),
    );
  }
}
