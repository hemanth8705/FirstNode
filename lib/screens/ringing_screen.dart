import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../services/audio_service.dart';
import '../services/formatters.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Shown when an alarm rings and it has no puzzles: a pulsing dot, the time,
/// the label, and a Dismiss button. Audio plays while this screen is open.
class RingingScreen extends StatefulWidget {
  final Alarm alarm;
  const RingingScreen({required this.alarm, super.key});

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen>
    with SingleTickerProviderStateMixin {
  late final AudioService _audio = context.read<AudioService>();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    // Start ringing. Read pools once here (listen:false) to pick the tone.
    _audio.playForAlarm(widget.alarm, context.read<AppState>().pools);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return Opacity(
                      opacity: 0.25 + 0.75 * t,
                      child: Transform.scale(
                        scale: 1 + 0.15 * t,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  fmtTime(widget.alarm.hour, widget.alarm.minute),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.alarm.label.isEmpty ? 'Alarm' : widget.alarm.label,
                  style: TextStyle(fontSize: 15, color: AppColors.w(0.5)),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 180,
                  child: PrimaryButton(
                    label: 'Dismiss',
                    radius: 100,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
