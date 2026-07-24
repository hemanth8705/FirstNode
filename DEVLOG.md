# FirstNode — Development Log

> A running, plain-English log of **what** was built, **which** files/functions were
> added, and **why** — written so someone new to Flutter can follow along.
> Newest entries are added at the bottom of each section.

---

## 1. What we are building

**FirstNode** is an alarm app based on the Claude Design prototype *"Alarm app with
puzzle flow."* It is a dark-themed Android app (iOS later) with these screens:

1. **Home** — list of alarms (time, label, repeat days, sound summary, TEST button, on/off toggle)
2. **Edit alarm** — time, repeat days, label, sound mode (Specific song / Random / Pool), volume, gradual-volume ramp, and *puzzles to dismiss*
3. **Song picker**, 4. **Pool picker**, 5. **Pool editor** (song "pools" with per-song trim + volume, linear/shuffle order)
6. **Rewrite-puzzle config**, 7. **Math-puzzle config**
8. **Ringing screen**, 9. **Puzzle-solve screen** (solve puzzles to dismiss the alarm)

The original design is only an interactive *mock* — its data lives in memory and its
songs are fake names. Our job is to turn it into a real, shippable app.

---

## 2. Key decisions (and why)

These were confirmed with the product owner before any code was written.

| # | Decision | Choice | Why |
|---|----------|--------|-----|
| 1 | **Alarm sound source** | Bundled tones now, device music library later | Bundled audio ships inside the app: works offline, needs no permissions, and passes store review easily. Reading the user's music library needs media permissions and is unreliable for alarms (especially on iOS), so we defer it. |
| 2 | **Platform priority** | Android first, iOS later | The design is an Android layout, and **Android is the only platform that can fire true alarms** that wake the device / show a full-screen puzzle even when the app is closed. iOS forbids this and needs workarounds, so we perfect Android first. |
| 3 | **First milestone** | Full UI foundation first | Build every screen, all navigation, add/edit/delete alarms, configurable puzzles & pools, data saved across restarts, and a working in-app TEST flow. Real background alarm scheduling comes right after. |
| 4 | **App name** | **FirstNode** (no "pgagi" anywhere) | Product owner's instruction. |

### Package ID (the app's permanent store identity)
- Chosen: **`com.firstnode.firstnode`**
- The *package ID* (a.k.a. Android `applicationId` / iOS `bundle identifier`) is the
  unique name the Play Store and App Store use to identify the app. It is written in
  reverse-domain style and is effectively **impossible to change after the app is
  published**. So it is worth getting right at creation time.
- Underscores were deliberately avoided because Apple's App Store rejects them in
  bundle IDs. "pgagi" was excluded per instruction.

### Important reality about iOS (know this early)
Reliable "wake me up and make me solve a puzzle" alarms are only truly possible on
**Android**. Apple does **not** let third-party apps reliably wake the phone and run a
puzzle flow when the app is backgrounded or killed. The iOS version will therefore need
workarounds (keep-alive audio, local notifications) and **will not behave identically to
Android**. This affects the App Store plan and is flagged now so there are no surprises.

---

## 3. Technology choices

| Concern | Package / approach | Why (beginner-friendly reasoning) |
|---------|--------------------|-----------------------------------|
| **State management** (sharing the alarm list across screens) | `provider` + `ChangeNotifier` | The simplest approach the Flutter team recommends. One "store" object holds the data and *notifies* the UI to rebuild when it changes. Fewer new concepts than alternatives (Riverpod, BLoC). |
| **Saving data on the device** | `shared_preferences` (store JSON text) | Our data (a list of alarms + pools) is small and simple. We convert it to a JSON string and save it under one key. No database setup needed. |
| **Playing sound** | `audioplayers` | Well-supported plugin that plays bundled audio files on both Android and iOS. |
| **Screen navigation** | Flutter's built-in `Navigator` (push/pop) | Each screen is "pushed" onto a stack; the back button "pops" it. This is the standard Flutter way and gives us Android back-button handling for free. |

### Folder layout (under `lib/`)
```
lib/
  main.dart            app entry point: sets up the store + theme
  theme/app_theme.dart colors & text styles copied from the design
  models/              plain data classes (Alarm, Pool, Puzzle, Song) + JSON
  state/app_state.dart the ChangeNotifier "store" + load/save
  services/            puzzle generator, audio player, storage helper
  screens/             one file per screen
  widgets/             small reusable UI pieces (toggle, segmented control, ...)
```
**Why split into folders?** It keeps each file small and focused, so it is easy to find
"the alarm model" or "the home screen" without scrolling through one giant file.

---

## 4. Progress log

### 2026-07-25 — Project setup

