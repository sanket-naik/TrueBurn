# TrueBurn — Flutter (Android, iOS)

## Icon

A flame over a short rule: the flame says *calories* with no explanation needed, and the
rule says the burn is measured from a baseline. The rule sits outside the shape
deliberately — a bar across the flame reads as a prohibition slash.

Two attempts were discarded. An abstract "scattered weigh-ins with a trend line through
them" was distinctive but cryptic: a descending line with dots is equally a stock chart,
a route, or a network graph. The first flame then came out as a **water droplet** — too
blunt a tip, too symmetric — which is worse than generic in an app that also tracks
water. The sharp leaning tip plus the punched-out inner core is what makes the shape
unmistakably fire.

`lib/splash.dart` redraws the same bezier geometry in Dart, so the launcher icon and the
launch screen cannot drift apart.

Regenerate with `python3 tool/gen_icons.py` — see **Icons** below.

## Naming

Shipping name is **TrueBurn**. Both platforms use `com.funnudge.trueburn` — Android's
`applicationId` and namespace, and the iOS bundle identifier — matching the studio
domain. They were briefly split (`com.sanketnaik` on Android, `com.funnudge` on iOS)
and were aligned deliberately rather than left to drift, because Play's `applicationId`
is permanent the moment a build reaches it.

Renaming Android touched the Gradle namespace, the `applicationId`, and the Kotlin
package plus its directory. It did **not** touch the manifest: `.MainActivity` is
relative to the namespace and the three notification receivers are absolute
`com.dexterous.*` names, which is the only reason this was a safe rename — a half-done
one breaks those receivers silently.

Studio credit on the splash is **FunNudge** (capital F, capital N, matching funnudge.com).

## Status

Engine ported and proven. Both screens, all sheets, persistence and theming are built,
and **it runs** — verified on an Android 15 emulator (Pixel 7, arm64). Notifications are
wired and verified end to end (below). iOS is scaffolded and configured but has never
been compiled — Xcode is not installed on this machine.

Two bugs only showed up once it was on a screen, which is the argument for running it
early rather than trusting a green analyzer:

- `WaterWave` used `SingleTickerProviderStateMixin` while creating **two** controllers
  (wave phase and level easing). Compiles, analyzes, builds — throws a red screen at
  runtime. Needs the plural mixin.
- At 0% fill the wave painted nothing, so the water card was a flat grey rectangle in
  the exact state every user sees on their first run. It now always draws a shallow
  band, damped at low fill.

```
mobile/
  lib/core/       the engine, pure Dart — no Flutter imports, no clock, no I/O
  lib/domain/     routines, foods, clock, the Today ⇄ Routines sync rules — pure
  lib/widgets/    primitives, the CustomPainter charts, the week grid
  lib/screens/    Today, Routines
  lib/sheets/     food picker, weigh-in, routine editor, settings, history
  lib/store.dart  state + local persistence
  tool/           RNG + convergence harness
  test/           domain + engine tests
```

`lib/core/` and `lib/domain/` never import Flutter. That is what keeps them provable
without a device, and it is the same discipline that made the TypeScript original
testable.

## Verify

```bash
flutter analyze          # clean
flutter test             # 68 tests
dart run tool/sim.dart   # the port's proof, below
dart run tool/bench.dart # engine cost per frame
flutter build apk --debug
```

## How the port was proven

A translation that "looks right" is worth nothing. Checked in two steps:

**1. The RNG first.** `mulberry32` depends on JS `Math.imul` and `>>>` semantics that
Dart does not share — its ints are 64-bit. If the RNG drifted, every downstream number
would differ for reasons unrelated to the engine, and a faithful port would be
indistinguishable from a broken one. Verified identical to 17 decimal places before
anything else was trusted.

**2. Then the whole simulation** — 6 people × 24 seeds × 120 days × 2 coaches:

