# FirstNode — UX Audit & Improvement Plan

> A snapshot of the app's UX as of 2026-07-28, written before implementing the
> Settings/Library/Pool-management redesign. Unlike `DEVLOG.md` (a log of *what
> was built and why*, growing forever), this is a standing review document —
> update it if a future pass changes the picture significantly, rather than
> appending to it indefinitely.

---

## 1. How the app looks today

One screen (Home) with no menu, no settings, and no way to manage songs or
pools except by drilling into an alarm's "Sound" section. Every other screen is
reached only as a sub-step of creating/editing an alarm. There are 9 screens
total; all share `BackHeader`/`EditHeader` navigation chrome, which is a real
strength — the app already has visual and structural consistency to build on.

## 2. Pain points found, by area

**Navigation flow / discoverability**
- No entry point exists for anything except "add/edit an alarm." Managing your
  song library or pools independently of a specific alarm is impossible today —
  you'd have to start creating a throwaway alarm just to reach the song/pool
  pickers.
- Nothing on Home hints that pools or a music library are concepts at all,
  until you're deep inside "Edit alarm → Sound → Pools."

**Library management**
- `SongPickerScreen`'s "Import from device" only accepts one file
  (`FilePicker.pickFiles` without `allowMultiple`), so importing 10 songs is 10
  repetitions of open-picker → pick-one → wait → repeat.
- There is no screen that just lists your imported songs. You can add one (via
  a picker meant for something else) but can never see them all together,
  search, sort, or delete one.
- Imported songs can never be deleted or renamed — once imported, forever
  imported (until the app's data is wiped).

**Pool management**
- Adding songs to a pool is "tap a row, it's added, repeat" inside a picker
  that has to stay open across multiple taps — there's no way to see what
  you've already picked before committing, no way to select 5 songs and add
  them all at once, and no undo besides deleting them back out of the pool
  afterward.
- The pool editor's empty state is one line of grey text; there's no visual
  invitation to add the first song.

**Alarm creation flow**
- Generally solid and consistent (time wheels → repeat → label → sound →
  volume → puzzles → reminder). No major pain points found here beyond what's
  shared with the rest of the app (no delete confirmation — see below).

**Empty states**
- Every empty state in the app (`home_screen.dart`, `pool_picker_screen.dart`,
  `pool_editor_screen.dart`) is an inline centered `Text` with no icon and no
  actionable next step beyond "look at the button elsewhere on screen."

**Loading states**
- Home has a spinner while `AppState` loads; no other screen needs one today
  since they're only reachable after Home has already loaded. This will change
  once Library/Settings become directly reachable, and once imports take real
  time (batch imports, larger files).

**Error handling**
- Single-file import failure just shows a generic "Couldn't import that file"
  toast — fine for one file, but with multi-file import a batch needs a real
  success/failure/duplicate summary, not one toast per file.

**Confirmation dialogs**
- None exist anywhere in the codebase. Deleting an alarm, deleting a pool, and
  removing a song from a pool all execute immediately on tap. This is the
  single biggest correctness/trust risk in the current UX — a mis-tap loses
  data with no recovery.

**Accessibility**
- Most tap targets are consistent with each other but several (the pool song
  "×" remove icon, the `PreviewButton`, the back chevron) are meaningfully
  under the ~44dp recommended minimum. Icon-only buttons throughout the app
  have no `Semantics`/`Tooltip` labels, so a screen reader user gets "button"
  with no description.
- Color contrast is generally fine (white text/icons on near-black, per
  `AppColors`), no issues found there.

**Visual consistency**
- Strong: one shared widget file (`app_widgets.dart`) is used everywhere, so
  cards, pills, headers, and buttons already look identical across screens.
  This redesign should keep using it rather than introducing new one-off
  styles.

**Onboarding**
- First launch seeds three sample alarms and one sample pool
  (`AppState._seed()`) so the app isn't empty, but there's no explanatory
  first-run tour or empty-state copy explaining what a "pool" even is the
  first time a new user encounters the concept.

**Performance**
- Nothing alarming found. `shared_preferences`-as-JSON-blob is fine at the
  current data scale (a handful of alarms/pools/songs); it would not scale to
  hundreds of imported songs, but that's far outside today's usage pattern.

**Google Play Store readiness**
- The release build still signs with the **debug keystore**
  (`android/app/build.gradle.kts` — flagged in-file as a TODO). This must be
  replaced with a real upload keystore before any Play Store submission; doing
  so requires a keystore file and credentials only the developer can generate,
  so it's out of scope for this pass and called out here instead.
- The app icon is still the **default Flutter template icon** at every
  density (`android/app/src/main/res/mipmap-*/ic_launcher.png`) — needs a real
  app icon and (ideally) the `flutter_launcher_icons` package before store
  submission. Also out of scope here for the same reason (needs real artwork).
- No privacy policy / data-safety declaration prepared yet (the app stores
  everything locally and requests no network permissions, which makes this an
  easy form to fill out later, but it hasn't been done).

## 3. Proposed improvements (this pass)

- Add a Settings entry point (gear icon, top-left of Home) leading to a
  central Settings page with Library, Pools, and General sections.
- Replace single-file import with real multi-file import: multi-select
  picker, per-file progress, and a success/duplicate/failure summary.
- Add a dedicated Library screen: search, sort (name/date added/duration),
  song count, delete (with usage-aware confirmation), empty states.
- Replace pool "tap-one-at-a-time" adding with a checkbox multi-select flow
  that adds everything selected in one action.
- Add one shared confirmation-dialog component and wire it into every
  destructive action: delete alarm, delete pool, remove song from pool, delete
  library song.
- Add a shared empty-state component (icon + message + call-to-action) and use
  it everywhere an empty list is shown today.
- Add `Semantics`/`Tooltip` labels and ≥44dp hit targets to every *newly
  added* icon-only control (gear icon, delete icons, checkboxes). A full pass
  over every pre-existing small tap target is listed below as a follow-up,
  not done now — it's a large, unrelated, cross-cutting diff better done as
  its own change.

## 4. Prioritized plan

### Quick wins (small diff, high value — do first)
1. Shared confirm-dialog component + wire into existing delete actions
   (alarm, pool, pool-song).
2. Shared empty-state component, swapped into the three existing inline
   empty states.
3. Settings entry point + page shell (even before Library/Pool content is
   fully built out, this immediately fixes the "nothing is discoverable"
   problem).

### Larger enhancements (this pass, more surface area)
4. Multi-file import + import-progress/summary UI.
5. Dedicated Library screen (search/sort/count/delete).
6. Pool multi-select add flow.

### Follow-up (flagged, not in this pass)
- Full accessibility sweep of pre-existing tap targets across all 9 screens.
- Real app icon + release signing keystore (needs developer-supplied
  artwork/credentials) before Play Store submission.
- Privacy policy / Play Console data-safety form.
- First-run onboarding tour explaining alarms/pools/puzzles to a brand-new
  user (currently only seeded sample data does this job, implicitly).
