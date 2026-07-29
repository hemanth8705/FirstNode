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

### 2026-07-25 — Time picker: scrollable wheels, 1-minute steps

User feedback while testing on-device: the minute stepper jumped in 5-minute
increments (ported directly from the original design) and should instead be
1-minute and scrollable, matching how native mobile time pickers work.

- [lib/screens/edit_alarm_screen.dart](lib/screens/edit_alarm_screen.dart): replaced
  the ▲/▼ tap-to-step hour/minute columns with two `CupertinoPicker` scroll wheels
  (hour 0-23, minute 0-59 — every value, so 1-minute granularity). `CupertinoPicker`
  is a single iOS-style widget import from `flutter/cupertino.dart`; using it inside
  a `MaterialApp` is a standard Flutter pattern and doesn't change the app's overall
  theming.
- The wheels' `FixedExtentScrollController`s are created **once** as state fields
  (not rebuilt on every `build()`), so unrelated changes elsewhere on the same
  screen (e.g. dragging the volume slider) don't reset their scroll position.
- Removed the now-unused `_incHour/_decHour/_incMinute/_decMinute` and
  `_timeColumn` methods.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → passes.

### 2026-07-25 — Import personal audio files; hide TEST button in release

User feedback while reviewing progress: (1) let users import their own audio
files as alarm tones, and (2) the "TEST" button/tag shouldn't be visible in the
shipped app.

#### TEST button → debug-only
- [lib/widgets/alarm_card.dart](lib/widgets/alarm_card.dart): wrapped the TEST
  button in `if (kDebugMode)`. It's compiled out of release builds entirely
  (satisfying "removed before release") while staying available for our own
  testing during `flutter run` debug sessions.

#### Import personal audio files
New dependencies: `file_picker` (system file picker) and `path_provider`
(app-private storage directory) — `flutter pub add file_picker path_provider`.

- [lib/models/song.dart](lib/models/song.dart): `Song` gained an `imported`
  flag and `toJson`/`fromJson`, since imported tones (unlike the fixed bundled
  catalog) are user-specific and must be persisted. `songByName`/`songDuration`
  now take an explicit `catalog` list instead of only searching the bundled
  `kSongCatalog`, so callers can pass the combined bundled+imported list.
- [lib/services/song_import.dart](lib/services/song_import.dart) — new service:
  opens the system audio picker, **copies the chosen file into the app's own
  private storage** (`path_provider`'s application-support directory, under
  `imported_sounds/`), then probes its duration by loading it into a throwaway
  `audioplayers` `AudioPlayer` (`setSourceDeviceFile` + `getDuration()` — no
  extra package needed, and it doesn't audibly play anything).
  - **Why copy the file instead of using the picked path directly?** The file
    picker's result may point to a cache location or a content:// URI-backed
    path without a durable permission grant. A real alarm can fire hours or
    days later, possibly after the phone reboots — the tone must still be
    readable then. Copying into our own app-private directory guarantees that,
    and app-private storage needs no runtime storage permission on any Android
    version.
- [lib/state/app_state.dart](lib/state/app_state.dart): added `customSongs`,
  persisted via `Storage` (extended its JSON to include a `customSongs` key —
  old saves without it default to an empty list), `allSongs` (bundled + custom,
  the catalog every picker/player should use), and `addCustomSong()` (renames
  on a name collision: "Song", "Song (2)", …).
- [lib/screens/song_picker_screen.dart](lib/screens/song_picker_screen.dart):
  added an "Import from device" row at the top of the list. Picking a file adds
  it to `AppState` and — matching how choosing an existing song behaves —
  either selects it immediately (specific-song mode) or adds it to the pool
  being edited and stays open (pool-add mode). Imported rows show a folder icon
  instead of the bundled music-note icon so users can tell them apart.
- **Playback wiring** — confirmed via the `alarm` package's own docs that its
  `assetAudioPath` field accepts *either* a Flutter asset key *or* an absolute
  device file path, so real scheduled alarms already handle imported tones with
  no extra native work; only the lookup catalog needed threading through
  ([lib/services/alarm_scheduler.dart](lib/services/alarm_scheduler.dart)).
  [lib/services/audio_service.dart](lib/services/audio_service.dart) (used by
  TEST and by the in-app ring/puzzle screens) picks `AssetSource` vs
  `DeviceFileSource` based on `Song.imported`.
- Every call site that looked up a song by name (`edit_alarm_screen.dart`,
  `pool_editor_screen.dart`, `main.dart`, `ringing_screen.dart`,
  `puzzle_solve_screen.dart`) now passes `AppState.allSongs` through instead of
  only searching the bundled catalog.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → passes.
- `flutter build apk --debug` → succeeds with the new native plugins.

### 2026-07-25 — Bug investigation: alarms ringing on boot / USB connect

User report: a "Random Pool" alarm sometimes played its sound when the phone
booted up or was connected via USB, instead of only at the scheduled time.

#### Root cause (confirmed by reading the `alarm` package's own source)
We only ever schedule the **next single occurrence** of each alarm (a one-shot
`dateTime`); "repeat on Mon/Wed/Fri" is entirely our own Dart-side concept —
the native plugin has no notion of it. That's fine normally, because after each
ring we reschedule the next occurrence ourselves
([lib/main.dart](lib/main.dart)'s `_dismissReal`).

The bug is in what happens **without our Dart code involved at all**. The
`alarm` package's own native `BootReceiver` (bundled inside the plugin, source
at `alarm-5.5.0/android/.../alarm/BootReceiver.kt`) runs on `BOOT_COMPLETED`
independently of our Flutter engine — it doesn't wait for the app to open. It
reads its own natively-persisted alarm list (`AlarmStorage`, a separate store
from our `shared_preferences` data) and replays each alarm's **last-known**
`dateTime` verbatim via `AlarmApiImpl.setAlarm()`. That method contains:

```kotlin
val delayInSeconds = (alarm.dateTime.time - System.currentTimeMillis()) / 1000
if (delayInSeconds <= 5) {
    handleImmediateAlarm(alarmIntent, delayInSeconds.toInt())  // fires almost instantly
} else {
    handleDelayedAlarm(...)  // properly scheduled via AlarmManager
}
```

If the stored `dateTime` is already in the past — which is very likely after any
reboot that happens *after* the alarm's last-scheduled time (e.g. a 6:30am alarm
and the phone reboots that afternoon) — `delayInSeconds` is negative, hits the
"immediate" branch, and the alarm rings right away, playing whatever tone was
picked (for Random/Pool-shuffle, whatever was last randomly chosen) — **not** a
fresh selection, just a stale replay.

