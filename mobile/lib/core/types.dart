/// Core domain types.
///
/// Nothing in `lib/core/` may import a Flutter API — no widgets, no plugins, no
/// DateTime.now(). The engine is a pure function of (Profile, LogBook, asOfDate).
/// That is what lets the whole thing be proven headlessly by `tool/sim.dart`,
/// exactly as the TypeScript original is proven by `src/sim/`.
library;

/// Local calendar date, `YYYY-MM-DD`.
typedef ISODate = String;

/// Which Mifflin–St Jeor constant to use for the cold-start estimate.
///
/// Chosen by the user directly rather than inferred from a gender field: the formula
/// is a population regression with two published variants, and asking which one fits
/// is both more honest and less presumptuous than deriving it.
enum FormulaVariant { mifflinMale, mifflinFemale }

/// Cold-start only. Discarded once measurement takes over.
enum ActivityLevel { sedentary, light, moderate, active }

sealed class Goal {
  const Goal();
}

class LoseGoal extends Goal {
  final double kgPerWeek;
  const LoseGoal(this.kgPerWeek);
}

class MaintainGoal extends Goal {
  const MaintainGoal();
}

class GainGoal extends Goal {
  final double kgPerWeek;
  const GainGoal(this.kgPerWeek);
}

class Profile {
  final double heightCm;
  final int birthYear;
  final FormulaVariant formulaVariant;

  /// Only consulted while confidence < 1.
  final ActivityLevel activityLevel;
  final Goal goal;

  const Profile({
    required this.heightCm,
    required this.birthYear,
    required this.formulaVariant,
    required this.activityLevel,
    required this.goal,
  });

  Profile copyWith({
    double? heightCm,
    int? birthYear,
    FormulaVariant? formulaVariant,
    ActivityLevel? activityLevel,
    Goal? goal,
  }) =>
      Profile(
        heightCm: heightCm ?? this.heightCm,
        birthYear: birthYear ?? this.birthYear,
        formulaVariant: formulaVariant ?? this.formulaVariant,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
      );
}

class WeighIn {
  final ISODate date;
  final double kg;
  const WeighIn(this.date, this.kg);
}

class FoodEntry {
  final ISODate date;
  final double kcal;
  final String label;
  const FoodEntry(this.date, this.kcal, this.label);
}

class WaterEntry {
  final ISODate date;
  final int ml;
  const WaterEntry(this.date, this.ml);
}

class LogBook {
  final List<WeighIn> weighIns;
  final List<FoodEntry> food;
  final List<WaterEntry> water;
  const LogBook({this.weighIns = const [], this.food = const [], this.water = const []});
}

/// Energy density of body-mass change. Standard figure; assumes fat mass.
const double kcalPerKg = 7700;

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
double clamp01(double v) => clampD(v, 0, 1);