```bash
# from the repo root
N='true TDEE|goal |TrueBurn |formula-only |drifted'
diff <(npx tsx src/sim/run.ts | grep -E "$N") \
     <(cd mobile && dart run tool/sim.dart | grep -E "$N")
```

Currently **identical** — all 31 numeric lines: every scenario, both coaches, p10–p90
spreads, floor-binding percentages, and the drifting true TDEE. That reproduces
REQUIREMENTS §10 exactly.

The filter matters. An earlier version of this diff matched only the two result rows,
which meant the six drift figures were never compared and the Dart harness was not even
printing them — a parity check is only as strong as what both sides put on stdout. If
one harness gains a line, give the other the same line rather than narrowing the filter.

Keep this diff green. It is the only thing standing between a working engine and a
plausible-looking one.

## Built

- Adaptive TDEE via `dailyReport` — the UI never reimplements any of the maths
- **Today**: first-run welcome, energy readout with the three-mode chip, cold-start
  progress card, weight trend with Month/Quarter/Year, meal-grouped intake, animated
  water fill with two-tap add
- **Routines**: seven-day adherence grid, per-routine pips, tick/pause, starter
  templates, pause-all
- **First-launch tour**: four pages, skippable from any of them, shown once. It exists
  because the central idea is invisible from the UI — without it the app looks like a
  plainer version of what people already have
- **210 foods**, natural units by default and grams where the food is weighed. A test
  asserts no duplicate names: a duplicate splits one food's history across two
  identical-looking rows, so portion memory and meal habits each learn half of it
- **Drift detection**: when measured burn falls 18% below the formula, Today says so —
  the one reading no food diary can produce, because it needs both figures (§4.2b)
- **Portion memory**: a food opens at the quantity you usually log it at, and the list
  leads with what you actually eat at *this* meal rather than what you ate last
- **Repeat last meal**: one tap re-logs yesterday's breakfast, the commonest wasted
  minute in the app
- **Weigh-in sanity check**: an entry more than 3 kg from the trend asks before it
  joins — weight is the input everything derives from, and nothing downstream ever
  looks obviously wrong after a slipped digit
- **History**: opened by tapping the date on Today. Range summary over 7 or 30 days,
  predicted-vs-actual, and a day list that opens one day in detail
- Sheets: food picker (grouped, quantity projection, reusable custom foods), weigh-in
  with live trend preview, routine editor with coverage warning, settings
- Local persistence via `shared_preferences`; no account, nothing uploaded
- Light / dark / auto, with auto genuinely following the OS
- Day rollover on resume, so yesterday's ticks do not read as today's

## iOS

**Builds and runs.** Verified on an iPhone 17 simulator (iOS 26.5, Xcode 26.6): first
compile clean in 153s, app launches, first-run screen renders, and the launch storyboard
resolves its ground colour in both appearances (`#F6F8F7` light, `#0E1513` dark). The
notification permission prompt appears on first launch, which is the Darwin init path
doing its job.

Not yet verified: **Done from the lock screen**, which is the one that matters most and
the one that fails silently. It needs tap input on the device — see "Still to check".

`lib/core/` and `lib/domain/` need no work at all: they are pure Dart with no platform
imports, which is the whole reason they were written that way. The platform work is
notifications, icons, and the launch screen.

### Setting this up from scratch

Xcode from the App Store, then **tick iOS in the Components step** — installing Xcode
alone gives you SDK stubs but not the platform, and the build fails with
`iOS 26.5 is not installed` long after you thought you were done. If you skipped it:

```bash
xcodebuild -downloadPlatform iOS
```

That needs no password and is the same download as the Components pane. It may end with
`Error: Duplicate of <uuid>` — that is harmless, it means one copy registered and a
second was redundant. Check with `xcrun simctl runtime list -v`; you want `State: Ready`.

CocoaPods via Homebrew, **not** `sudo gem install` — the system Ruby is 2.6 and that
route breaks on current macOS:

```bash
brew install cocoapods
```

