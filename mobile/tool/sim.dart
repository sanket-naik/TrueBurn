/// Convergence harness — the Dart port's proof of faithfulness.
///
/// Run:  dart run tool/sim.dart
///
/// If this reproduces the numbers in REQUIREMENTS §10 (8% / 15% / 18% / 8% / 13% / 8%),
/// the port is proven rather than hoped. Anything else means the translation changed
/// behaviour, because the RNG is already verified bit-identical to the TypeScript one.
library;

import 'package:trueburn/core/tdee.dart';
import 'package:trueburn/core/types.dart';
import 'simulate.dart';

const int totalDays = 120;
const int seeds = 24;

const profile = Profile(
  heightCm: 175,
  birthYear: 1994,
  formulaVariant: FormulaVariant.mifflinMale,
  activityLevel: ActivityLevel.light,
  goal: LoseGoal(0.5),
);

const scenarios = <PersonSpec>[
  PersonSpec(name: 'Honest logger', trueTdee: 2600, logFactor: 1.0, foodLogProb: 0.95),
  PersonSpec(
      name: 'Under-reporter (logs 25% low)',
      trueTdee: 2600,
      logFactor: 0.75,
      foodLogProb: 0.95),
  PersonSpec(
      name: 'Sporadic logger (45% of days)',
      trueTdee: 2600,
      logFactor: 0.95,
      foodLogProb: 0.45),
  PersonSpec(
      name: 'Off-population metabolism', trueTdee: 3100, logFactor: 0.9, foodLogProb: 0.9),
  PersonSpec(
      name: 'Guesser (±25% per-day noise, no bias)',
      trueTdee: 2600,
      logFactor: 1.0,
      logNoiseSd: 0.25,
      foodLogProb: 0.9),
  PersonSpec(
      name: 'Improving logger (0.70 → 0.95 over 120d)',
      trueTdee: 2600,
      logFactor: 0.7,
      logFactorEnd: 0.95,
      logNoiseSd: 0.1,
      foodLogProb: 0.9),
];

double _mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;

String _pad(String s, int w) => s.padRight(w);
String _num(double v, int w, [int dp = 0]) => v.toStringAsFixed(dp).padLeft(w);

class Stats {
  final double meanErrPct;
  final double p10;
  final double p90;
  final double meanRate;
  final double floorPct;
  const Stats(this.meanErrPct, this.p10, this.p90, this.meanRate, this.floorPct);
}

Stats _statsFor(List<SimResult> runs, double goalRate) {
  final errs = <double>[];
  final rates = <double>[];
  final floors = <double>[];
  for (final r in runs) {
    final rate = actualRateKgPerWeek(r.days);
    if (rate == null) continue;
    rates.add(rate);
    errs.add(goalRate == 0 ? 0 : ((rate - goalRate) / goalRate).abs() * 100);
    floors.add(r.days.where((d) => d.clamped).length / r.days.length * 100);
  }
  final sorted = [...errs]..sort();
  double at(double q) {
    final i = (q * sorted.length).floor();
    return sorted[i < sorted.length ? i : sorted.length - 1];
  }

  return Stats(_mean(errs), at(0.1), at(0.9), _mean(rates), _mean(floors));
}

void _run(PersonSpec spec, int seedBase) {
  final goalRate = profile.goal is LoseGoal ? -(profile.goal as LoseGoal).kgPerWeek : 0.0;
  final formulaAtStart = formulaTdee(profile, spec.startWeightKg, simYear - profile.birthYear);

  print('');
  print('═' * 74);
  print('  ${spec.name}');
  print('═' * 74);
  print('  true TDEE ${spec.trueTdee.round()} kcal   ·   formula says '
      '${formulaAtStart.round()} kcal   ·   off by '
      '${(formulaAtStart - spec.trueTdee).round()}');

  final runs = <Coach, List<SimResult>>{Coach.adaptive: [], Coach.formulaOnly: []};
  for (var i = 0; i < seeds; i++) {
    final seed = seedBase + i * 7919;
    runs[Coach.adaptive]!.add(simulate(profile, spec, Coach.adaptive, totalDays, seed));
    runs[Coach.formulaOnly]!.add(simulate(profile, spec, Coach.formulaOnly, totalDays, seed));
  }

  print('');
  print('  Achieved rate of loss over the final 30 days — mean of $seeds seeds');
  print('─' * 74);
  print('  ${_pad('goal', 18)}${_num(goalRate, 7, 2)} kg/wk');

  for (final coach in [Coach.adaptive, Coach.formulaOnly]) {
    final st = _statsFor(runs[coach]!, goalRate);
    final label = coach == Coach.adaptive ? 'TrueBurn' : 'formula-only';
    print('  ${_pad(label, 18)}${_num(st.meanRate, 7, 2)} kg/wk   '
        '${_pad('off by ${st.meanErrPct.round()}%', 14)}'
        '${_pad('(p10–p90 ${st.p10.round()}–${st.p90.round()}%)', 22)}'
        'floor ${st.floorPct.round()}%');
  }

  // True expenditure drifts down as mass comes off; a static formula cannot see this,
  // so the engine is chasing a moving target rather than a fixed one. Printed because
  // the parity check is only as strong as what both harnesses put on stdout — this line
  // was in the TypeScript report and not here, so six numbers went uncompared.
  final first = runs[Coach.adaptive]!.first;
  if (first.days.isNotEmpty) {
    print('  ${_pad('', 18)}true TDEE drifted ${spec.trueTdee.round()} → '
        '${first.days.last.trueTdeeToday.round()} kcal as weight came off');
  }
}

void main() {
  print('');
  print('  BASELINE — adaptive TDEE convergence (Dart port)');
  print('  $totalDays simulated days · goal 0.5 kg/week loss · seeded, reproducible');

  for (var i = 0; i < scenarios.length; i++) {
    _run(scenarios[i], 1337 + i * 101);
  }
  print('');
}
