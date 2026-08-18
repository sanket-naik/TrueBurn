# TrueBurn — iOS & Android

Expo / React Native. One codebase, both platforms.

## The point of this layout

```
TrueBurn/
  src/core/        the energy engine — no platform imports, no clock, no I/O
  src/sim/         the simulation that proves it (npm run sim)
  app/             this app
    src/domain/    routines, foods, sync rules — pure, testable
    src/store/     state + local persistence
    src/screens/   Today, Routines
    src/sheets/    food, weigh-in, routine editor, settings
```

**`app/` imports `src/core/` directly — it is not copied.** Metro reaches one directory
up (`metro.config.js`), so the app runs the exact code the simulation proves. That only
works because `src/core/` has no platform imports, which is why it was written that way
from the start.

Two resolvers have to agree for this: `tsconfig.json` `paths` teaches the type checker,
`metro.config.js` `extraNodeModules` teaches the bundler. Setting only the first gives
you a green typecheck and a red device.

## Run it

```bash
cd app && npm install
npx expo start        # then press i / a, or scan with Expo Go
```

Notifications with lock-screen actions need a real build, not Expo Go:

```bash
npx expo run:ios      # needs Xcode
npx expo run:android  # needs Android Studio + an SDK
```

## Verify without a device

```bash
npx tsc --noEmit                 # from app/
npx tsx app/verify.ts            # from the repo root
npx expo export --platform ios   # proves Metro resolves everything
```

`verify.ts` covers the parts that are expensive to debug on a phone: the Today ⇄ Routines
sync invariant, and that the app's data shape drives the engine through formula →
blended → measured at the right thresholds.

## What is wired

- Adaptive TDEE via `dailyReport` — the app never reimplements any of the maths
- Two screens, bottom tabs, sheets for food / weigh-in / routine editing / settings
- Local persistence (AsyncStorage), debounced; no account, nothing uploaded
- Reminders with **Done / In 30 min / Skip** as lock-screen actions; Done ticks the
  reminder without opening the app
- Quiet hours are honoured at scheduling time, not by suppressing on arrival
- Light / dark / auto, with auto genuinely following the OS
- Animated water fill, weight trend chart, per-routine adherence timeline

## Not done yet

- History sheet and the predicted-vs-actual report (prototype §5.4) — the engine already
  returns everything it needs
- Pause-all persists only for the session; it should survive a relaunch
- Onboarding profile capture is in Settings rather than a first-run step
- No app icon or splash art
- **Never run on a device or simulator by me.** It typechecks and bundles for both
  platforms; it has not been seen on a screen.
