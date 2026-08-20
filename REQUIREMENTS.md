# TrueBurn — Requirements (v1)

Working name. A fitness tracker that does three things and derives a fourth.

**Premise:** the market is over-engineered. But the fix is not "fewer buttons" — it is
*not asking the user for information the app can compute itself*. Every competitor asks
you to declare an activity level and trust a population-average formula. TrueBurn measures
your actual energy expenditure from data you were already logging.

---

## 1. Scope

### In (v1)

| Feature | Notes |
|---|---|
| Weight logging | One number per day. Trend line is the primary display, not raw weight. |
| Food logging | Curated seed list + reusable custom items. See §5. |
| Water logging | ml, quick-add buttons. |
| Adaptive TDEE | Derived. The differentiator. See §4. |
| Daily report | Intake vs target, water vs target, weight trend, TDEE + its confidence. |
| Notifications | System nudges, rate-limited. See §7.1. |
| Routines | User-created reminders with a duration and a done/pause/delete lifecycle. See §7.2. |

Two screens: **Today** (the daily loop — log, and see where you stand) and **Routines**.
Split because one is opened many times a day and the other every few weeks; putting
setup in the path of the daily loop is how these apps get heavy.

### Out (v1) — explicitly deferred

- Wearables / HealthKit / Health Connect. **v1 uses no sensors at all.**
- Exercise logging. TDEE absorbs activity automatically; logging workouts would double-count.
- Macro targets, micronutrients, fibre, sodium.
- Social, streaks, gamification, badges.
- Accounts and cloud sync. Local-first; export as JSON.
- Barcode scanning, restaurant menus, and any licensed or crowd-sourced nutrition
  database. The seed list in §5 is hand-curated and deliberately small.

### Non-goals

- Not a medical device. Produces no diagnosis and no clinical advice.
- Not a coaching app. It reports; it does not exhort.

---

## 2. Product decisions (already made, with reasons)

| Decision | Reason |
|---|---|
| No activity-level dropdown after cold start | Self-reported activity is the single largest error source in every competitor. We measure it instead. |
| Trend weight is the primary number | Raw daily weight swings ±1–2 kg on water and glycogen alone. Showing raw weight makes users react to noise. |
| No exercise logging | Adaptive TDEE already contains their activity. Adding "calories burned from workout" double-counts and is the #1 way these apps lie to people. |
| Accuracy of food logging is not required | Only *consistency* is. See §4.3 — systematic under-logging is absorbed by the feedback loop. |
| Ranges, not point estimates, until confident | A number with false precision is worse than an honest range. |
| Hard cap of 4 notifications/day | Reminder spam is the top uninstall driver, water reminders worst of all. |

---

## 3. Data model

```
Profile     heightCm, birthYear, formulaVariant, activityLevel (cold start only), goal
WeighIn     date, kg
FoodEntry   date, kcal, label
WaterEntry  date, ml, source ("manual" | routineId)
Routine     type, name, message, times[], days[], amountMl, totalDays, elapsed,
            active, completions[]        — see §7.2
```

`WaterEntry.source` records which routine completion produced it, so a reminder ticked
twice cannot double-log and unticking can reverse exactly the entry it created.

Dates are `YYYY-MM-DD` local. All logs are append-only lists; the engine is a pure
function of `(Profile, LogBook, asOfDate) -> DailyReport`. No hidden state, no
mutation, no I/O. This is what makes it testable off-device.

---

## 4. Algorithms

### 4.1 Weight trend — time-aware EMA

```
alpha_base = 0.25                        # ~7-day effective window
alpha_eff  = 1 - (1 - alpha_base)^gapDays
trend_n    = trend_(n-1) + alpha_eff * (raw_n - trend_(n-1))
```

Time-aware so a user who skips four days does not get a trend line that lags four days
behind reality. Seeded with the first weigh-in.

**The trend is a single derived value, never stored alongside a copy.** An early
prototype kept a separate `weight` field next to the series; the card read one and the
chart read the other, and they disagreed on screen by 0.3 kg. There is one trend, and it
is the last point of the series.

**Logging a weight opens a sheet, not a silent write.** A stepper at 0.1 kg with coarse
±0.5 / ±1 nudges, pre-filled from the last raw entry, and — the point of the screen — a
live preview of the trend the entry produces: *"trend after this 78.4 kg · moves the
trend by +0.02 kg"*. Raw weight swings a kilo or two on water and food alone, and
reacting to that swing is the behaviour the trend exists to prevent, so the sheet teaches
the relationship at the moment it matters. No streak language anywhere (§6 rule 4).

