# FirstNode

A dark-themed alarm app built in Flutter, based on the "Alarm app with puzzle
flow" design. Alarms can play bundled tones, use song "pools", ramp volume, and
require solving **rewrite** or **math** puzzles before they can be dismissed.

> **New to this project?** Read [DEVLOG.md](DEVLOG.md) — it explains every decision,
> file, and how the pieces fit together, written for someone learning Flutter.

## Status
- **Milestone 1 (done):** full UI — all screens, add/edit/delete alarms, pools,
  puzzles, data saved across restarts, and a working in-app **TEST** ring/puzzle
  flow with real audio.
- **Milestone 2 (next):** real scheduled alarms that fire when the app is
  closed/locked (Android first).

## Run it
```bash
flutter pub get
dart run tool/generate_tones.dart   # generates the bundled tones (already committed)
flutter run                         # pick an Android device/emulator
```

## Where things live
```
lib/
  main.dart      app entry (Provider + theme)
  theme/         colors & theme
  models/        Alarm, Pool, Puzzle, Song (+ JSON)
  services/      puzzle engine, audio, storage, formatters
  state/         AppState — the data store
  widgets/       shared UI pieces
  screens/       one file per screen
assets/sounds/   bundled alarm tones
tool/            tone generator script
```

## Target platforms
Android first (the only platform that supports true background alarms). iOS
scaffolding exists and will follow, with the caveat that iOS restricts background
alarms — see DEVLOG for details.