I checked: this isn't fixed in a newer package version (5.5.0 is current) and
isn't a known/tracked GitHub issue — it's a genuine gap in the plugin's
boot-recovery logic. It's most likely to surface during heavy dev/test cycles
(exactly what we've been doing this session — leaving test alarms armed while
repeatedly rebooting/reinstalling the same phone), but it's a real risk for any
end user too.

I could not find equally hard evidence for the **USB-connect** trigger — the
plugin's manifest only registers for `BOOT_COMPLETED`, not any
reinstall/package-replaced or USB-related action, so it isn't the exact same
code path. It's plausible it's an adjacent effect (e.g. Android's Doze-exemption
behavior while a debugger is attached surfacing a previously-stuck stale alarm),
but I'm flagging that part as a reasonable hypothesis rather than a proven cause.
The fix below removes the *entire class* of "replay a stale one-shot time"
behavior regardless of what triggers it, which should cover this too — worth
confirming next time it happens (see "how to verify" below).

#### Fix
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml):
  disabled the plugin's own `BootReceiver` via the standard Android manifest-merger
  override (`tools:node="remove"` on a matching `<receiver>` declaration), and
  registered our own receiver for `BOOT_COMPLETED` instead.
- [android/app/src/main/kotlin/.../SafeBootRescheduleReceiver.kt](android/app/src/main/kotlin/com/firstnode/firstnode/SafeBootRescheduleReceiver.kt) —
  new receiver, reusing the plugin's own public `AlarmStorage`/`AlarmApiImpl`
  classes (no fork needed): for each stored alarm, **re-arm it only if its
  `dateTime` is still in the future**; otherwise skip it silently. A skipped
  alarm isn't lost — our own `AppState.ready` → `AlarmScheduler.syncAll()` (which
  *does* know the real repeat-day rule) correctly reschedules it the next time the
  app is opened. Trade-off, stated plainly: an alarm whose time was missed while
  the phone was off won't ring retroactively until the app is reopened — the same
  category of trade-off most software alarms make, and vastly preferable to
  ringing at the wrong moment.

#### On requirement #3 ("random selection works reliably every time the alarm fires")
Worth understanding precisely: the `alarm` package bakes a fixed `assetAudioPath`
into the native alarm at the moment we call `Alarm.set()` — there's no hook for
"pick the file at the exact instant it rings." So the random/shuffle pick is
decided at the **last (re)schedule time** (right after the previous ring's
dismissal, or whenever `syncAll()` runs), not at the literal ring moment. In
practice this still means a different song each time it actually rings — it just
means the pick can also silently re-roll if `syncAll()` runs for an unrelated
reason (e.g. editing a *different* alarm triggers a global re-sync). This is a
minor, invisible-in-the-UI characteristic of the current design, not a source of
unexpected playback — that was exclusively the boot-replay bug above. Flagging it
here for transparency; happy to build a stricter "only reschedule alarms that
actually changed" pass if it matters, but it isn't needed to satisfy the reported
bug.

#### How to verify / what to watch for next time
Logcat filtered on `SafeBootReschedule` will now show exactly which alarms were
re-armed vs. skipped after any reboot. If the USB-connect scenario happens again,
capturing logcat at that moment (`adb logcat | grep -i alarm`) would confirm
whether it's going through this same receiver or something else entirely.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter build apk --debug` → succeeds with the new receiver + manifest override.

### 2026-07-25 — Fix: text overflow with long imported song names

User screenshot showed a red-and-black striped banner reading "RIGHT OVERFLOWED
BY 220 PIXELS" on the Edit Alarm screen after importing a real audio file with a
long name ("Karpur Gauram Karunavataram..."). That banner is Flutter's built-in
debug-mode layout warning (`RenderFlex overflowed`) — not a network/AI error.

**Why it only showed up now:** every bundled tone name is short ("Radar",
"Sunrise", ≤11 characters), so no row displaying a song name had ever been
tested against a long string. Imported files can have arbitrarily long names,
and several rows put a `Text` directly inside a `Row` (or an unbounded inner
`Row`) with no `Expanded` wrapper and no `overflow`/`maxLines` — Flutter renders
such a `Text` at its full natural width, which overflows the row once the name
is longer than the remaining space.

Fixed by wrapping every place a song/pool name is shown in `Expanded` and adding
`maxLines: 1` + `overflow: TextOverflow.ellipsis` (truncates with "…" instead of
overflowing or wrapping):
- [lib/screens/edit_alarm_screen.dart](lib/screens/edit_alarm_screen.dart)'s
  `_rowWithChevron` — the exact row from the screenshot (specific-song and
  pool-name display).
- [lib/screens/song_picker_screen.dart](lib/screens/song_picker_screen.dart)'s
  `_songRow` — same bug class (nested unbounded Row/Column).
- [lib/screens/pool_editor_screen.dart](lib/screens/pool_editor_screen.dart) and
  [lib/screens/pool_picker_screen.dart](lib/screens/pool_picker_screen.dart) —
  already had `Expanded` (no crash), added ellipsis for consistency so a long
  name doesn't instead wrap awkwardly across multiple lines.
- [lib/widgets/alarm_card.dart](lib/widgets/alarm_card.dart) — same consistency
  fix for the label/sound-summary lines on the Home screen.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → passes.

### 2026-07-25 — Song selection UX overhaul + Random-mode-uses-pool

Six requested changes to how sounds are chosen and previewed.

#### 1. Trim sliders: 1-second precision
[lib/screens/edit_alarm_screen.dart](lib/screens/edit_alarm_screen.dart) and
[lib/screens/pool_editor_screen.dart](lib/screens/pool_editor_screen.dart)'s
start/end trim sliders rounded to 5-second steps (`(v/5).round()*5`); changed
to `v.round()` with `divisions: <duration in seconds>` — every second is
reachable, and the explicit `divisions` gives the same visual "snap" feedback
the volume slider already had (unchanged, still 5% steps).

