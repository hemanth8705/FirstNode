import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

import '../theme/app_theme.dart';

/// Small, reusable UI pieces shared across screens. Keeping them here means
/// every screen looks consistent and we only style each element once.

/// The little grey uppercase section heading ("REPEAT", "LABEL", "SOUND"…).
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(fontSize: 12, letterSpacing: 0.5, color: AppColors.w(0.4)),
  );
}

/// Shows [text] as plain left-aligned text if it fits the available width;
/// otherwise scrolls it horizontally (marquee) so long filenames are fully
/// readable instead of being truncated.
class MarqueeOrText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const MarqueeOrText({required this.text, required this.style, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        if (painter.width <= constraints.maxWidth) {
          return Align(alignment: Alignment.centerLeft, child: Text(text, style: style));
        }
        return Marquee(
          text: text,
          style: style,
          blankSpace: 40,
          velocity: 30,
          pauseAfterRound: const Duration(seconds: 1),
        );
      },
    );
  }
}

/// A small circular Play/Pause button used for song previews.
class PreviewButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  final double size;
  final bool filled;
  const PreviewButton({
    required this.playing,
    required this.onTap,
    this.size = 30,
    this.filled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? Colors.white : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.w(0.18)),
        ),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          size: size * 0.53,
          color: filled ? AppColors.onAccent : Colors.white,
        ),
      ),
    );
  }
}

/// A dark rounded panel with a hairline border — the app's basic "card".
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.radius = 12,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: AppColors.cardBorder,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: box,
    );
  }
}

/// The custom on/off switch from the design (white when on, dark thumb).
class AppToggle extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  const AppToggle({required this.value, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.accent : AppColors.w(0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.onAccent : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small circular outline button showing a single glyph (used for − / +).
class CircleStepButton extends StatelessWidget {
  final String glyph;
  final VoidCallback? onTap;
  final double size;
  const CircleStepButton({
    required this.glyph,
    required this.onTap,
    this.size = 26,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.w(0.15)),
        ),
        child: Text(
          glyph,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.54,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// "− value +" control. Buttons are disabled (dimmed) when their callback is null.
class StepperControl extends StatelessWidget {
  final String value;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final double valueWidth;
  final double gap;
  const StepperControl({
    required this.value,
    required this.onDec,
    required this.onInc,
    this.valueWidth = 48,
    this.gap = 16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleStepButton(glyph: '−', onTap: onDec),
        SizedBox(width: gap),
        SizedBox(
          width: valueWidth,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        SizedBox(width: gap),
        CircleStepButton(glyph: '+', onTap: onInc),
      ],
    );
  }
}

/// One choice in a [SegmentedControl].
class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption(this.value, this.label);
}

/// A pill-shaped segmented control (e.g. Specific / Random / Pool).
class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color trackColor;

  const SegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
    this.trackColor = AppColors.surface,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: options.map((o) {
          final active = o.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  o.label,
                  style: TextStyle(
                    color: active ? AppColors.onAccent : AppColors.w(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A rounded outline pill that can be toggled active (filled white) — used for
/// character-set choices and small filter buttons.
class ChoicePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final EdgeInsets padding;
  const ChoicePill({
    required this.label,
    required this.active,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.w(0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.onAccent : AppColors.w(0.6),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// The big white full-width primary button ("Done" / "Save" / "Dismiss").
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double radius;
  const PrimaryButton({
    required this.label,
    required this.onTap,
    this.radius = 12,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.onAccent,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Header with Cancel (left) / title (center) / Save (right). Used by the edit
/// screens where changes are committed only on Save.
class EditHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String cancelLabel;
  final String saveLabel;
  const EditHeader({
    required this.title,
    required this.onCancel,
    required this.onSave,
    this.cancelLabel = 'Cancel',
    this.saveLabel = 'Save',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.w(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HeaderTextButton(
            label: cancelLabel,
            onTap: onCancel,
            color: AppColors.w(0.55),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          _HeaderTextButton(
            label: saveLabel,
            onTap: onSave,
            color: Colors.white,
            weight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

/// Header with a back chevron + title, and an optional trailing action. Used by
/// the picker / config screens.
class BackHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;
  const BackHeader({
    required this.title,
    this.trailing,
    this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.w(0.08))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A centered icon + title + optional subtitle + optional call-to-action,
/// used everywhere an empty list would otherwise just be blank.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.w(0.25)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.w(0.6), fontSize: 15),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.w(0.35), fontSize: 13, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A non-dismissible "Importing N of M — filename" dialog driven by a
/// `ValueNotifier` of `(done, total, currentFileName)`, shared by every screen
/// that runs a multi-file import.
class ImportProgressDialog extends StatelessWidget {
  final ValueNotifier<(int, int, String)> progress;
  const ImportProgressDialog({required this.progress, super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ValueListenableBuilder<(int, int, String)>(
        valueListenable: progress,
        builder: (context, value, _) {
          final (done, total, name) = value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total == 0 ? 'Preparing…' : 'Importing $done of $total',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.w(0.5), fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: total == 0 ? null : done / total,
                backgroundColor: AppColors.w(0.1),
                color: Colors.white,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows a Cancel/Confirm dialog and resolves `true` only if the user tapped
/// confirm. Used before every destructive action in the app (delete alarm,
/// delete pool, remove a song from a pool, delete a library song).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: message == null
          ? null
          : Text(message, style: TextStyle(color: AppColors.w(0.55), fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: AppColors.w(0.55))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? Colors.redAccent : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _HeaderTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final FontWeight weight;
  const _HeaderTextButton({
    required this.label,
    required this.onTap,
    required this.color,
    this.weight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          label,
          style: TextStyle(fontSize: 15, color: color, fontWeight: weight),
        ),
      ),
    );
  }
}
