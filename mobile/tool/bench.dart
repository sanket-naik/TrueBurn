import 'package:trueburn/core/report.dart';
import 'package:trueburn/core/types.dart';
import 'package:trueburn/core/weight_trend.dart';

void main() {
  const profile = Profile(
    heightCm: 175, birthYear: 1994,
    formulaVariant: FormulaVariant.mifflinMale,
    activityLevel: ActivityLevel.light, goal: LoseGoal(0.5));

  for (final days in [30, 180, 365]) {
    final w = <WeighIn>[]; final f = <FoodEntry>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime.utc(2025, 8, 18).add(Duration(days: i));
      final date = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      w.add(WeighIn(date, 82 - i * 0.01));
      // a realistic day is several entries, not one
      for (var k = 0; k < 5; k++) { f.add(FoodEntry(date, 400, 'item')); }
    }
    final log = LogBook(weighIns: w, food: f);
    final asOf = w.last.date;

    final sw = Stopwatch()..start();
    const n = 300;
    for (var i = 0; i < n; i++) { dailyReport(profile, log, asOf, 2026); }
    sw.stop();
    final per = sw.elapsedMicroseconds / n;

    final sw2 = Stopwatch()..start();
    for (var i = 0; i < n; i++) { weightTrend(w); }
    sw2.stop();

    print('${days.toString().padLeft(3)} days (${f.length} food entries): '
        'dailyReport ${per.toStringAsFixed(0)}us   '
        'weightTrend ${(sw2.elapsedMicroseconds / n).toStringAsFixed(0)}us   '
        '=> ${(per / 16666 * 100).toStringAsFixed(1)}% of a 60fps frame budget');
  }
}