#### 2. Song Picker: select-then-Done instead of pop-on-tap
[lib/screens/song_picker_screen.dart](lib/screens/song_picker_screen.dart)
converted from `StatelessWidget` to `StatefulWidget`. Tapping a song (Specific
mode) now just highlights it (border + a checkmark) via local `_selected`
state; a **Done** button in the header's top-right (`BackHeader`'s `trailing`
slot) is what actually pops with the result. Pool-add mode keeps its existing
"tap adds immediately, can add several" behavior, but its Done button moved
from the bottom of the screen into the same header slot, so both modes now
close the same way.

#### 3 & 4. Song preview (list + trim-aware) — new `AudioService` API
Both the song list and the Edit Alarm screen needed "tap to hear it" — the
list previews a song from the start, Edit Alarm previews *exactly the
currently-selected trim range* ("hear what the alarm will actually play").
Built once, used in both places:
- [lib/services/audio_service.dart](lib/services/audio_service.dart) —
  `preview(allSongs, name, {startSec, endSec, volume})`: plays once (no loop,
  unlike the looping alarm/TEST playback), seeks to `startSec`, and — if
  `endSec` is given — listens to `onPositionChanged` and auto-pauses on
  reaching it. `pausePreview`/`resumePreview`/`stopPreview` round out the API.
  State (`previewingName`, `previewPlaying`) is exposed as `ValueNotifier`s so
  any screen can reactively show the right icon without owning the state
  itself — avoids each screen re-implementing "which song, is it playing."
- [lib/widgets/app_widgets.dart](lib/widgets/app_widgets.dart) — new
  `PreviewButton` (small circular Play/Pause) shared by both screens.
- Trim preview toggles **play/stop** (not pause/resume): the trim bounds can
  change between presses, so "resume from wherever it paused" would be
  confusing once the range no longer matches. The list preview *does* use
  real pause/resume, since nothing else changes while browsing.

#### 4 (UI). Selected-song card redesign
New `_selectedSongCard()` in
[edit_alarm_screen.dart](lib/screens/edit_alarm_screen.dart) replaces the old
chevron-row: slightly shorter padding, split into name (left) + trim-preview
button + chevron (right). Long filenames scroll via a new
[MarqueeOrText](lib/widgets/app_widgets.dart) widget (added the `marquee`
package) that only scrolls when the text actually doesn't fit — measured with
a `TextPainter` inside a `LayoutBuilder` — short names just render as normal
left-aligned text, no unnecessary animation.

#### 5 & 6. Random mode now requires a pool; label "Pool" → "Pools"
Clarified with the user first, since "Random" and the existing "Pool" mode
would otherwise become functionally identical: **Random** = pick a pool, then
*always* shuffle-pick a song from it (ignores that pool's own order setting) —
a quick "just shuffle this pool" shortcut. **Pools** (renamed from "Pool") =
pick a pool, respect *its own* configured order (Linear = its first/configured
song, Shuffle = random) — unchanged behavior, just relabeled and now with
explanatory text distinguishing it from Random.
- [lib/screens/edit_alarm_screen.dart](lib/screens/edit_alarm_screen.dart):
  Random mode's UI now shows the same pool-picker row Pools mode does (reusing
  `_openPoolPicker`, which already just sets `draft.poolId` — no new plumbing
  needed there), plus mode-specific explanatory text.
- [lib/services/alarm_scheduler.dart](lib/services/alarm_scheduler.dart) and
  [lib/services/audio_service.dart](lib/services/audio_service.dart): both
  gained a shared `_findPool` helper; `random` now looks up `a.poolId` and
  shuffles within `pool.songs` (falls back to any song across the whole
  catalog if no pool is set — covers alarms saved before this change).
- [lib/state/app_state.dart](lib/state/app_state.dart)'s `soundSummary` now
  shows the pool name for Random mode too ("Random · Weekday Mix").
- While touching this: fixed a pre-existing inconsistency where `AudioService`
  (TEST/in-app ring) ignored a pool's Shuffle order and always played its
  first song, while `AlarmScheduler` (real alarms) respected it correctly —
  TEST now matches real-alarm behavior.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → passes.
- `flutter build apk --debug` → succeeds.

### 2026-07-25 — Fix: Pools mode didn't cycle through songs; removed TEST button

User report: with a "Weekday Mix" pool (Linear order, 2 songs) selected, only
the first song ever played — it just looped forever instead of moving to the
second song after its trimmed length and cycling back to the first.

#### Root cause
Pool mode was never actually implemented as a sequence. Both `AlarmScheduler`
(real alarms) and `AudioService` (in-app playback) treated "Pools" as "pick
**one** representative song from the pool" — the first song for Linear order,
or one random pick for Shuffle — then handed that single song to the audio
layer to loop **forever**. This was a known, documented simplification from
Milestone 2 ("Pools/trim at ring time: a fired alarm plays a single tone... the
pool/trim UI is saved but full playback needs a custom player — future work") —
today's report is exactly that future work coming due.

#### Fix: true sequential/looping pool playback
[lib/services/audio_service.dart](lib/services/audio_service.dart) gained
`playPool(pool, allSongs, alarm)` — a real per-song sequencer:
- Builds a queue from the pool's songs (list order for Linear; shuffled once
  at the start of ringing for Shuffle — the order isn't reshuffled every loop,
  keeping behavior predictable once ringing starts).
- Plays each song from its own `start` to `end` (its individual trim), at its
  own relative volume **combined with the alarm's overall volume**
  (`alarm.volume% × song.volume% / 100`) — previously each pool song's own
  volume slider was set in the UI but silently ignored during playback, since
  only one song ever played; now that multiple genuinely play, honoring it is
  part of making the feature work as designed, not a scope add.
- Advances to the next song via `AudioPlayer.onPositionChanged` once it
  crosses `end`, and **also** on `onPlayerComplete` (the song's own file
  finishing naturally) — needed because a song's own audio can be shorter than
  its configured trim `end` (e.g. left at the default 60s over a 15s tone);
  without the second check, playback would silently stall in silence once the
  file ran out, since position would never reach the configured cutoff.
- Wraps back to the first song once the queue is exhausted, continuing
  indefinitely until `stop()` is called (dismissal).