- **Confirmed Flutter is installed:** Flutter 3.44.3 / Dart 3.12.2.
- **Read the full design** from the Claude Design project via the design tools, including
  its data model and logic (ported later into Dart).
- **Scaffolded the project** with:
  ```
  flutter create --project-name firstnode --org com.firstnode --platforms android,ios .
  ```
  - `--project-name firstnode` → the internal Dart package name (used in `import` lines).
  - `--org com.firstnode` → combined with the name to form the package ID `com.firstnode.firstnode`.
  - `--platforms android,ios` → generate Android + iOS folders only (no web/desktop clutter).
- This created the standard Flutter files: `lib/main.dart` (a demo counter app we will
  replace), `pubspec.yaml` (the project's dependency + asset manifest), and the
  `android/` + `ios/` native project folders.
- **Created this `DEVLOG.md`.**

### 2026-07-25 — Milestone 1: full UI foundation

Goal: rebuild the entire designed app as a real, clickable Flutter app with all
screens, navigation, data that saves across restarts, and a working in-app TEST
(ring + puzzle) flow. Real *scheduled* alarms are the next milestone.

#### Dependencies added
`flutter pub add provider shared_preferences audioplayers`
- **provider** — share the alarm/pool data with every screen and rebuild the UI
  when it changes.
- **shared_preferences** — save the data on the device as JSON.
- **audioplayers** — play the bundled tones.

#### Files created (grouped by layer, with the "why")

**Theme**
- [lib/theme/app_theme.dart](lib/theme/app_theme.dart) — `AppColors` (the exact
  dark palette from the design: bg `#0A0A0A`, cards `#141414`, white accent) plus
  `AppColors.w(opacity)` for the many translucent whites, and `buildAppTheme()`
  (the dark `ThemeData`, including the thin white slider style).

**Models** (plain data + `toJson`/`fromJson` for saving, and `clone()` for editing)
- [lib/models/song.dart](lib/models/song.dart) — `Song` + `kSongCatalog`, the
  fixed list of six bundled tones.
- [lib/models/puzzle.dart](lib/models/puzzle.dart) — a **sealed** `Puzzle` family:
  `RewritePuzzle` and `MathPuzzle` (with `Difficulty` per easy/medium/hard).
  "Sealed" means the compiler forces us to handle both kinds wherever we branch on
  a puzzle — safer than a loose `type` string.
- [lib/models/alarm.dart](lib/models/alarm.dart) — `Alarm` (time, days, sound mode,
  trim, volume, `Gradual` ramp, puzzles).
- [lib/models/pool.dart](lib/models/pool.dart) — `Pool` + `PoolSong`.

**Services** (logic with no UI)
- [lib/services/formatters.dart](lib/services/formatters.dart) — pure string
  helpers (`fmtTime`, `fmtMMSS`, `repeatSummary`, `summarizePuzzle`).
- [lib/services/puzzle_engine.dart](lib/services/puzzle_engine.dart) — the puzzle
  generator, ported 1:1 from the design's JavaScript: random rewrite strings, math
  questions (operators grow with difficulty; division only when it divides evenly),
  and `resolveQueue()` which expands an alarm's puzzles into the ordered list to
  solve. A `Random` can be injected for testing.
- [lib/services/storage.dart](lib/services/storage.dart) — load/save all data as
  one JSON string under a versioned key (`firstnode_data_v1`).
- [lib/services/audio_service.dart](lib/services/audio_service.dart) — one shared
  `AudioPlayer`; picks the right tone for an alarm's sound mode and loops it.

**State**
- [lib/state/app_state.dart](lib/state/app_state.dart) — `AppState` (a
  `ChangeNotifier`): the single source of truth for alarms + pools. Every change
  saves to disk. Also seeds three sample alarms + one pool on first launch so the
  app opens looking like the design. `soundSummary()` lives here because it needs
  to look pools up by id.

**Widgets** (small reusable pieces so every screen looks consistent)
- [lib/widgets/app_widgets.dart](lib/widgets/app_widgets.dart) — `SectionLabel`,
  `AppCard`, `AppToggle` (the animated on/off switch), `CircleStepButton`,
  `StepperControl`, `SegmentedControl<T>`, `ChoicePill`, `PrimaryButton`, and the
  two header bars (`EditHeader` = Cancel/title/Save, `BackHeader` = back + title).
- [lib/widgets/alarm_card.dart](lib/widgets/alarm_card.dart) — one row on the Home
  list.

**Screens** (one file each; all nine from the design)
- [home_screen.dart](lib/screens/home_screen.dart), [edit_alarm_screen.dart](lib/screens/edit_alarm_screen.dart),
  [song_picker_screen.dart](lib/screens/song_picker_screen.dart), [pool_picker_screen.dart](lib/screens/pool_picker_screen.dart),
  [pool_editor_screen.dart](lib/screens/pool_editor_screen.dart), [puzzle_rewrite_screen.dart](lib/screens/puzzle_rewrite_screen.dart),
  [puzzle_math_screen.dart](lib/screens/puzzle_math_screen.dart), [ringing_screen.dart](lib/screens/ringing_screen.dart),
  [puzzle_solve_screen.dart](lib/screens/puzzle_solve_screen.dart), plus
  [ring_flow.dart](lib/screens/ring_flow.dart) (the helper the TEST button calls).
- [lib/main.dart](lib/main.dart) — sets up `provider`, the theme, and shows Home.

#### Key implementation decisions (the "why", for learning)

1. **Navigation = the built-in Navigator stack.** The design tracked a "current
   screen" string + a manual history array. In Flutter the idiomatic equivalent is
   pushing a screen with `Navigator.push` and popping with the back button, which
   handles Android's system Back for free. So each screen is a route.

2. **Editing works on a draft copy.** Opening an alarm/pool passes a `clone()`.
   Screens mutate the copy; **Save** writes it to the store, **Cancel** just pops
   and the copy is discarded. This is why every model has a `clone()`.

3. **Pickers return a value; puzzle configs edit in place.** Choosing a song/pool
   uses `Navigator.pop(context, value)` and the edit screen applies it. Puzzle
   config screens instead edit the puzzle object directly (it already belongs to
   the alarm draft), matching the design where Done and Back both keep changes.

4. **Sliders snap to steps of 5** by rounding in the change handler (the design
   used HTML range `step=5`).

5. **The TEST flow is real.** Tapping TEST resolves the puzzle queue, opens the
   ringing or puzzle-solve screen, and **plays a tone**. Solving all puzzles (or
   Dismiss) closes it and stops the audio. Audio starts in `initState` and stops in
   `dispose`, so it's tied to the screen's lifetime.

#### Bundled tones
- [tool/generate_tones.dart](tool/generate_tones.dart) synthesizes six clean WAV
  tones into `assets/sounds/` (`dart run tool/generate_tones.dart`). Generating them
  ourselves means **zero copyright risk** and real working audio immediately. They
  can be swapped for professionally designed/licensed tones (same filenames) later.
- Declared under `flutter: assets:` in [pubspec.yaml](pubspec.yaml).

#### App identity
- Android `android:label` → **FirstNode** ([AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)).
- iOS `CFBundleDisplayName` → **FirstNode** ([Info.plist](ios/Runner/Info.plist)).

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → smoke test passes (Home renders, seeded alarm shows).
- `flutter build apk --debug` → **succeeds** (`app-debug.apk`), confirming the whole
  thing compiles and packages natively for Android.

#### Build fix (Windows Kotlin cache)
The first APK build failed with *"Could not close incremental caches"* while
compiling `shared_preferences_android`. This is a known Windows issue (antivirus /
file-locking on the Kotlin incremental-compile cache), **not** a code problem. Fix:
added `kotlin.incremental=false` to [android/gradle.properties](android/gradle.properties)
and re-ran after `flutter clean`. Build then succeeded. (Trade-off: slightly slower
incremental Kotlin builds; safe to revisit later.)

#### Deliberately deferred (so we ship the foundation first)
- **Real scheduled alarms** that fire when the app is closed/locked — the next
  milestone (Android exact-alarm + full-screen notification).
- **Gradual-volume ramp during playback** and **trim (start/end) during playback** —
  the settings are saved and shown; applying them to live audio comes with the
  scheduling work.
- **Device music library** picking — planned after bundled tones (per decision #1).
- **iOS monospace font** — we fall back to Menlo/Courier; a bundled mono font can be
  added when we polish iOS.
- **Puzzle-solve back button** is currently allowed (handy while testing); for a real
  fired alarm we'll block it so the alarm can't be dismissed without solving.

### 2026-07-25 — Milestone 2: real scheduled alarms (Android)

Goal: alarms that actually fire at the set time — even when the app is closed or
the phone is locked — ring loudly, and require solving the puzzles to dismiss.

#### Engine choice: the `alarm` package (v5.5.0)
Reliable alarms are the hard part. Rather than hand-build native code, we use the
**`alarm`** package, which is purpose-built for alarm-clock apps. It does the parts
that are genuinely hard on Android:
- Fires at an **exact** time via `AlarmManager`, surviving app-kill and reboot.
- Plays audio from a **foreground service** (so sound works even when killed).
- Shows a **full-screen intent** notification that can wake the screen.
- Exposes an `Alarm.ringing` stream so we can show our own puzzle UI.
- Its **volume fade** maps directly onto our "gradual volume" feature.

`flutter pub add alarm permission_handler` (permission_handler for the runtime
notification / exact-alarm prompts).

#### Android configuration
- [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml): added the alarm
  permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS`,
  `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, foreground-service
  perms, `VIBRATE`) and the package's `NotificationOnKillService`.
- [build.gradle.kts](android/app/build.gradle.kts): `compileSdk = 36` (the alarm
  package's `flutter_fgbg` dependency requires compiling against API 35+; Flutter's
  default 34 fails the build) and `multiDexEnabled = true`.
- [notification_icon.xml](android/app/src/main/res/drawable/notification_icon.xml):
  a white alarm-clock vector for the status-bar notification.

#### New code
- [lib/services/alarm_scheduler.dart](lib/services/alarm_scheduler.dart) — the heart
  of this milestone. It:
  - Computes `nextOccurrence()` from an alarm's time + repeat days (0=Mon…6=Sun;
    empty = once).
  - Maps our `Alarm` → the package's `AlarmSettings` (chooses the tone asset for
    specific/random/pool, sets `loopAudio`, `androidFullScreenIntent`, and volume).
  - **Gradual volume → `VolumeSettings.fade`**; otherwise `VolumeSettings.fixed`.
  - **Omits the notification Stop button when the alarm has puzzles**, so it can't be
    silenced without solving them.
  - `scheduleOne`, `cancel`, and `syncAll` (reconciles the OS schedule with our list).
