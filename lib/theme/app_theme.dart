import 'package:flutter/material.dart';

/// Colors and text styles copied from the original design.
///
/// The design is a dark app: a near-black background (#0A0A0A), slightly
/// lighter cards (#141414), and white as the accent. Many text colors are
/// "white at some opacity" (e.g. rgba(255,255,255,0.5)), so the helper
/// [AppColors.w] builds those on demand.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0A0A0A); // page background
  static const Color surface = Color(0xFF141414); // cards / inputs
  static const Color surfaceAlt = Color(0xFF1C1C1C); // inner pill track
  static const Color surfaceAlt2 = Color(0xFF242424); // song-art stripe

  static const Color accent = Colors.white; // active pill / toggle-on
  static const Color onAccent = Color(0xFF0A0A0A); // text on a white pill
  static const Color text = Color(0xFFF5F5F5); // default text

  /// White at [opacity] (0..1). Used for the many translucent whites.
  static Color w(double opacity) => Colors.white.withValues(alpha: opacity);

  /// Standard hairline border used on cards and inputs.
  static Border get cardBorder => Border.all(color: w(0.08));
}

/// Builds the app-wide dark theme handed to [MaterialApp].
ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.bg,
      primary: Colors.white,
    ),
    // The design uses the platform's default sans-serif (Roboto on Android),
    // so we don't ship a custom font — we just tune sizes/weights per widget.
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 2,
      activeTrackColor: Colors.white,
      inactiveTrackColor: AppColors.w(0.18),
      thumbColor: Colors.white,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    ),
  );
}