- Implements gradual volume itself (a linear ramp over `gradual.duration`,
  matching how the native side already does it) so pool-mode alarms don't
  silently lose that feature now that Dart owns their audible playback (see
  below) — the ramp continues seamlessly across song changes.

#### Real fired alarms needed a deeper change, not just TEST/in-app
The native `alarm` package can only loop one fixed audio file — no concept of
"play A, then B, then loop." For real (backgrounded/killed-app) alarms it's
literally impossible to sequence natively, so:
- [lib/services/alarm_scheduler.dart](lib/services/alarm_scheduler.dart): Pools
  mode now schedules the native alarm with a **true-silence placeholder**
  (`assets/sounds/silent_placeholder.wav`, added to
  [tool/generate_tones.dart](tool/generate_tones.dart)) instead of a real song —
  the native side still fires, wakes the screen, vibrates, and shows the
  notification (all unaffected), it just doesn't play anything audible itself.
- [lib/main.dart](lib/main.dart)'s `_onRing` now sets `playInApp: true`
  specifically when `alarm.soundMode == SoundMode.pool` (every other mode
  keeps relying on the native side's own loop, unchanged) — so **Dart's**
  `AudioService.playPool()` takes over actual audible playback the moment the
  ring/puzzle screen mounts, for both TEST-style and real alarm firing alike.
- Trade-off worth knowing: there's a brief (well under a second, given
  `androidFullScreenIntent` launches the screen immediately) silent gap between
  the native alarm firing and Dart's screen mounting to take over — acceptable
  for correct sequencing over the previous "loops forever, never advances" bug.