**`pod` crashes on a non-UTF-8 locale** with
`Unicode Normalization not appropriate for ASCII-8BIT`. This machine is `en-IN`, so it
hits every time. Put this in `~/.zshrc`:

```bash
export LANG=en_US.UTF-8
```

Then, from `mobile/`:

```bash
flutter build ios --simulator --no-codesign   # generates the Podfile, runs pod install
flutter run
```

Signing is only needed for a physical device: open `ios/Runner.xcworkspace`, Runner →
Signing & Capabilities → Team. Bundle id is `com.funnudge.trueburn` on both platforms.

### The 64-notification cap

iOS refuses to hold more than **64** pending local notifications per app, and past that
it keeps the 64 that were *set last* — not the ones that fire soonest. No error, no
callback, no log entry. A single six-a-day water routine repeating weekly is already 42
requests, so two routines would quietly lose reminders in an unpredictable order.

Two things in `syncAll` keep this honest:

1. **Every-day routines collapse to one daily repeat** instead of seven weekly ones.
   Identical behaviour, a seventh of the requests. This is what makes realistic schedules
   fit, and it applies on Android too — fewer alarms there as well.
2. Whatever is left is scheduled **soonest-first** up to 60, leaving headroom, and the
   overflow count is exposed as `Notifications.droppedFromSchedule` rather than being
   discarded silently the way iOS would.

### The trap that matches Android's missing receivers

Android silently drops notifications when the plugin's broadcast receivers are not
declared. iOS has an exact counterpart: the Done action runs in a **separate background
isolate that starts with no plugins registered**. Without
`setPluginRegistrantCallback` in `AppDelegate.swift`, `shared_preferences` does not
exist in that isolate, the completion queue is never written, and every lock-screen tick
is lost — while the notification still appears and still dismisses, so it looks like the
feature works.

This project uses the `UIScene` lifecycle (there is a `SceneDelegate.swift`), so that
callback goes in `didInitializeImplicitFlutterEngine`, **not** in
`didFinishLaunchingWithOptions` as most of the documentation shows.

`UNUserNotificationCenter.current().delegate` is set in the same file, and is equally
load-bearing and equally quiet when missing.

### Actions

Android attaches action buttons to each notification. iOS registers them once against a
**category identifier** at init, and a notification whose category was never registered
shows no buttons — again with no error. The category is `ROUTINE`, declared in
`Notifications.init`, and every scheduled notification carries
`categoryIdentifier: categoryId`.

`DarwinNotificationAction.plain` is used without the `foreground` option on purpose: with
it, Done would open the app, which defeats the point.

### Still to check

- **Done from the lock screen reaching `drainPending`.** Proven on Android, unproven on
  iOS, and it is exactly the path that fails without a sound. Set a routine two minutes
  out, lock the device, tap Done, reopen
- Notification delivery under Low Power Mode, and on a real device rather than a
  simulator
- The App Store icon has no alpha channel (the generator strips it; upload will confirm)

## Icons

`tool/gen_icons.py` renders every size for both platforms from the bezier data in
`lib/splash.dart`. Previously no generator was checked in and the icons could only be
reproduced by hand.

```bash
python3 tool/gen_icons.py
```

It emits: the two Android splash marks (natural and v31-padded, light and night, five
densities each), the 19-entry iOS `AppIcon.appiconset` (opaque, no alpha — iOS rejects icons
with transparency at upload), Android legacy launcher icons, the adaptive foreground,
the white notification silhouette, iOS `LaunchImage` at 1x/2x/3x, and a 1024 master.

The adaptive foreground is sized against the **visible tile, not the safe zone** — these
are different measurements and confusing them is what made the Android icon look zoomed
next to the iOS one. The safe zone (66/108 = 0.611) is a *maximum*: cross it and a round
mask clips the corners. But the launcher only ever shows the inner 72dp, so the visible
tile is 72/108 = 0.667 of the canvas, and ink sized to 0.60 of the canvas fills 90% of
what the user actually sees.