The trend is shown to **one decimal everywhere**; the 0.01 precision appears only on the
*movement*, which is where the small change actually lives. Showing a 2 dp trend in the
sheet and a 1 dp trend on the card promises a precision the card then discards.

**Range: Month / Quarter / Year**, with the plain-language answer stated under the chart
— *"−2.0 kg over the past 89 days · −0.16 kg a week"* — plus start and end weights. Raw
dots are drawn at a month, shrunk at a quarter, and dropped entirely at a year, where 365
of them are texture rather than information; the line is scaled to the trend so outliers
cannot flatten it.

Note that a short window is genuinely noisy: in simulation a 29-day window read
−0.19 kg/week against a true −0.13, while the year window read −0.19 against a true
−0.18. This is expected, not a defect — but it is a reason not to let a monthly figure
carry more weight in the UI than the longer ones.

### 4.2 Adaptive TDEE — the core

Over a rolling window (target 28 days, minimum span 12):

```
slope       = OLS slope of raw weigh-ins against day     # kg/day
deltaKg     = slope * spanDays
avgIntake   = mean(kcal on days that were logged)
TDEE        = avgIntake - (deltaKg * 7700) / spanDays
```

`7700 kcal/kg` is the standard energy density of body-mass change.

**The slope is fitted by least squares through the raw weigh-ins, not by differencing
two ends of the EMA.** Differencing endpoints throws away every observation in between,
so one noisy weigh-in at either end moves the whole answer — measured at ±200 kcal of
jitter in simulation, which then feeds the recommendation and sets up an oscillation.
The EMA is for display, where its lag is a feature; as a slope estimator that lag is a
bias.

Weigh-ins are a morning protocol, so weight on `end` reflects eating through `end - 1`.
The causally matching intake window is `[start, end-1]` — exactly `spanDays` days. Days
without a food log are excluded from the mean and then implicitly assumed to equal it:
the least-bad available assumption, and a known source of downward bias, since people
skip logging on heavy days. §4.3 explains why that bias is tolerable.

**Rejection rules** — return no measurement if any hold:

- intake coverage < 60% of span
- fewer than 3 weigh-ins, or span < 12 days
- result falls outside `[0.85x, 2.5x]` of **BMR** (implausible; usually a data-entry
  error such as a weight typed in lb). That range spans bedbound to elite endurance

**The plausibility guard is anchored to BMR, never to the formula.** An earlier version
used `[0.6x, 1.8x]` of `formulaTdee`, which carries the self-reported activity
multiplier (1.2 to 1.725). That let a dropdown decide which real measurements were
believable: across the full simulation, declaring "Active" instead of "Light" rejected
**9.7% of measurements against 0.1%** — on identical logged data — and silently dropped
the engine back to the very formula this document exists to replace. §1's whole premise
is that self-reported activity is *less* reliable than the population regression; giving
it a veto over the measurement inverted that.