- [lib/services/permissions.dart](lib/services/permissions.dart) — requests
  notification + exact-alarm permissions at startup.

#### Wiring (in [lib/main.dart](lib/main.dart))
- A global `navigatorKey` lets us navigate even when the app is launched *by* an
  alarm (no existing screen context).
- `main()` now `await`s `Alarm.init()` before scheduling anything.
- A root `StatefulWidget` listens to `Alarm.ringing`. When an alarm fires it looks up
  our `Alarm` (with its puzzles), pushes the ring/puzzle screen, and on dismiss:
  - **repeating alarm →** schedules the next occurrence;
  - **one-off alarm →** turns itself off.
- `AppState.onAlarmsChanged` re-syncs the OS schedule after every add/edit/delete/
  toggle. `AppState.ready` lets the ring handler wait for data on a cold start.

#### Test vs. real (one screen, two modes)
The `RingingScreen` / `PuzzleSolveScreen` gained flags:
- **TEST button** → `playInApp: true` (our `AudioService` previews the tone), back
  allowed.
- **Real alarm** → `playInApp: false` (the package is already playing audio),
  `blockBack: true` (can't back out of a puzzle), and an `onStop` callback that stops
  the native alarm and reschedules/disables it.

#### Known limitations (documented, for later milestones)
- **Pools/trim at ring time:** a fired alarm plays a *single* tone (first/random pool
  song), not a trimmed multi-song sequence. The pool/trim UI is saved but full
  playback needs a custom native player — future work.
- **Repeat rescheduling** happens when the alarm is acknowledged. A fully robust
  solution would reschedule from a native receiver even if ignored.
- **iOS** scheduling isn't wired yet (Android-first), and iOS can't match Android's
  background behavior regardless.
- **Permissions:** on Android 12 the user must allow "Alarms & reminders"; if denied,
  alarms may fire inexactly.

#### How to test on a device
1. `flutter run` on an Android phone; grant the notification / alarm permissions.
2. Add an alarm a minute or two ahead, keep it enabled, and lock the phone.
3. It should ring and show the puzzle screen; solve it to dismiss.
   (The **TEST** button still gives an instant in-app preview without waiting.)

#### Build fix (plugin compileSdk mismatch)
The APK build first failed at `:alarm:checkDebugAarMetadata`: the `alarm` 5.5.0 plugin
hardcodes `compileSdkVersion 34` in its own Gradle file, but its dependency
`flutter_fgbg 0.8.0` is built against API 35 and requires consumers to match — an
inconsistency inside the plugin. We can't edit the plugin (it lives in the pub cache
and would be overwritten), so the fix is a root-Gradle override in
[android/build.gradle.kts](android/build.gradle.kts) that forces every Android module
to `compileSdk = 36` (plus `compileSdk = 36` on the app module itself). A
`state.executed` guard avoids a Gradle "afterEvaluate on an already-evaluated
project" error for `:app`.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → passes.
- `flutter build apk --debug` → **succeeds** (`app-debug.apk`) with the native alarm
  engine integrated.

_(further entries appended below as each piece is built)_