At `scale_mark=0.65` the ink measures 0.472 of the canvas — **0.708 of the visible
tile, against iOS's 0.703**, so the two platforms finally match. Furthest ink from
centre is 0.531 against the 0.611 safe circle, verified per-pixel rather than by
bounding box, and checked against circle, squircle and rounded-square masks.

Edit `_MarkPainter` in `lib/splash.dart` and `OUTER`/`INNER` in the generator together —
the geometry is duplicated because nothing can rasterise a Flutter `CustomPainter`
headlessly.

## Permission timing

The notification permission is requested when the main UI first appears, **not** at
boot. Asking on the first frame — before the app has said what reminders are or why
they exist — is the reliable way to get denied, and a denial is close to permanent on
both platforms: the app cannot re-prompt, only send the user to Settings.

The tour's fourth page explains reminders; the ask lands immediately after it. Anyone
who skips still gets asked, on the first frame of a screen they recognise rather than a
splash. Nothing breaks on refusal — scheduling still succeeds, the notifications simply
do not display.

## Signing

`android/app/build.gradle.kts` reads `android/key.properties` when it exists and signs
release builds with it; when it does not, it falls back to the debug key and says so in
the build log. That fallback exists so `flutter run --release` works on a machine
without the keystore — **Play rejects debug-signed uploads**, and without the warning
that failure only surfaces at upload time, long after the build looked fine.

Generate the upload key once:

```bash
keytool -genkey -v -keystore ~/trueburn-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`:

```
storePassword=<the store password>
keyPassword=<the key password>
keyAlias=upload
storeFile=/Users/you/trueburn-upload.jks
```

`.gitignore` already excludes `key.properties`, `*.jks` and `*.keystore`. Keep it that
way: the upload key is the app's identity on Play, anyone holding it can publish as you,
and **losing it means you can never update the app again** — a new key is a new listing.
Back it up somewhere you will still have in five years.

Check what actually signed a build rather than assuming:

```bash
apksigner verify --print-certs app-arm64-v8a-release.apk | grep "certificate DN"
```

`CN=Android Debug` means the fallback was used. Anything else means the keystore was
picked up.

## The release build hangs on the splash if you strip one PNG

Worth its own section, because it is the worst failure this project has produced and it
is invisible until you run a release build.

`ic_notification` is referenced **only from Dart**, as the string literal
`'@drawable/ic_notification'` passed to `AndroidInitializationSettings`. No Kotlin and no
XML mentions it, so the release resource shrinker cannot see the reference and removes
the file — leaving the resource *id* in the table with no densities behind it.

The consequence is not a missing icon:

```
Unhandled Exception: PlatformException(invalid_icon,
  The resource @drawable/ic_notification could not be found...)
```

`initialize()` throws, the exception escapes `Notifications.init()`, `_boot` never
completes, and **the app sits on its splash screen forever**. No crash dialog, nothing in
the UI, debug entirely unaffected.

Two defences, both needed:

1. `android/app/src/main/res/raw/keep.xml` lists it under `tools:keep`. Anything else
   named from Dart must be added there too. **It needs a `flutter clean`** — stale merged
   resources will keep stripping it and make the fix look like it did not work.
2. `Notifications.init()` catches everything. Reminders are a feature; weight and food
   are the product. A tracker that cannot remind you is degraded, one that will not open
   is broken.

Do not verify this by grepping the APK for the filename. Release resources are renamed —
`ic_notification.png` becomes `res/hQ.png` — so a name search reports it missing even
when it is present. Read the resource table instead:

```bash
aapt2 dump resources app-arm64-v8a-release.apk | grep -A4 drawable/ic_notification
```

Densities listed under the id means it survived; the bare id alone means it was stripped.

## Notifications (Android)

Wired and **verified end to end on device**: reminder fires → Done tapped from the
notification with the app backgrounded → completion lands in state on reopen.

Four things had to be right, and three of them fail silently:

