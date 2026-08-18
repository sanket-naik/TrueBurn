# TrueBurn

Working name. A fitness tracker that logs weight, food and water — and derives your
actual daily energy expenditure from those three, with no wearable.

**[REQUIREMENTS.md](REQUIREMENTS.md) is the spec.** Read it first. It contains the
scope, the algorithms, the safety rules, and — in §10 — what the simulation actually
found, including the two results that argue against the product.

## Why this exists

Every competitor asks you to declare an activity level and then trusts a population
regression. Mifflin–St Jeor is ±10–15% off for any given person, and self-reported
activity is worse than that. If you are logging weight and intake anyway, expenditure
is not something to estimate — it is something to *measure*:

```
TDEE = averageIntake - (weightChangeKg * 7700) / days
```

The formula is kept only as a cold-start fallback and blended out as the measurement
earns confidence.

## Layout

```
src/core/     the engine. zero dependencies, no platform imports, no clock, no I/O.
              pure: (Profile, LogBook, asOfDate) -> DailyReport
src/sim/      synthetic people with a known true TDEE and a closed feedback loop
design/       interactive prototype (open prototype.html)
mobile/       the app — Flutter. Engine ported to Dart and proven. See mobile/README.md
app/          superseded Expo/React Native build, kept for reference
```

`src/core/` (TypeScript) remains the reference implementation and the thing `src/sim/`
measures. `mobile/lib/core/` is a Dart port of it, held honest by running both harnesses
and diffing the output — currently identical, including spreads and floor percentages.

Two copies of an engine normally rot. This one cannot rot silently: the diff is a
one-command check and it either matches §10 or it does not.

`src/core/` must stay free of platform imports — no fetch, no fs, no React Native, no
`Date.now()`. That is what lets the whole engine be proven headlessly, before any UI
exists, and reused unchanged behind whatever UI eventually ships.

## Verify

```bash
npm install && npx tsc --noEmit && npm run sim
```

The simulation is seeded and deterministic: the same seed always produces the same
numbers, so a run is a regression test rather than an anecdote. It runs each synthetic
person twice — once coached by the adaptive engine, once by a formula-only control —
and reports the metric that matters, which is not whether the TDEE number looks
plausible but whether the person ends up losing weight at the rate they asked for.

## Status

The engine is built and proven. **There is no UI, and no seed food list yet.**

v1 ships without a nutrition database: a small curated list plus custom items the user
adds by hand (REQUIREMENTS §5). That works because the engine needs consistency rather
than accuracy — but only if custom foods are **saved and reused** rather than re-guessed
each time. Re-guessing biases the measurement downward by roughly σ² and makes the app
over-restrict; the derivation and the simulated cost are in §10.5.

The open risk is no longer the database. It is logging consistency: below ~60% coverage
the engine correctly refuses to measure and falls back to a formula, at which point the
product has no advantage over anything already on the store (§8.1).
# TrueBurn
