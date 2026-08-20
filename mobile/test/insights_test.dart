/// The insight layer, which is the part most likely to be quietly wrong.
///
/// A miscomputed drift figure tells someone they are lying about their food when they
/// are not, so the direction and the thresholds get their own tests rather than being
/// eyeballed on a screen.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:trueburn/domain/foods.dart';
import 'package:trueburn/core/tdee.dart';
import 'package:trueburn/domain/insights.dart';

LoggedItem item(
  String date,
  String name, {
  double qty = 1,
  int kcal = 100,
  Meal meal = Meal.breakfast,
}) => (date: date, name: name, unit: '1 serving', qty: qty, kcal: kcal, meal: meal);

TdeeResult tdee({
  double? measured,
  double formula = 2400,
  double confidence = 0.9,
}) => TdeeResult(
      kcal: measured ?? formula,
      mode: measured == null ? TdeeMode.formula : TdeeMode.measured,
      confidence: confidence,
      measured: measured,
      formula: formula,
      notes: const [],
    );

void main() {
  group('drift detection', () {
    // The thresholds come from running the simulation's personas and averaging the
    // measured figure over their last 20 days:
    //
    //   honest logger      +3%      under-records 25%   -17%
    //   under-records 15%  -9%      under-records 40%   -32%
    //
    // These cases pin that evidence so a future tweak to the band has to face it.

    test('an honest logger is left alone', () {
      // +3% — the measurement landing slightly above the formula is normal.
      expect(detectDrift(tdee(measured: 2470, formula: 2400)).kind, DriftKind.none);
    });

    test('a gap inside the formula own error is not a finding', () {
      // -9%. Mifflin is +/-10-15% for an individual, so this is indistinguishable
      // from simply having a slower metabolism.
      expect(detectDrift(tdee(measured: 2184, formula: 2400)).kind, DriftKind.none);
    });

    test('a 25% under-recorder is deliberately NOT flagged', () {
      // -17.25%, just inside the bar. Lowering the threshold to catch this would put
      // it inside Mifflin's own +/-15% error, so it would start accusing people whose
      // metabolism is simply slow — a charge they cannot act on, because nothing is
      // wrong. §4.3 shows the engine tolerates systematic under-reporting anyway, so a
      // miss here costs far less than a false accusation.
      final d = detectDrift(tdee(measured: 1986, formula: 2400));
      expect(d.kind, DriftKind.none);
      expect((2400 - 1986) / 2400, closeTo(0.1725, 0.001));
    });

    test('a 30% under-recorder is caught', () {
      final d = detectDrift(tdee(measured: 1900, formula: 2400));
      expect(d.kind, DriftKind.underLogging);
      expect(d.kcalPerDay, closeTo(500, 1));
      expect(d.share, closeTo(0.208, 0.005));
    });

    test('a heavy under-recorder is caught with a bigger number', () {
      final d = detectDrift(tdee(measured: 1614, formula: 2400));
      expect(d.kind, DriftKind.underLogging);
      expect(d.kcalPerDay, closeTo(786, 1));
    });

    test('the upward direction needs a wider bar', () {
      // +25% is a plausible fast metabolism, so it stays quiet...
      expect(detectDrift(tdee(measured: 3000, formula: 2400)).kind, DriftKind.none);
      // ...but +33% is worth a word.
      expect(detectDrift(tdee(measured: 3200, formula: 2400)).kind, DriftKind.overLogging);
    });

    test('a green measurement is not evidence', () {
      expect(
        detectDrift(tdee(measured: 1600, formula: 2400, confidence: 0.4)).kind,
        DriftKind.none,
      );
    });

    test('no measurement at all reports nothing', () {
      expect(detectDrift(tdee()).kind, DriftKind.none);
    });

    test('kcalPerDay is always positive, whichever way the gap runs', () {
      expect(detectDrift(tdee(measured: 1600)).kcalPerDay, greaterThan(0));
      expect(detectDrift(tdee(measured: 3300)).kcalPerDay, greaterThan(0));
    });
  });

  group('portion memory offers what you actually eat', () {
    test('the mode, not the mean', () {
      final log = [
        for (var i = 0; i < 9; i++) item('2026-08-0$i', 'Roti', qty: 2),
        item('2026-08-19', 'Roti', qty: 5),
      ];
      // The mean is 2.3, a quantity nobody has ever eaten.
      expect(typicalQty(log, 'Roti'), 2);
    });

    test('one sighting is a coincidence, not a habit', () {
      expect(typicalQty([item('2026-08-01', 'Roti', qty: 3)], 'Roti'), isNull);
    });

    test('unknown food has no opinion', () {
      expect(typicalQty([item('2026-08-01', 'Roti')], 'Poha'), isNull);
    });

    test('ties go to the larger portion', () {
      final log = [
        item('2026-08-01', 'Roti', qty: 2),
        item('2026-08-02', 'Roti', qty: 3),
      ];
      expect(typicalQty(log, 'Roti'), 3);
    });
  });

  group('meal affinity beats recency', () {
    final log = [
      for (var i = 1; i <= 6; i++)
        item('2026-08-0$i', 'Poha', meal: Meal.breakfast),
      item('2026-08-07', 'Biryani', meal: Meal.dinner),
      item('2026-08-08', 'Biryani', meal: Meal.dinner),
      item('2026-08-09', 'Idli', meal: Meal.breakfast),
    ];

    test('a food is scored against the meal it belongs to', () {
      expect(mealAffinity(log, 'Poha', Meal.breakfast), 6);
      expect(mealAffinity(log, 'Poha', Meal.dinner), 0);
    });

    test('breakfast habits do not include last night dinner', () {
      final b = habitualFor(log, Meal.breakfast);
      expect(b.first, 'Poha');
      expect(b, isNot(contains('Biryani')));
    });

    test('a single appearance is not a habit', () {
      // Idli appears once at breakfast.
      expect(habitualFor(log, Meal.breakfast), isNot(contains('Idli')));
    });
  });

  group('repeat meal', () {
    final log = [
      item('2026-08-17', 'Poha', meal: Meal.breakfast, kcal: 250),
      item('2026-08-17', 'Tea', meal: Meal.breakfast, kcal: 90),
      item('2026-08-18', 'Idli', meal: Meal.breakfast, kcal: 150),
      item('2026-08-18', 'Dal', meal: Meal.lunch, kcal: 180),
    ];

    test('offers the most recent version of that meal', () {
      final r = repeatableMeal(log, Meal.breakfast, '2026-08-19')!;
      expect(r.date, '2026-08-18');
      expect(r.items.single.name, 'Idli');
      expect(r.kcal, 150);
    });

    test('sums every item in the meal', () {
      // A log where the newest breakfast is the two-item one, so it is the one offered.
      final twoItem = [
        item('2026-08-17', 'Poha', meal: Meal.breakfast, kcal: 250),
        item('2026-08-17', 'Tea', meal: Meal.breakfast, kcal: 90),
      ];
      final r = repeatableMeal(twoItem, Meal.breakfast, '2026-08-19')!;
      expect(r.date, '2026-08-17');
      expect(r.items.length, 2);
      expect(r.kcal, 340);
    });

    test('does not offer to repeat a meal already logged today', () {
      // Double-counting is the one outcome worse than an extra tap.
      expect(repeatableMeal(log, Meal.lunch, '2026-08-18'), isNull);
    });

    test('nothing to repeat when the meal has no history', () {
      expect(repeatableMeal(log, Meal.snack, '2026-08-19'), isNull);
    });
  });

  group('weigh-in sanity check', () {
    test('a normal day passes', () {
      expect(checkWeighIn(80.9, 80.2).verdict, WeighInVerdict.ok);
    });

    test('water weight is not an error', () {
      // Two kilos overnight is a heavy meal and a salty one, not a typo.
      expect(checkWeighIn(82.1, 80.2).verdict, WeighInVerdict.ok);
    });

    test('a slipped digit is caught', () {
      expect(checkWeighIn(88.0, 80.2).verdict, WeighInVerdict.farFromTrend);
      expect(checkWeighIn(70.0, 80.2).verdict, WeighInVerdict.farFromTrend);
    });

    test('the first ever weigh-in has no trend to fail against', () {
      expect(checkWeighIn(80.0, null).verdict, WeighInVerdict.ok);
    });

    test('the delta is signed, so the message can say which way', () {
      expect(checkWeighIn(88.0, 80.0).delta, closeTo(8, 1e-9));
      expect(checkWeighIn(72.0, 80.0).delta, closeTo(-8, 1e-9));
    });
  });
}