1. **Exact alarms.** Inexact carries a `window=+1h` on Android — verified in
   `dumpsys alarm` — which would let a 9 am reminder arrive at 9:55. `USE_EXACT_ALARM`
   is the permission Google designates for reminder apps; the core-function
   justification holds here, and Play review expects it.
2. **The plugin declares no receivers of its own.** v22 ships a manifest containing only
   permissions, so the app must declare `ScheduledNotificationReceiver`,
   `ActionBroadcastReceiver` and `ScheduledNotificationBootReceiver` itself. Without
   them the alarm fires and nothing listens: no notification, no crash, no log entry.
3. **Core library desugaring** must be enabled or the build fails outright (this one at
   least is loud).
4. **`prefs.reload()` before draining the queue.** A lock-screen tap runs in a separate
   isolate, and `shared_preferences` caches per isolate — so the app reads its own stale
   snapshot and silently drops every completion. This was the last bug, and it looked
   exactly like the feature working.

`am force-stop` blocks broadcast delivery until the user relaunches, so it is not a
valid way to test this. Background the app instead.

**Verified end to end on a release build** (obfuscated, R8-shrunk), not just in debug:
the alarm registers as `RTC_WAKEUP ... window=0 exactAllowReason=policy_permission`
— exact, not the inexact one-hour window — the notification arrives with Done / In 30
min / Skip, tapping Done with the app backgrounded queues the tick from the background
isolate, and reopening applies it to the routine *and* to the water total on Today
(§7.4). `run-as` does not work against a release build, so seeding state for this test
needs root.

## UI notes

Things that only became visible on a real screen, and what they turned into:

- **Big numbers are sans, not mono.** The prototype's readouts were SF Mono, which is
  handsome at 44px. Android's `monospace` is Droid Sans Mono — wide and clumsy, and it
  was most of why the app "looked plain". Large figures now use the sans face with
  tabular figures and tight tracking; mono is kept for small data and labels, where it
  reads as instrument output rather than as a fallback.
- **Overscroll stretch is off.** Android's default warps the whole page at the ends,
  which on a card layout reads as the UI breaking rather than as feedback.
- **Absence should be the quietest thing on screen.** The same mistake appeared three
  times and was fixed the same way each time: the week grid drew twelve outlined boxes
  for days with *no record*, so an absence carried more weight than the one day that
  was completed; the routine editor drew six full-width buttons for six times, each
  with its own delete button, pushing Days and Save below the fold; and the day picker
  drew seven bordered boxes, giving a routine's schedule more prominence than anything
  it reports. Empty states are now faint fills with no border, times are chips that
  flow two to a line, and days are solid-vs-quiet circles with no borders at all. The
  editor went from needing a scroll to fitting on one screen.

- **Over target reads as over target.** The headline ran
  `(target - consumed).abs()`, so 720 kcal *over* rendered identically to 720 kcal
  *left* — same digits, same label, on the one number the screen exists to communicate.
  The meter already knew. Now the label switches to "Over by", the figure and the panel
  border go amber, and the meter's existing over state finally agrees with the text
  above it.

- **The food list is windowed.** It used to build every row on every rebuild — including
  every keystroke in the search box, which is exactly when the frame budget matters. At
  73 foods that was survivable; at 210 it is not. `showAppSheet` now takes
  `scrollable: false` to hand the sheet a *bounded* box so it can own a
  `ListView.builder`, because nesting a lazy list inside the wrapper's
  `SingleChildScrollView` is what made settings unscrollable once already.

- **The weight chart is scrubable.** Touch or drag it and a vertical line marks the
  nearest day, with its date, the weigh-in and the trend value. Three details that took
  a second pass:

  * The readout **flips to whichever half is free** — below the point when the trend is
    high there, above it when low. A tooltip that covers the very point it is reading
    is worse than no tooltip, and a 92dp chart has room on one side only.
  * The x and y mappings live in `_chartX` and `_ChartScale`, shared by the painter and
    the hit-test. Two copies of that arithmetic drift, and the symptom is a crosshair
    landing beside the dot it claims to read.
  * Only `onHorizontalDrag*` is handled, never vertical, so scrubbing never fights the
    page scroll underneath it.

