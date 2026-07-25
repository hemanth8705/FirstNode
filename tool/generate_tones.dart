// Generates the bundled alarm tones under assets/sounds/ as 16-bit PCM WAV.
//
// These are simple synthesized placeholder tones so the app has real, working
// audio out of the box (no copyright concerns). Run from the project root:
//
//     dart run tool/generate_tones.dart
//
// Later we can replace these files with professionally designed / licensed
// tones of the same names, or add device-library songs (see DEVLOG).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;
const double twoPi = 2 * pi;

void main() {
  Directory('assets/sounds').createSync(recursive: true);

  _write('assets/sounds/gentle_chime.wav', 12, _gentleChime);
  _write('assets/sounds/classic_beep.wav', 10, _classicBeep);
  _write('assets/sounds/morning_rise.wav', 15, _morningRise);
  _write('assets/sounds/soft_pulse.wav', 12, _softPulse);
  _write('assets/sounds/radar.wav', 10, _radar);
  _write('assets/sounds/sunrise.wav', 15, _sunrise);
  // True silence — used as the *native* placeholder for "Pools" mode alarms,
  // where Dart drives the actual audible sequencing (see AudioService.playPool
  // and AlarmScheduler's use of kSilentPlaceholderAsset). Never shown in the
  // user-facing song catalog.
  _write('assets/sounds/silent_placeholder.wav', 5, (t) => 0);

  stdout.writeln('Done — 7 tones written to assets/sounds/');
}

/// A short attack/release envelope so notes don't click on/off.
double _env(double t, double dur, {double attack = 0.01, double release = 0.05}) {
  if (t < attack) return t / attack;
  if (t > dur - release) return max(0, (dur - t) / release);
  return 1;
}

double _gentleChime(double t) {
  const period = 2.0;
  final local = t % period;
  final decay = exp(-local * 3.0);
  final v = sin(twoPi * 880 * t) +
      0.5 * sin(twoPi * 1760 * t) +
      0.3 * sin(twoPi * 2640 * t);
  return 0.4 * decay * v;
}

double _classicBeep(double t) {
  const period = 0.5, on = 0.25;
  final local = t % period;
  if (local >= on) return 0;
  return 0.4 * _env(local, on, release: 0.03) * sin(twoPi * 1000 * t);
}

double _morningRise(double t) {
  const period = 3.0;
  final local = t % period;
  final freq = 400 + 300 * (local / period);
  final amp = 0.35 * (0.5 - 0.5 * cos(twoPi * local / period));
  return amp * sin(twoPi * freq * t);
}

double _softPulse(double t) {
  final amp = 0.5 + 0.5 * sin(twoPi * 1.6 * t);
  return 0.32 * amp * sin(twoPi * 440 * t);
}

double _radar(double t) {
  const note = 0.2, on = 0.13, group = 5 * note, period = group + 0.8;
  final local = t % period;
  if (local >= group) return 0;
  final idx = (local / note).floor();
  final nt = local % note;
  if (nt >= on) return 0;
  final freq = 600 + idx * 180;
  return 0.4 * _env(nt, on, release: 0.03) * sin(twoPi * freq * t);
}

double _sunrise(double t) {
  const notes = [523.25, 659.25, 783.99, 1046.5];
  const noteDur = 0.375, total = 1.5, period = 2.5; // 4 notes * 0.375 + 1.0s gap
  final local = t % period;
  if (local >= total) return 0;
  final idx = (local / noteDur).floor();
  final nt = local % noteDur;
  final amp = 0.35 * _env(nt, noteDur, attack: 0.02, release: 0.12) * exp(-nt * 0.8);
  return amp * (sin(twoPi * notes[idx] * t) + 0.3 * sin(twoPi * 2 * notes[idx] * t));
}

void _write(String path, int seconds, double Function(double t) synth) {
  final n = sampleRate * seconds;
  final bytes = ByteData(44 + n * 2);

  // ---- WAV header ----
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  final dataBytes = n * 2;
  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);

  // ---- samples ----
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final v = synth(t).clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }

  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
  stdout.writeln('  wrote $path (${seconds}s)');
}