#### TEST button removed (for real this time)
Previously gated behind `kDebugMode` (hidden in release, visible in debug) per
an earlier ask — user asked again to just remove it outright, so it's now gone
unconditionally: [lib/widgets/alarm_card.dart](lib/widgets/alarm_card.dart) (no
more button/`onTest`), [lib/screens/home_screen.dart](lib/screens/home_screen.dart)
(wiring removed), and `lib/screens/ring_flow.dart` deleted entirely (it was
`startRing`'s only caller). To exercise ring/puzzle flows now, use a real
scheduled alarm.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → passes.
- `flutter build apk --debug` → succeeds.

### 2026-07-25 — Fix: alarm/Dismiss not responsive while phone is locked

User report: with the phone idle/locked, an alarm set for e.g. 5:00 wouldn't
actually start ringing until the phone was unlocked (e.g. at 5:02) — and when
it did ring, tapping Dismiss had no effect until unlock either. Both symptoms
went away the instant the phone was unlocked, in either direction (ring
"catching up", Dismiss suddenly working).

#### Root cause
[android/app/src/main/kotlin/.../MainActivity.kt](android/app/src/main/kotlin/com/firstnode/firstnode/MainActivity.kt)
was the bare Flutter template default — it never told Android that this
Activity should be **interactive over the lock screen**. The `alarm` package's
own install docs note that versions before 5.0.0 configured this
automatically, but it no longer does (we depend on 5.5.0) — meaning the *app*
is responsible for it now, and nothing ever added it.

Without it, the sequence that actually happened: the native alarm fires
exactly on time (that part is real `AlarmManager`, unaffected) and its
full-screen-intent notification *launches* our Activity over the lock screen —
but without opting in via `showWhenLocked`/`turnScreenOn`, Android treats it as
a normal activity that shouldn't be fully interactive while genuinely locked.
It sits in an ambiguous "visible but not truly resumed" state: our Dart code
(and therefore `AudioService.playPool()` actually starting sound, and the
Dismiss button's tap handler) doesn't get a chance to properly run until the
user's own unlock gesture forces Android to fully resume the activity stack —
which is exactly "everything catches up the moment I unlock."

This is the textbook three-part recipe for a reliable full-screen alarm/call
UI on Android — `USE_FULL_SCREEN_INTENT` permission + a notification with
`fullScreenIntent` (both already in place via the `alarm` package) + the
**target Activity opting into show-over-lock-screen** (the missing piece).

#### Fix
`MainActivity.onCreate()` now calls `setShowWhenLocked(true)` +
`setTurnScreenOn(true)` (the modern Activity API, Android 8.1/API 27+), with a
fallback to the older `WindowManager.LayoutParams` flags for API 23-26 (our
`minSdk`). This makes the alarm/puzzle screen fully visible, awake, *and*
properly touch-interactive straight from the lock screen — without fully
unlocking the device — exactly like the stock Clock/Phone apps.

Deliberately left out: `FLAG_KEEP_SCREEN_ON`. It's set at the Activity level
for its whole lifetime, and since this Activity is also the normal one used for
browsing the alarm list, an unconditional keep-awake would drain battery during
regular use too — out of scope for what was reported. If the screen turning off
mid-puzzle becomes its own issue, that calls for a narrower fix (e.g. toggling
it only while the ring/puzzle screen is shown).

#### A second factor worth ruling out on this device
This phone is a Xiaomi/POCO device (confirmed earlier this session via `adb
shell getprop ro.product.manufacturer`). MIUI/HyperOS is well known for extra,
OS-level background/battery restrictions on top of stock Android's — even with
the code fix above, if any of these aren't granted for FirstNode, similar
symptoms could still show up:
- **Settings → Apps → FirstNode → Battery saver → No restrictions**
- **Settings → Apps → FirstNode → Autostart → enabled**
- **Settings → Apps → FirstNode → Other permissions → "Display pop-up windows
  while running in the background" and "Show on Lock screen"** (exact wording
  varies by MIUI/HyperOS version)

These are device settings, not something fixable in code — worth checking if
either symptom persists after this update.

#### Verified
- `flutter analyze` → **No issues found** (Dart-only; doesn't check Kotlin).
- `flutter build apk --debug` → succeeds, confirming the native Kotlin change
  compiles correctly.
- **Not yet verified on-device** — this fix specifically needs testing with the
  phone genuinely locked (screen off, not just backgrounded) through an actual
  alarm firing, since that's precisely the state the bug only showed up in.

### 2026-07-27 — Feature: Post-Alarm Reminder

Many people dismiss an alarm and go straight back to sleep. This feature keeps
nudging after dismissal until the user *actively confirms* they're awake by
tapping a reminder notification. Per-alarm setting: on/off, interval (1 / 2 / 5
/ 10 / 15 / 30 minutes), and its own ringtone from the existing tone library.

#### The one hard requirement that drove the whole design

"Notifications continue until the user taps one" plus "works reliably even if
the app is running in the background." Between two nudges the app can be
backgrounded, killed by the OS, or swiped out of recents — so **nothing in the
repeating loop may depend on Dart running**. Anything scheduled from Dart, or
that needs Dart to schedule its successor, breaks the chain the first time the
process goes away, which is precisely the situation the feature exists for.

#### Why not reuse the `alarm` package for the nudges

That was the obvious first idea — it already fires at an exact time with the app
killed, plays our tones, vibrates, and shows a notification. Three things ruled
it out:

1. **No way to detect a tap.** Its notification's content intent is the plain
   launcher intent with no extras, so from Dart "the user tapped the reminder"
   is indistinguishable from "the user opened the app." The spec is explicit
   that only a tap acknowledges — swiping away or ignoring must not — so
   guessing from app-resume wasn't good enough.
2. **Its ringing model is the wrong shape.** One alarm rings at a time and must
   be explicitly stopped; `AlarmService` refuses a new alarm while
   `ringingAlarmIds` is non-empty (`allowAlarmOverlap` defaults to false) and
   *unsaves* it. A nudge nobody stops would therefore silently swallow the next
   nudge — the exact failure mode the feature can't have.
3. **Chaining would still need Dart** to schedule occurrence N+1 when N fires.

`flutter_local_notifications` was the other candidate, and it *does* report taps
cleanly — but a notification channel bakes in its sound at creation and can
never change it, and channel sounds must be `res/raw` resources or content URIs.
Our tones are Flutter assets plus arbitrary user-imported files, so "pick a
reminder ringtone" would have been unimplementable after first run.

#### The design: the chain lives in native code

`android/app/src/main/kotlin/com/firstnode/firstnode/reminder/`

| File | Role |
| --- | --- |
| `ReminderStore.kt` | The one active chain (alarm id, label, interval, tone path, volume) + a pending acknowledgement, in its own `SharedPreferences` file. |
| `ReminderScheduler.kt` | Arms the next nudge with `AlarmManager`; cancels; re-arms after boot. |
| `ReminderReceiver.kt` | One tick: arm the follow-up, post the notification, start the sound service. |
| `ReminderSoundService.kt` | Short-lived foreground service that plays the tone once and vibrates. |
| `ReminderNotifier.kt` | The channel and the notification, including the tap → acknowledge intent. |
| `ReminderBridge.kt` | `MethodChannel` (`firstnode/post_alarm_reminder`) + handling of the tap intent. |

Only **one** alarm is pending at a time; the receiver arms the following one
*before* doing anything else, so a nudge that fails to show or sound can't end
the chain. Dart decides *whether* a chain runs; Android runs it.

#### Android details worth remembering

- **`setAlarmClock`, not `setExactAndAllowWhileIdle`.** Doze throttles the
  latter to roughly one firing per nine minutes per app, which would quietly
  turn "every 1/2/5 minutes" into "every ~9 minutes" for exactly our scenario —
  phone face-down, screen off, user back asleep. `setAlarmClock` is exempt and
  never rate-limited. The cost is the system's next-alarm indicator showing the
  upcoming nudge, which for an alarm clock app is honest rather than surprising.
  (Note this differs from the `alarm` package, which uses
  `setExactAndAllowWhileIdle` — fine for a once-a-day alarm, not for a
  one-minute loop.)
- **The tap goes straight to `MainActivity`**, not through a receiver that then
  starts it: Android 12+ bans that "notification trampoline". The
  acknowledgement is recorded in `MainActivity.onCreate` *before* `super`, so it
  lands even if the Flutter engine never finishes starting. Dart picks it up
  later via `consumeAck` (which clears it, so the confirmation shows exactly
  once whether the app was already open or cold-started by the tap).
- **The notification is deliberately *not* `ongoing`** and has no delete intent,
  so it can be swiped away — and swiping it is not an acknowledgement.
- **`STOP_FOREGROUND_DETACH`** when the tone finishes, so the notification
  survives the service and stays in the shade to be tapped much later.
- **The channel is silent and vibration-free**; the service plays the tone and
  vibrates itself. That's what makes a *changeable* per-alarm ringtone possible
  at all (see above), and it lets us skip vibration when the ringer is silent.
- **Tone paths** reuse the two shapes `Song.asset` already has: a Flutter asset
  key (`assets/sounds/x.wav` → `flutter_assets/…` via `AssetManager.openFd`) or
  an absolute path for imported files — the same mapping the `alarm` package
  applies to `assetAudioPath`, so bundled and imported tones both just work.
- **Boot**: `SafeBootRescheduleReceiver` re-arms an unacknowledged chain. Unlike
  the alarms it guards, there's no stale-time hazard — a reminder has no correct
  wall-clock time, only "keep asking every N minutes."

#### Lightweight on purpose

The tone plays **once** per nudge (not looped until stopped), capped at 30
seconds so a long imported song can't drone on, at the alarm's own volume, with
one short vibration. No ring screen, no puzzles. `USAGE_ALARM` though, not the
notification stream — a reminder nobody hears because the phone is on silent
would defeat the point.

#### Dart side

- `models/alarm.dart` — new `PostAlarmReminder` (enabled / intervalMinutes /
  songName) on `Alarm`, with `clone`/JSON. Saves that predate the feature have
  no `reminder` key and default to off.
- `services/post_alarm_reminder.dart` — the channel client, plus
  `resolveReminderTone()`: the reminder's own tone if set, else the alarm's
  (Specific mode) or its pool's first tone (Random/Pools — a nudge plays one
  tone once, so there's nothing to shuffle), else the first bundled tone. The
  reminder can never end up silent.
- `main.dart` — the chain starts by watching the **`Alarm.ringing` stream for an
  alarm leaving the set**, not off the Dismiss button. That way it also starts
  when the alarm is stopped from its notification's Stop button, which never
  reaches `_dismissReal`. Also: acknowledgement is consumed on resume *and* at
  startup (a cold start from a tap never fires a lifecycle change), a chain is
  cancelled if its alarm is deleted or has its reminder switched off mid-chain,
  and a newly ringing alarm supersedes any chain still running.
- `screens/edit_alarm_screen.dart` — new section after "Puzzles to dismiss",
  matching the order the user experiences: ring → dismiss → reminders. Turning
  it on pre-fills the tone with whatever the alarm itself would play, so the row
  is never blank. The song picker and preview button are reused as-is; the
  selected-tone card was factored out of Specific mode into a shared `_toneCard`
  rather than duplicated.

#### Verified
- `flutter analyze` → **No issues found** (Dart-only; doesn't check Kotlin).
- `flutter test` → **11 tests pass**, including a new
  `test/post_alarm_reminder_test.dart` covering the JSON round trip, the
  pre-feature default, `clone` being a deep copy (so Cancel discards reminder
  edits), and every `resolveReminderTone` fallback branch.
- `flutter build apk --debug` → succeeds, confirming the six new Kotlin files
  compile.
- **Not yet verified on-device** — no Android device was attached this session
  (`flutter devices` showed only Windows/Chrome/Edge). The whole chain is native
  and time-based, so it needs a real device: dismiss an alarm with the reminder
  on, confirm the nudge arrives on schedule with the chosen tone, confirm
  swiping it away still produces the next one, and confirm tapping it opens the
  app and ends the chain. Worth testing with the app swiped out of recents too,
  since that's the case the native design exists for — and on this Xiaomi/POCO
  device, with the MIUI/HyperOS autostart and battery settings noted in the
  previous entry.

### 2026-07-27 — Feature: manual pool ordering + frozen songs

Two related additions to pool playback, both from the notes in `TODO.md`:
songs can be dragged into any order, and Shuffle can be told to leave the first
few of them alone. So "always open with this one, surprise me after that."

#### Mapping the request onto what already existed

The request talks about "Sequential Mode" and "Random Pool Mode". In this app
those are one pool setting, not two modes:

| Request | This app |
| --- | --- |
| Sequential playback | `SoundMode.pool` + `PoolOrder.linear` |
| Random Pool playback | `SoundMode.pool` + `PoolOrder.shuffle` |

Note there is also a separate `SoundMode.random`, which picks **one** song from
the pool and loops it. Frozen songs deliberately don't apply there: with a single
song there is no order to preserve, and "freeze first 1" would turn Random mode
into "always play the same song" — the opposite of what it's for. The request's
own wording ("each song appears only once before repeating", and its six-song
worked example) is about a sequence, which is the `SoundMode.pool` path.

#### One pure function decides the order

`resolvePlayOrder(pool, {random})` in [lib/models/pool.dart](lib/models/pool.dart):

```dart
if (pool.order == PoolOrder.linear) return songs;   // the arrangement, exactly
final tail = songs.sublist(frozen)..shuffle(random);
return [...songs.take(frozen), ...tail];
```

Always a permutation of `pool.songs`, so every song still plays once before any
repeat. `AudioService.playPool` now calls it instead of shuffling inline, which
means the interesting logic is a pure function with no audio plugin attached —
`random` is injectable, so the tests pin the behavior down across 25 seeds
rather than hoping one shuffle happens to be revealing.

`Pool.frozenCount` is stored, with `effectiveFrozenCount` clamping it to the
number of songs actually in the pool: a count chosen when the pool had six songs
must not misbehave after four are deleted. The editor also clamps the stored
value on removal so the pills on screen match. Pools saved before this feature
have no `frozenCount` key and default to 0 — identical shuffle behavior to before.

**Left alone deliberately:** the order is still decided once when ringing starts
and then loops, rather than being re-shuffled on each pass. The request asked to
maintain the existing random behavior, and it already satisfies "each song once
before repeating."

#### Drag-and-drop: sliver list, not a nested one

The editor was a single `ListView` holding the name field, order control and
song cards. Putting a `ReorderableListView` inside it would have meant a nested
scrollable with `shrinkWrap` — two scroll positions, and dragging a song toward
the screen edge wouldn't scroll the form.

Instead the screen is now one `CustomScrollView`: `SliverList` for the form
above, `SliverReorderableList` for the songs, `SliverToBoxAdapter` for the
delete link. One scroll position, so dragging past the top or bottom edge
auto-scrolls the whole form the way you'd expect.

Details that mattered:
- **`onReorderItem`, not `onReorder`.** The latter is deprecated as of
  v3.41.0-0.0.pre and hands you a "gap" index that needs a manual `-= 1` when
  moving a song downward. `onReorderItem` gives the final index, so the handler
  is just `insert(newIndex, removeAt(oldIndex))`.
- **`ObjectKey(song)` for item keys**, not the index. A pool can legitimately
  contain the same song twice, so the name isn't unique — but the `PoolSong`
  instances are, and reordering only moves those instances around.
- **The expanded card is tracked by identity, not index.** `_expandedIndex` would
  have pointed at a different song after a drag; it's now `PoolSong? _expanded`.
- **Item spacing lives inside each item.** A reorderable list has no room for
  separators between children, so the 8px gap moved into the item's `Padding`.

#### A bug the widget test caught

`SliverReorderableList` renders the card you're dragging in an **overlay**, which
sits outside the `Scaffold` and therefore has no `Material` ancestor. Picking up
a card whose trim/volume sliders were open threw `No Material widget found` —
`Slider` insists on a Material to draw its ink on. Fixed with a `proxyDecorator`
that wraps the lifted card in `Material(type: MaterialType.transparency)`, which
supplies the ancestor without altering how the card looks.

Worth noting because nothing about the feature request hints at it, and it only
fires in the specific combination "expand a song, then drag that same song."

#### Testing drag gestures, for next time

Two traps, both of which cost real time here:
1. **Move the pointer in small steps.** A reorderable list recalculates the drop
   slot on each pointer move, against geometry that is mid-animation. Teleporting
   with a single `moveBy` evaluates that logic once against unshifted geometry and
   lands in states a real finger never reaches — a sweep of drag distances gave
   "no move" at exactly one row, "two places" at 1.6 rows, and "one place" at 2.
   Twenty small steps gives the correct result in every direction.
2. **Measure travel from the drag handles**, not from an assumed row height. The
   moment one card is expanded the rows aren't uniform, and a height measured
   between two titles is the *expanded* card's height.

Also: the test view is sized 1000×2400, because a sliver list doesn't build
off-screen children and the song cards would otherwise be unfindable.

#### UI
- **Pool editor** — a drag handle on each song card; a `FROZEN SONGS` row of
  None / First 1…5 pills, shown only for Shuffle (linear has nothing to hold in
  place) and offering at most one option per song in the pool. Frozen songs are
  marked `· frozen` on their own card, so which songs are pinned is visible
  rather than something you have to work out from a number.
- **Pool list** — the summary line now reads `6 songs · shuffle · 2 frozen`, with
  the frozen part shown only when it affects playback (and `1 song` no longer
  reads `1 songs`).
- **Edit alarm** — the Pools-mode hint now says Linear follows the order you
  arranged and Shuffle keeps frozen songs first.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → **34 tests pass**, 19 of them new:
  `test/pool_play_order_test.dart` (frozen head preserved and tail permuted
  across 25 seeds, no duplicates, linear untouched, freezing everything, a stale
  count clamped, empty pool, the input pool not mutated, JSON round trip
  including a reorder, pre-feature default, summaries) and
  `test/pool_editor_screen_test.dart` (drags down one / down to the end / to the
  top, a reorder feeding the frozen selection, the pills, Shuffle-only
  visibility, clamping on removal, and the expanded-card case that found the
  Material bug).
- `flutter build apk --debug` → succeeds.
- **Not yet verified on-device** — still no Android device attached. What needs a
  real device is the feel of the drag gesture (handle size, auto-scroll speed
  while dragging near the edges) and hearing a frozen shuffle actually ring.

### 2026-07-28 — Feature: Settings page, Library management, and a pass of confirmation dialogs

Until now the app had exactly one entry point — Home — and everything else
(songs, pools) was only reachable as a side-effect of editing a specific
alarm. This adds a real Settings page, turns song import from
one-file-at-a-time into a proper batch operation, gives pools a multi-select
"add songs" flow instead of tap-one-repeat, and — the change with the biggest
correctness impact — adds confirmation dialogs before every destructive
action, since none existed anywhere in the app before this.

A full UX audit was written first, at [UX_AUDIT.md](UX_AUDIT.md) — it's a
standing document (unlike this log) covering pain points across every area in
the brief (navigation, empty states, accessibility, Play Store readiness,
etc.) and what's deliberately *not* fixed yet (a real app icon and release
signing keystore both need developer-supplied material this pass doesn't
have).

#### Navigation
A gear icon now sits at the top-left of Home (`lib/screens/home_screen.dart`),
opening a new `SettingsScreen` with Library / Pools / General sections. Every
row in it reuses a screen that already existed or was built for this pass —
Settings is a router, not a new UI system. `PoolPickerScreen` gained a
`selectable` flag: false when opened from Settings' "Manage Pools" so a row
tap opens the pool for editing (there's nothing to "select" for outside an
alarm), true everywhere else, unchanged.

#### Multi-file import + real duplicate detection
`SongImportService.importFromDevice()` (one file) is now
`pickAndImport()` (`FilePicker.pickFiles(..., allowMultiple: true)`),
returning an `ImportBatchResult { imported, duplicates, failed }`. A picked
file is skipped as a duplicate if its name+size already matches a song in the
library *or* another file earlier in the same batch — `PlatformFile.size`
comes free from the picker, so this costs no extra I/O per skipped file.
`Song` gained `dateAdded`/`originalFileName`/`sizeBytes` to back this (all
default to 0/null for bundled tones and pre-existing imports, so old saved
data still loads). One bad file no longer aborts the batch — errors are
caught per-file and rolled into the summary instead.

Both import entry points (`SongPickerScreen`'s row, and the new Library
screen) share this one method and the same `ImportProgressDialog` (added to
`app_widgets.dart`) — a non-dismissible "Importing N of M — filename" dialog
driven by a `ValueNotifier`.

#### Library screen (`lib/screens/library_screen.dart`, new)
Lists built-in tones (read-only, tagged) and imported songs (deletable)
separately, with search, a sort menu (name / date added / duration), and a
running count. Deleting an imported song calls the new
`AppState.songUsage(name)` first, which scans every alarm's `songName` and
every pool's song list — if it's in use, the confirm dialog says exactly
where ("Used by 2 alarms and 1 pool…") before letting the delete proceed.
`AppState.removeCustomSong` deletes the file off disk as well as the list
entry. `addCustomSong` became `addCustomSongs` (a batch), since one import can
now produce several songs at once.

#### Pool multi-select add
`SongPickerScreen`'s `poolAdd` mode changed from "tap a row, it's added
immediately, picker stays open" to real checkboxes plus a bottom "Add N
songs" button that commits the whole selection in one `onAdd(List<String>)`
call. `PoolEditorScreen._addSong` now does one `setState` for the whole batch
and shows one "Added N songs" toast instead of one per song.

#### Confirmation dialogs, everywhere they were missing
One shared `showConfirmDialog()` (`app_widgets.dart`) — Cancel/Confirm,
destructive actions render the confirm label in red. Wired into: delete
alarm (`edit_alarm_screen.dart` — previously a bare text link, no
confirmation at all), delete pool, remove a song from a pool, and delete a
library song. `test/pool_editor_screen_test.dart`'s song-removal test now taps
through the dialog it previously didn't need to.

#### Empty states
A shared `EmptyState` widget (icon + message + optional call-to-action)
replaced the inline `Text`-only empty states on Home, the pool list, and the
pool editor's song list, and backs the two new empty states in Library ("no
imported songs yet" and "no songs match your search").

#### Left alone deliberately
- The spec's "Edit Pool" settings row isn't a separate screen — editing
  requires picking a pool first, so it's the same destination as "Manage
  Pools." Adding a second row to the same place would just be a second way to
  find one thing.
- "Application Settings" only got an About/version row (via the new
  `package_info_plus` dependency) — there's no app-level preference (theme,
  locale, etc.) to expose yet, so the section stays honest rather than
  shipping toggles that don't do anything.
- A full accessibility sweep of *pre-existing* small tap targets (the pool
  song "×", the preview button, the back chevron) wasn't done here — it's a
  large, unrelated, cross-cutting diff, and is flagged as a follow-up in
  `UX_AUDIT.md` instead of folded into this change.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → **34 tests pass** (including the updated pool-removal test).
- **Not yet verified on-device** — no Android device attached this session.
  What still needs a real device: the multi-file picker's actual OS UI,
  import progress timing on a real filesystem, and the new checkbox/dialog
  touch targets.

---

### 2026-07-28 — Bug fix: Alarm playback stops when song ends + Puzzle difficulty redesign + Practice mode

#### Problem: alarm playback duration

The alarm could stop playing when the audio file reached its natural end,
even though the user hadn't dismissed or solved the puzzles. Root cause:
for `SoundMode.specific` and `SoundMode.random`, audio was delegated
entirely to the native `alarm` package's foreground service with
`loopAudio: true`, and Dart had no fallback. If the native loop failed
(e.g., for imported device files on certain Android versions), playback
simply stopped.

**Fix**: Dart now drives audio playback for ALL sound modes, not just pool
mode. The native alarm side always plays the silent placeholder
(`kSilentPlaceholderAsset`) to keep the foreground service alive, while
`AudioService` handles all audible output.

Changes:
- `alarm_scheduler.dart` — `_assetFor()` replaced with a simple `_asset`
  getter that always returns the silent placeholder. Removed the
  `_findPool` helper (no longer needed).
- `main.dart` — `_onRing()` now always passes `playInApp: true` to
  both `RingingScreen` and `PuzzleSolveScreen`. Removed the
  `needsDartPlayback` variable.
- `audio_service.dart` — Added `_alarmLoopActive`/`_alarmLoopSong`
  tracking so `onPlayerComplete` can force-replay the song if
  `ReleaseMode.loop` fails (safety net). Updated `_play()` to accept
  optional `startSec`/`endSec` for trim-within-loop (seeks back to
  `startSec` when position reaches `endSec`). All cleanup paths
  (`stop`, `dispose`, `playPool`, `preview`) now clear alarm-loop state.
- `playForAlarm()` for specific mode now passes the alarm's trim range
  (`alarm.start`, `alarm.end`) to `_play`, giving Dart-driven trim
  support that the native side never had.

#### Problem: puzzle difficulty levels feel identical

Easy, Medium, and Hard generated nearly identical equations. The old
generator picked random terms and operators from a flat pool — the only
difference between levels was which operators were available (`+/-` vs
`+/-/×/÷` vs `+/-/×/÷/^`), and evaluation was strictly left-to-right
(no order of operations, no brackets).

**Fix**: Complete rewrite of `puzzle_engine.dart`'s `buildQuestion()` with
a template-based generator. Each difficulty level uses structurally
different expression templates:

- **Easy** (2 terms): `a + b` or `a − b`, numbers 1-50.
- **Medium** (2-3 terms, gated by `variables` setting): `a × b`,
  `a ÷ b`, `a + b × c`, `a × b − c`, etc. Proper order of operations —
  the displayed expression and the expected answer follow PEMDAS.
  Division is clean by construction (generate quotient and divisor,
  multiply to get dividend). Subtraction results are always non-negative.
- **Hard** (3-4 terms, gated by `variables` setting): Brackets and
  multi-step calculations: `(a + b) × c`, `a ÷ (b + c)`,
  `(a + b) × (c + d)`, `a × (b − c) + d`, etc. Answers are always
  integers and non-negative.

Exponents were removed — the user's difficulty spec doesn't include them,
and they weren't producing obviously harder puzzles.

Updated `puzzle_math_screen.dart`'s description text to reflect the new
levels: "Easy: simple addition and subtraction. Medium: adds
multiplication and division with order of operations. Hard: adds
brackets and multi-step calculations."

#### Feature: shuffle mixed-difficulty puzzle queue

`resolveQueue()` now calls `queue.shuffle(_rng)` after building the full
list. When multiple difficulties are selected (e.g., 3 easy + 2 medium +
1 hard), the puzzles are interleaved randomly rather than grouped by
level. Rewrite puzzles are shuffled in too.

#### Feature: puzzle practice mode

Users can now test their puzzle configuration without triggering a real
alarm. Added a "Test Puzzles" button to the edit alarm screen's puzzle
section (visible only when at least one puzzle is configured).

Changes:
- `puzzle_solve_screen.dart` — Added `isPractice` flag. When true: no
  audio plays, back navigation is allowed, and completing all puzzles
  shows a "Practice complete!" dialog with the count instead of calling
  `onStop`.
- `edit_alarm_screen.dart` — Added `_practicePuzzles()` method that
  generates a queue from the current draft's puzzle config and pushes
  `PuzzleSolveScreen` in practice mode. Shows a snackbar if no puzzles
  are configured. Added imports for `puzzle_engine.dart` and
  `puzzle_solve_screen.dart`.

#### Puzzle generation review (Task 5)

Reviewed the system for long-term maintainability:
- **Template variety**: 2 easy + 7 medium + 8 hard = 17 distinct
  expression shapes. Each template generates random terms within
  difficulty-appropriate ranges, so repetition across puzzles is low.
- **Correctness**: Every template computes the answer by construction
  (no parsing/evaluation step that could disagree with the displayed
  expression). Division dividends are generated as `divisor × quotient`,
  so division is always clean. Subtraction templates ensure
  non-negative results.
- **Scalability**: Adding a new template is one `case` in the
  `_tryMedium`/`_tryHard` switch — no changes to the rest of the engine.
  Adding a new difficulty level would require a new `_build*` method and
  a new case in `buildQuestion`.
- **Future puzzle types**: The sealed `PuzzleStep` hierarchy makes
  adding new types straightforward (the compiler forces handling in the
  solve screen's `switch`).
- **What's not done**: no timer/speed tracking for practice sessions,
  no per-difficulty statistics, no "wrong attempt" penalty. These are
  reasonable future additions but not needed for the current UX.

#### Verified
- `flutter analyze` → **No issues found.**
- `flutter test` → **34 tests pass.**
- **Not yet verified on-device** — no emulator attached. What needs a
  real device: the Dart-driven playback for specific/random modes
  (confirm it loops correctly and respects trim), and the practice mode
  completion dialog.

_(further entries appended below as each piece is built)_