- **State changes move, they do not cut.** Two shared primitives in `primitives.dart`:
  `SmoothSwap` slides and fades one control past another (the water card's amounts
  becoming "Add 250 ml?", a routine's Tick button becoming "All done today"), deriving
  direction from the key so it reads as a push rather than a crossfade in place;
  `SmoothReveal` animates height for things that appear (the weigh-in out-of-range
  warning, the goal-rate row when you leave Maintain) so the panel grows instead of the
  page jumping under your finger.

  Verified by temporarily stretching the duration to 2200ms and screenshotting
  mid-flight — at 260ms no screenshot can catch it, and "it looks instant" is exactly
  what a hard cut also looks like.

- **The splash is one screen, not two.** There are unavoidably two — the OS launch
  screen while the engine boots, then the Flutter one — and the app used to make that
  obvious: the mark jumped size *and* position, then text appeared. Fixed on three
  fronts. The mark is 108dp and screen-centred on both sides. The wordmark is
  positioned *beneath* the centred mark rather than laid out under it in a Column, so
  arriving text cannot shift the mark. And the hold went 1100ms to 1900ms, because at
  1100 the tagline faded in and was gone inside a blink.

  Verified by measuring the mark in screenshots of each phase:

  | | native launch | Flutter splash |
  |---|---|---|
  | Android | 120x198px, centre y=1201 | 120x198px, centre y=1201 |
  | iOS | 138x226px, centre y=1311 | 138x226px, centre y=1311 |

- **Android 12+ ignores `windowBackground` entirely**, which is the trap underneath
  that. It uses `windowSplashScreenAnimatedIcon` and **scales whatever drawable it is
  given to fill its own icon window**, so the bitmap's pixel size is irrelevant and the
  only way to control apparent size is padding inside the image. Measured at ~273dp on
  a 420dpi device. The mark therefore ships twice: natural size in `drawable-<density>/`
  for pre-12's centred bitmap, and padded to `scale_mark=0.38` in
  `drawable-<density>-v31/` for the icon window. Getting this wrong made the mark jump
  2.5x, and no amount of correcting the bitmap's resolution would have fixed it.

- **Sparse data gets a designed state, not a gap.** One weigh-in cannot make a trend, so
  the weight card shows the figure, a dashed continuation, and the reason — rather than
  an empty 92px chart slot that looks like a failed component. Same principle as the
  water wave at 0%.
- **The summary shows the week, not the day.** It used to be a per-routine timeline on a
  time axis. That answered "which reminder do I always miss" — a real question — but the
  routine cards immediately below it already show today's slots as pips, so the summary
  was restating what sat an inch beneath it. It is now a seven-day grid: rows are
  routines, depth of fill is the fraction ticked, today is ringed. Rest days are a dash
  and days with no record are an empty outline, because a day that was never measured
  must not look like a day that was failed. Still no streak count — §6 rule 4.
- **A nested scroll view silently eats the drag.** `showAppSheet` already wraps its
  content in a `SingleChildScrollView`. Putting a `ListView` inside that made the
  settings sheet completely unscrollable — the inner list, sized exactly to its content,
  had nothing to scroll and swallowed the gesture rather than passing it up. Sheets emit
  a plain `Column`; anything that must stay reachable goes in the pinned `footer`.
- **`initState` cannot read `MediaQuery`.** The water wave's reduced-motion check moved
  into `_stir()`, which `initState` called — legal to analyze, legal to build, and a red
  error box on the Today screen at runtime. It belongs in `didChangeDependencies`,
  guarded to fire once. A profile build did not reproduce it, because the assertion is
  debug-only.
- **No empty action rows.** A lone Pause button beside a blank gap reads as a layout
  bug; that space now says what state the routine is in.

## Performance

Measured, not guessed. The engine was the obvious suspect and turned out to be
innocent — `tool/bench.dart` runs it against synthetic logbooks:

```
 30 days (150 food entries): dailyReport  80us   weightTrend   5us  =>  0.5% of a 60fps frame
180 days (900 food entries): dailyReport 162us   weightTrend  77us  =>  1.0% of a frame
365 days (1825 entries)    : dailyReport 348us   weightTrend 203us  =>  2.1% of a frame
```

A year of daily logging costs a fiftieth of one frame. The real costs were elsewhere:

1. **The water wave never stopped.** It repeated a 60fps animation for as long as the
   card was on screen. Measured on a profile build by reading `utime + stime` from
   `/proc/<pid>/stat` over a five-second window with the card visible and no input:

   | | CPU used per 5s idle |
   |---|---|
   | wave looping | 2.4 – 3.5 s (≈ half a core, forever) |
   | wave settling after 2.6 s | **0.00 s** |

   It now ripples on change and stills. Nothing is lost — the movement was only ever
   meaningful at the moment the level changed.

2. **`ColorScheme.fromSeed` re-ran on every store change.** Real colour-space maths, for
   an identical result, on every water tap and every tick. Memoised on
   `(palette, brightness)`.

3. **`report()` recomputed several times per build.** Memoised on a state version
   counter plus the date, so it recomputes when the data changes or the day turns, and
   at no other time.

4. **`RepaintBoundary` around the wave, the trend chart and the week grid**, so a
   repaint in one cannot drag the others with it.

`dumpsys gfxinfo` and `SurfaceFlinger --latency` are both useless here — Flutter renders
into a `SurfaceView`, so the platform's frame counters see almost nothing. `/proc` CPU
jiffies are the honest measure.

## Stress-test findings

Fixed after testing on device:

- **A routine could not miss slots from before it existed.** Adding a meal routine at
  11 pm reported three missed reminders for a day it had never been active in. Routines
  now carry `startedDate`/`startedMin`, and `slotState` distinguishes *untracked* from
  *missed*. Resuming a paused routine restarts tracking too, so resuming at 3 pm does not
  retroactively fail the morning. Six regression tests cover it.
- **The same root cause explained "notifications never fired."** Every time in the
  schedule had already passed that day, so the next fire was the following morning.
  Verified by advancing the emulator clock: the 8:30 reminder posted correctly with
  Done / In 30 min / Skip.
- **Notification small icon** was the full-colour launcher icon, which Android renders
  as a flat blob — it keeps only the alpha and tints it. Now a white-on-transparent
  flame silhouette.
- **`ink3` failed WCAG AA** at 2.94:1 on white, below even the 3:1 large-text floor,
  while carrying most of the hint and label text. Now #697872 / #7A8984 at ~4.6:1.
  Checked with a contrast script, not by eye.
- **Cancel and Save were different shapes and heights** — a pill beside a rounded
  rectangle. `SecondaryButton` now matches `PrimaryButton` geometry.
- **"Add your own food" sat below seventy list items.** Sheets take an optional pinned
  footer; the food sheet uses it.
- **Motion**: meters ease instead of snapping, pips animate between states, tabs
  cross-fade.
- **Semantics**: symbol-only controls ("−", "+", "×") now announce what they do.

## Not done
- **iOS has never been compiled.** Xcode is not installed here; see the iOS section
- Export. Delete-all exists; there is no way to get the data *out* yet
- Pause-all is session-only by design; confirm that is what you want
- Water and routine history begin from the day the fields were added — days before that
  read as "no record", which is correct but means history is thin at first
- Historic slot counts are not stored, so editing a routine's times rescales its old
  cells in the week grid
- Only exercised on an emulator, not a physical phone. Doze and OEM battery managers are
  the untested part of notifications

## Run it

```bash
flutter emulators --create --name pixel      # once
flutter emulators --launch pixel
flutter run
```