BMR depends only on height, weight, age and variant, so the guard now catches the typos
it was written for without the user's guess about themselves entering into it. At the
default activity level the new band is what the old bounds already produced, so §10's
results are unchanged but for one figure (persona 6's floor moves 15% to 14%).

### 4.2b Telling the user when the log has drifted

The app holds two independent expenditure figures: the **formula**, which knows only
height, weight and age, and the **measurement**, which comes from the food log and the
scale. Nothing else on the market holds both, so nothing else can notice when they
disagree — and a sustained disagreement has one overwhelmingly likely cause, which is
food going unrecorded.

Surfaced on Today when the measurement sits **18% or more below** the formula, worded as
an observation about the *log*, never about the person.

**Not predicted-versus-actual.** That pairing is the obvious test and is useless for
this: measured TDEE is *defined* as average intake minus the weight change, so predicted
and actual reconcile by construction and can never diverge enough to report. This was
built the wrong way round first and caught by testing, not by review.

The 18% threshold is set from the simulation, averaging measured TDEE over each
persona's last twenty days:

| persona | measured vs formula |
|---|---|
| honest logger | +3% |
| under-records 15% | −9% |
| under-records 25% | −17% |
| under-records 40% | −32% |

§1 puts Mifflin–St Jeor at ±10–15% for any given person, so anything inside that band is
indistinguishable from an unusual metabolism. 18% clears both the honest logger and the
formula's own error — at the deliberate cost of missing the 25% under-recorder. That
trade is chosen, not accidental: a false accusation is unfixable by the person receiving
it, while §4.3 shows the engine tolerates systematic under-reporting. The upward
direction needs 30%, because a fast metabolism is common and real whereas nobody logs
food they did not eat by accident.

### 4.3 Why under-reporting does not break it

Let `f` be the user's systematic logging factor (0.75 = logs 25% low), `T` true TDEE,
`I` true intake, `D` the target deficit.

The recommendation error works out to `(1 - f) * (D_current - D)`.

The error is proportional to the gap between the *current* deficit and the *target*
deficit. At equilibrium — when the user is losing at the target rate — the error is
**zero**. The system is a damped feedback loop that self-corrects, not an instant
cancellation. It converges over a few weeks; it is not right on day one.

The user never needs to be accurate. They need to be *consistently* inaccurate.

### 4.4 Cold start and blending

```
c_span     = clamp01((spanDays - 12) / 15)          # 0 at 12d span, 1 at 27d
c_coverage = clamp01((coverage - 0.6) / 0.3)        # 0 at 60% logged, 1 at 90%
c_density  = clamp01((weighIns/spanDays - .25)/.35) # 0 at 25% weigh-in rate, 1 at 60%
confidence = c_span * c_coverage * c_density

shownTDEE  = confidence * measured + (1 - confidence) * formula
```

Three terms, multiplied, because any one of them alone is not evidence. Density matters
independently of span: a slope fitted through three points spread across four weeks has
a standard error far too wide to act on.

A window of N days can only contain a span of N−1. Using N as the `c_span` denominator
makes full confidence unreachable and silently pins the app in `blended` mode forever —
this was a real bug, caught only because the simulation printed the mode column.

Fallback formula is Mifflin–St Jeor × activity multiplier:

```
male    BMR = 10*kg + 6.25*cm - 5*age + 5
female  BMR = 10*kg + 6.25*cm - 5*age - 161
multipliers: sedentary 1.2, light 1.375, moderate 1.55, active 1.725
```

The formula variant is chosen by the user directly, not inferred from a gender field.

**The UI must state which mode it is in.** "Estimated from your height and weight" vs
"Measured from your last 28 days" is an honest label and a genuinely good moment when
it flips. But see §10.4 — do not flip that label on every confidence wobble.

### 4.5 Targets

```
deficit      = goal.kgPerWeek * 7700 / 7
targetIntake = shownTDEE - deficit
waterTarget  = clamp(35 ml * trendWeightKg, 2000, 4000)
```

The water figure is a rule-of-thumb, and the UI must not present it as a clinical
requirement. It is nonetheless **derived from body weight, never hardcoded**, so the
"recommended zone" a routine is checked against tracks the actual user.

**A water routine discloses its coverage at setup.** `times × amount` against the
recommended intake, stated plainly: six 500 ml bottles is 3.0 L and clears a 2.75 L
target; six 250 ml glasses is 1.5 L and covers barely half. When a schedule falls short
the sheet warns, gives the percentage and the litre shortfall, and names the two fixes
(add a time, or raise the amount).

This matters more than it looks. A schedule that quietly under-delivers is worse than no
schedule at all, because the user believes hydration is handled and stops thinking about
it. The default amount is therefore **500 ml, not 250** — six reminders at 250 ml would
ship a default that fails its own check.

---

## 5. Food entry

No licensed database. A small curated seed list, plus custom items the user adds by
hand. This is viable *because* of §4.3 — the engine needs consistency, not accuracy.

### 5.1 The hard requirement

**A custom food is a saved, reusable item. Never a one-off free-text calorie entry.**

This is the single most important constraint in the food feature, and it is not a
convenience feature. Simulation (§10) shows the two kinds of wrongness behave completely
differently:

- **Consistent error is harmless.** Save "my dal = 250 kcal" when it is really 320, reuse
  it every time, and the feedback loop absorbs it entirely. Error stays systematic.
- **Re-guessing every time costs real accuracy.** It biases the TDEE measurement *down*
  by roughly σ², because the user eats until the log reads their target: on days they
  underestimate a portion they eat more, on days they overestimate they eat less, and
  `E[1/f] > 1/E[f]` means those do not cancel. At ±25% per-day guessing this costs about
  five points of goal accuracy (13% vs 8%) and pushes the app to over-restrict.

So the UI must make re-using an existing item strictly easier than typing a new number.
A free-text "just enter calories" field, used habitually, is the failure mode.

### 5.2 The seed list is scaffolding, not the product

People eat a small repertoire. After roughly two weeks a user's own history *is* their
database, and search stops mattering. Budget accordingly:

- 150–300 items is enough. Cover daily staples and common packaged goods.
- **Portions in natural units** — "1 roti", "1 katori dal", "1 cup rice" — not grams.
  Asking for grams is the largest single source of entry friction and of guessing noise.
- Invest in recents, frequents, one-tap re-log, and "same as yesterday". That is where
  logging consistency comes from, and §10 shows consistency is what switches the whole
  differentiator on.

### 5.3 The picker

Three taps to a logged meal: **Add → item → Add**. Rules that keep it at three:

- **Opens on recents, never on an empty search field.** Search is the fallback path, not
  the primary one. A keyboard appearing on open is a design failure.
- **Three labelled groups when browsing**: Recent, Your foods, then All foods
  lightest-first. Without the separators a saved custom food disappears into the sorted
  tail and reads as though it was never saved. Search collapses to a single flat list,
  because groups are noise once the user has named what they want.
- **Order is recents first, then everything else lightest-first.** Putting the cheap
  choice within reach is a nudge worth having, and it means the list is useful without
  remembering an exact name.
- **The list is never length-capped.** A cap on top of a lightest-first sort silently
  buries every heavy item — biryani, samosa, pav bhaji — where browsing cannot reach
  them. The list scrolls; truncating it only hides food people actually eat.
- **Quantity is a stepper that scales the calories live** — `1.5 × 1 katori = 270 kcal`,
  in natural units, half-steps below 2 and whole steps above.
- **The quantity step projects the result before committing**: a two-tone bar showing
  current intake plus the addition against target, and "takes you to 1250 of 2010". The
  decision should be informed at the moment it is made, not checked and regretted after.
- Entries are assigned a **meal from the clock** at the time of logging.
- **Custom foods are saved as reusable items and land in recents immediately.** The
  custom flow asks for a name and calories-per-serving, nothing else. §5.1 is the reason
  this is not a free-text calorie box.
- **"Same as yesterday"** copies the whole previous day in one tap. For anyone with a
  routine diet this is the single largest reduction in taps the app can offer, and it
  directly attacks the coverage number in §8.1.

Today shows intake as a bar **grouped by meal** — breakfast, lunch, snack, dinner — with
the remaining budget as a labelled block rather than anonymous grey, and a target marker
once exceeded. One segment per *entry* was tried first and failed: a 16 kcal spoon of
sugar became an invisible sliver, and alternating two accent tints coloured the segments
arbitrarily. Four meal blocks are always legible, and the opacity ramp (lighter earlier
in the day) encodes something true.

---

## 5.4 History and the report

**The date on Today is the control.** Tapping "MON 17 AUG" opens history. No new tab, no
extra icon — the date already answers "which day am I looking at", so making it tappable
adds a feature without adding chrome. A small glyph marks it as pressable.

History is a range summary over a day list, not a bare list. A list of days would miss
the point of a trend-based engine: the interesting numbers are averages, and the report
below is the "overall health report" the product was originally asked for.

**Range summary** — averages over 7 or 30 days: eaten per day, burned per day (measured,
§4.2), net per day, water, reminders completed. Then the line that matters:

```
Predicted −0.53 kg        Actual −0.53 kg
```

**Predicted comes from the energy arithmetic; actual comes from the scale.** Showing
them side by side is the engine checking itself in public. When they agree, the
measurement is sound. When they diverge, something is wrong — logging has drifted, or
expenditure has changed — and the user deserves to see that rather than be handed a tidy
number that hides it.

Getting this right requires care with the window: `predicted` sums N daily deltas, so
`actual` must span N intervals, meaning N+1 trend points. Measuring between the newest
and oldest *rows* spans only N−1 and silently understates the change.

**Day detail** — one tap from any row, and deliberately short: calories eaten with
under/over, the meal breakdown, measured expenditure and the day's net, weight trend,
water, and reminders completed. One screen, no scrolling, no charts. It answers "what
did that day look like" and stops.

**Absent is not zero, anywhere in this screen.** A day with no food logged shows no
intake rather than 0 kcal, is excluded from the averages rather than dragging them
down, and contributes nothing to `predicted` rather than a full day's deficit. Counting
unlogged days as fasts would manufacture a weight loss that never happened and then
report it as the engine's own prediction — the one number on this screen that has to be
beyond suspicion. Water is stored per day for the same reason: it used to exist only
for today, so history could speak about food and weight but had to stay silent about
water, and silence is the honest output when there is no record.

---

## 5.5 Settings, time format, motion

**Settings** sits beside the date on Today — the only two controls in that header, and
still no third tab. It holds: appearance, goal and rate, height and year of birth, the
basal formula variant and activity level, the weigh-in nudge time, quiet hours, and
export / delete.

Its icon is **sliders, not a cog**. A circle ringed by radiating spokes — the obvious
first attempt — is the brightness glyph, and read as one. Sliders are unambiguous and
stay legible at 14 px, where a cog's teeth turn to mush.

**Appearance is Light / Dark / Auto, and it comes first** because it is the setting
people reach for most. Auto must *remove* the theme override so `prefers-color-scheme`
takes back over — not read the device once and freeze that answer, which would leave the
app stuck in the morning's theme by evening.

Changing the goal **moves the real target**, including when a safety rule binds: pick
1.0 kg/week and the sheet shows the target raised to the 1500 kcal floor with the reason
(§6). A settings screen whose controls do not visibly change anything teaches the user
that the app is decorative.

The activity and formula controls carry an explicit note that they only shape the first
three weeks, after which measurement replaces them (§4.4). Formula variants are labelled
neutrally and chosen directly rather than inferred.

**Times are stored 24h and displayed am/pm**, with zero minutes dropped — "9 am", not
"9:00 am". This covers routine cards, tick buttons, pause-until labels and the routine
editor. The week grid carries no times at all — its axis is days. The exception is `<input type="time">`, which formats to the device locale itself.

**Routine cards** lead with today, not with the schedule: a row of pips showing *which*
of today's reminders landed (filled / amber ring / faint), then "3 of 6 done today", with
day-count progress demoted to a thin secondary line. "6×" told the user nothing; "6 times
a day · 9 am–7 pm" tells them what they signed up for.

**Water quick-add is two-tap**: the first arms, the second commits, with a visible
Cancel. A stray tap on a card scrolled past several times a day should not silently
rewrite the log. *(An Undo affordance would cost fewer taps for the same protection and
is the alternative worth measuring.)* The fill level itself eases toward its new value
rather than snapping, so adding water reads as filling.

**Motion is a one-time opening reveal** — trend line drawn, dots and pips popped in,
bars grown from zero — keyed off an `intro` class that is dropped after the first paint.
Every later render is instant: a chart that redraws itself on every tap is noise, not
polish. All of it is disabled under `prefers-reduced-motion`.

---

## 5.6 First run and the cold start

The hardest screen in the product. TrueBurn needs roughly three weeks before it does the
one thing that makes it worth using, and on day one it has nothing. §8.3 lists cold-start
dropout as a top risk; this section is the answer to it.

**A dashboard of zeros is the obvious design and the wrong one.** It shows nothing,
promises nothing, and leaves the user to invent their own reason to come back.

### Day 1 — no data

One action, and an honest account of what waiting buys:

> **Today** — One weigh-in. Five seconds, and the app has what it needs to start.
> **This week** — Log roughly what you eat. Rough is fine; it only has to be consistent.
> **Week three** — TrueBurn stops estimating and tells you what you actually burn.

Rules for this screen:

- **No onboarding wall.** Height, birth year, formula variant and activity level are
  *not* asked upfront. They shape only the first three weeks (§4.4), so they are
  collected when a target is first wanted, not before the user has done anything.
- **No invented numbers.** No calorie target, no water target, no chart. An app that
  fabricates a target on day one to look complete has taught the user its numbers are
  decorative.
- **Food and water still work immediately.** Neither needs a profile or a weigh-in.
- Routines shows the two starter templates — water and meals — with the reason each
  earns its place, rather than an empty list and a "+" button.

### Days 1–28 — the wait, made legible

A progress card counts days of data toward 28, with a marker at 12 where measurement
becomes possible. This is the retention mechanism: it converts an unexplained silence
into a finite, visible countdown, and gives a reason to keep logging that is not
willpower.

**The label must track the engine's three modes (§4.4), not a boolean.** At exactly a
12-day span confidence is *zero* — measurement becomes possible, not trustworthy:

| Days of data | Chip | What it says |
|---|---|---|
| < 12 | Estimated | Population formula, ±10–15% off for any individual |
| 12–27 | **Part measured** | Blends the user's own data with the estimate, leaning further on data each day |
| ≥ 28 | Measured | Measured from the last 28 days |

An early prototype flipped straight from "Estimated" to "Measured" at day 12 and
overclaimed by three weeks. The middle state is not a nicety; without it the app lies.

---

## 6. Safety rules

Non-negotiable, enforced in the engine rather than the UI so they cannot be bypassed:

1. **Intake floor.** Never recommend below 1500 kcal (male variant) / 1200 kcal
   (female variant). If the goal demands lower, clamp and surface the reason.
2. **Rate cap.** Reject goals above 1.0 kg/week.
3. **BMI floor.** Below BMI 18.5, refuse to display a loss target at all and show a
   see-a-professional message instead.
4. **No streak pressure on weigh-ins.** Nothing in the app may reward daily weighing
   frequency; that pattern is actively harmful for a subset of users.
5. Age gate at 18 for the calorie-target feature.

---

## 7. Notifications

Two mechanisms, governed differently, because an unrequested ping and a commitment the
user built themselves are not the same object.

### 7.1 System nudges — the app decides

Global: **hard cap 4/day.** A channel auto-mutes after 7 consecutive ignores and tells
the user it did.

| Channel | Rule |
|---|---|
| Weight | Once daily at a user-set morning time. Suppressed if already logged. |
| Food | Max 3/day, tied to meal windows. Suppressed if that window already has an entry. |
| Water | **Not time-based.** Two checkpoints (15:00, 20:00), fires only if behind pace by >30%. Max 2/day. |

Hourly water reminders are the single most common reason this category of app gets
deleted. There is no configuration screen for these; the pacing logic replaces it.

### 7.2 Routines — the user decides

A routine is a reminder the user creates and owns. Fields: type (water / food / gym /
custom), name, notification text, **a list of clock times**, a day-of-week mask, a
duration in days after which it retires itself, and — water only — millilitres logged
per completion.

**There is no interval builder.** An earlier draft offered "every *N* hours between X
and Y"; in the prototype that rendered as a bare `1` beside two time fields and
explained nothing. A schedule is now always a visible list of real clock times.

Instead, **choosing a type loads a ready-made schedule** which the user then edits:

| Type | Times | Days |
|---|---|---|
| Water | 09:00, 11:00, 13:00, 15:00, 17:00, 19:00 | every day |
| Food | 08:30, 13:00, 17:00, 20:30 | every day |
| Gym | 18:30 | Mon / Wed / Fri |
| Custom | 09:00 | every day |

Two taps produce a working water routine. Times are added and removed individually; the
last one cannot be removed. Water stops at 19:00 rather than 21:00 — six reminders
instead of seven, which keeps the default under the density warning and avoids nudging
fluid intake close to bedtime.

Changing type in **create** mode loads that template whole. Changing it in **edit** mode
changes only the type, so an existing schedule is never silently overwritten.

Lifecycle: active → paused → deleted, plus auto-retire when the day count completes.
Every routine is editable — tapping its card opens the same sheet, pre-filled. Delete
lives inside that sheet rather than on the card, which keeps two buttons on the card
instead of three and puts a destructive action behind one deliberate tap.

**Pause all** suspends every routine for a chosen span — 1 hour, 4 hours, rest of today,
or until tomorrow — surfaced as a banner with the resume time and a one-tap Resume. Day
counts keep advancing while paused, so a pause costs no progress; otherwise people
refuse to use it and mute the app instead, which is unrecoverable.

The notification carries **Done**, **snooze**, and **Skip** as inline actions; Done must
be reachable without opening the app, or people stop marking things done and the data
breaks. Skip is styled as prominently as Done — a reminder you can dismiss honestly is
one you keep. Three consecutive skips prompts to retire the routine.

**Done on a water routine logs its water.** Each water routine carries an amount (250 ml
default) which lands on Today when *that individual reminder* is completed, shown on the
Water card as "*n* ml from reminders". Confirming a reminder and then separately
recording the same glass is exactly the double work this app exists to remove. Because
completion is per reminder (§7.3), the synced total is always `ticked × amount`, which
makes it self-correcting — there is no accumulated counter to drift.

### 7.4 One source of truth

Today and Routines are two views of the same data and must never disagree. Sync runs
**both ways**:

| Action | Effect |
|---|---|
| Tick a water reminder | Logs its millilitres on Today |
| Log water manually on Today | *Converts* an overdue water reminder into a tick |
| Log any food on Today | Ticks the food routine's most recent already-due reminder |
| Tick a gym reminder | Progress bar only — never the energy math (§7.2) |

The manual-water rule is the one to get right. A "+250 ml" tap **satisfies** an overdue
reminder rather than logging alongside it; only the remainder reaches the manual pool.
Adding both would count the same glass twice. It also never reaches forward — a
reminder scheduled for later today is not satisfied by drinking now, because the user
has not got there yet.

Food is the mirror case: a food routine is a reminder *to log*, so the act of logging
satisfies it. Without this, someone who logs every meal from the Today screen would see
a wall of missed reminders and conclude the app is broken. It is the
same event, recorded once.

### 7.3 Adherence display

**Completion is per reminder, not per day.** A routine stores the list of times ticked
today and the list ticked yesterday. Ticking three of six water reminders logs 750 ml,
not all-or-nothing, and the card's button targets the next specific time ("Tick 15:00",
or "Missed 13:00 — tick" when one has already lapsed).

