import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../services/formatters.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// A single alarm row on the Home screen: time + label/repeat + sound summary
/// on the left, the on/off toggle on the right.
class AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final String soundSummary;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  const AlarmCard({
    required this.alarm,
    required this.soundSummary,
    required this.onOpen,
    required this.onToggle,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.w(0.5)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    soundSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.w(0.32)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppToggle(value: alarm.enabled, onTap: onToggle),
        ],
      ),
    );
  }
}