Routines opens with a **week grid**: one row per active routine, seven columns, today
rightmost and ringed. Each cell's accent depth is the fraction of that day's reminders
ticked — a half-done day looks half done rather than failed. Aggregate counts for
yesterday and today stay as a single line above it.

Two earlier drafts were rejected. Merging every routine onto two rows put dots at nearby
times into unreadable blobs and made a missed marker unattributable — you could see
*something* lapsed at 17:00 but not what. Splitting it to one row per routine on a
**time axis** fixed both, and answered a real question ("which reminder do I always
miss"), but it duplicated the screen: the routine cards immediately below already show
today's slots as pips. A summary that restates what is an inch beneath it is wasted
space. The week is the thing the cards cannot show.

**Three cell states, and the third is not optional.** *Tracked* — scheduled, with a
known count. *Off* — not scheduled that day, drawn as a dash; a rest day is not a
failure. *Unknown* — scheduled, but the routine did not exist yet or the app kept no
record, drawn as an empty outline. Collapsing unknown into zero would report days the
user was never measured on as days they failed, which is the same error §7.3's
`startedDate` rule exists to prevent. Today's fraction uses the *tracked* denominator
for the same reason: a routine created at 11 pm reads as off, not as 0%.

Storage is a count per date (`YYYY-MM-DD` → ticks), pruned to five weeks, banked at
rollover from the same value that feeds `doneYesterday` — so the grid and the header
line cannot disagree. Historic slot counts are not kept: editing a routine's times
rescales its old cells, which is a known and accepted distortion.

No streaks, no escalating counter, no praise: §6 rule 4 forbids that pattern and it
applies to routines as much as to weigh-ins. A missed reminder is information, not a
failure, and the display must not editorialise.

**Routines are exempt from the §7.1 four-a-day cap.** That cap exists because
*unrequested* pings drive uninstalls; a routine is requested by definition. In exchange,
the cost is disclosed at the moment of creation: the sheet states how many reminders per
day the routine will send, and warns above six that people usually mute at that rate.
Disclose, do not silently cap.

**A gym routine's Done never touches the energy math.** §1 excludes exercise logging
because adaptive TDEE already contains the user's activity and crediting "calories
burned" on top double-counts. A gym routine is a commitment tracker: Done moves a
progress bar and nothing else. This boundary is not negotiable, because violating it
silently corrupts the one number the product exists to get right.

Routines are placed as a top-level tab rather than inside settings — they have a
lifespan, a progress bar and a history, which makes them content, not configuration.
See `design/prototype.html`.

---

## 8. Open risks

1. **Logging consistency is the whole product risk.** Not accuracy — §10 shows the
   engine is worth nothing over a plain formula below ~60% logging coverage, and that
   is the only regime where it fails to beat the control. Everything in §5.2 exists to
   defend this number. It is the metric to instrument first.
2. **The seed list has no answer for home-cooked food.** A user can look up "1 roti"
   but not "the sabzi my mother made". They will guess. §5.1 makes that survivable by
   forcing the guess to be saved and reused, but the first guess is still unanchored,
   and a portion-size picker with photos is the obvious v2.
3. Cold-start dropout. The engine needs ~3 weeks before it does its trick. Weeks 1–3
   have to be worth using on their own.
4. 7700 kcal/kg assumes fat-mass change. Early water-weight drops will read as a huge
   deficit; the EMA and the 28-day window damp this but do not remove it.

---

## 8.5 Implementation

**Expo / React Native**, one codebase for iOS and Android. Chosen because the TypeScript
core drops in unchanged — which was the reason `src/core/` was written free of platform
imports in the first place.

**The app imports the core; it does not copy it.** Metro reaches one directory up, so the
shipped binary runs the exact code §10 measures. A copied engine would drift from its own
proof within weeks.

Two resolvers must agree, and they are configured separately: `tsconfig` `paths` for the
type checker, `metro.config.js` `extraNodeModules` for the bundler. Setting only the
first yields a green typecheck and a bundle that fails on device.

Routines live in `app/src/domain/`, **outside** the core. That is what structurally
enforces §7.2: the routines module has no way to write into a `LogBook`, so a gym tick
cannot reach the energy maths even by mistake.

The sync rules of §7.4 are pure functions in `app/src/domain/sync.ts` rather than store
methods, so the invariant — `manual + ticks × amount` is unchanged by a conversion — is
provable headlessly (`npx tsx app/verify.ts`) in the same way the engine is.

---

## 9. What this repo currently implements

`src/core/` — the whole engine above, zero dependencies, no platform imports.
`src/sim/` — synthetic users with a *known* true TDEE and a closed behavioural feedback
loop, to verify convergence. Run with `npm run sim`.

No UI yet. The algorithm is the risky part and it is proven first.

---

## 10. Findings from the simulation

120 simulated days, goal 0.5 kg/week. Each person is run twice — once coached by the
adaptive engine, once by a formula-only control — and **averaged over 24 seeds**. Error
is in *achieved rate of loss*, which is what the user actually cares about. Bracketed
figures are the p10–p90 spread across seeds.

| Person | TrueBurn | Formula-only |
|---|---|---|
| Honest logger | **8%** (3–15) | 34% (28–42) |
| Under-reporter (logs 25% low) | **15%** (1–23) | 79% (69–92) |
| Off-population metabolism | **8%** (1–18) | 91% (84–97) |
| Guesser (±25%/day, unbiased) | 13% (2–23) | 15% (1–32) |
| Improving logger (0.70 → 0.95) | 8% (0–18) | 9% (2–20) |
| Sporadic logger (45% of days) | 18% (8–26) | 18% (9–27) |

**Single-seed numbers are not results.** An earlier version of this table came from one
seed per scenario; adding one unrelated RNG call shifted the stream and moved the
under-reporter from 27% to 1%, and flipped the guesser row's conclusion outright. Every
figure above survives resampling. Anything added later must too.

### The headline

**TrueBurn lands between 8% and 18% for every person tested. The formula ranges from 9%
to 91% depending on whether you happen to resemble its training population.** That is
the argument for the product, and it is stronger than any single row: the formula is not
uniformly bad, it is *unpredictably* bad, and neither the app nor the user can tell in
advance which case they are in.

### What this changes

1. **For a sporadic logger, TrueBurn is worth nothing over a formula** — 18% vs 18%,
   with overlapping spreads. The coverage guard rejects the measurement and correctly
   falls back. This is right behaviour and it is also the product's central risk: the
   differentiator only switches on above ~60% logging consistency. Onboarding has to
   earn that, and weeks 1–3 have to be worth using without it. Instrument this metric
   before any other.
2. **The under-reporter's residual error is the safety floor, not the algorithm.** The
   floor binds on **41% of days** for them: their measured TDEE is scaled down by their
   own logging bias, dragging the target into the 1500 kcal floor. The engine is right
   to refuse to go lower — but the floor is expressed in *logged* kcal while the safety
   concern is about *actual* kcal, so it is over-conservative for exactly the people it
   catches. **Action: when the floor binds repeatedly, tell the user their logging may
   be running low.** More useful than silently capping them.
3. **Random guessing biases the measurement downward by roughly σ².** The user eats
   until the *log* reads their target, so on days they underestimate a portion they eat
   more and on days they overestimate they eat less. Because `E[1/f] > 1/E[f]` those do
   not cancel: actual intake runs above logged, measured TDEE reads low, and the app
   over-restricts. Cost is real but modest — 13% against the honest logger's 8%, so
   about five points. Note the asymmetry with §4.3: a *consistent* error is free, a
   *random* one is not. This is why §5.1 requires saved, reusable custom foods.
4. **Drift is a non-issue.** A logger improving from 0.70 to 0.95 over four months came
   out at 8% — identical to the honest logger — because the 28-day window tracks it.
   This was the main worry about shipping manual entry and it is resolved. It also means
   nudging users toward better logging mid-flight is safe.
5. **Neither food-estimation scenario beats the control by much** (13 vs 15, 8 vs 9).
   Both tie rather than win. TrueBurn's advantage comes from people whose *metabolism*
   the formula misjudges, not from people whose *logging* is poor. Worth knowing before
   building marketing around food accuracy.
6. **Formula-only apps get worse as you lose weight.** The formula lowers your target as
   mass comes off, compounding an error it already had, so the achieved deficit drifts
   further from target over time. A real mechanism, not a simulation artefact.
7. Confidence plateaus around 0.84–1.00 for a good logger and oscillates between
   `measured` and `blended` as weigh-in density fluctuates. The UI must not flip a
   prominent label on every such transition — treat ≥0.8 as one visual state.
