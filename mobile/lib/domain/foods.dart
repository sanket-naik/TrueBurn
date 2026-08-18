/// Seed food list.
///
/// Portions in natural units — "1 katori", "1 roti" — never grams. Asking for grams is
/// the largest single source of entry friction and of the guessing noise that biases the
/// expenditure measurement downward (§5.2, §10.3).
///
/// ~70 items here; §5.2 puts the shipping target at 150–300. This is scaffolding: after
/// about two weeks a user's own history is their database.
library;

class Food {
  final String n;
  final String u;
  final int k;
  const Food(this.n, this.u, this.k);

  Map<String, dynamic> toJson() => {'n': n, 'u': u, 'k': k};
  static Food fromJson(Map<String, dynamic> j) =>
      Food(j['n'] as String, j['u'] as String, j['k'] as int);
}

const List<Food> seedFoods = [
  Food('Roti / chapati', '1 roti', 120),
  Food('Paratha, plain', '1 paratha', 210),
  Food('Naan', '1 naan', 260),
  Food('Rice, cooked', '1 katori', 205),
  Food('Jeera rice', '1 katori', 240),
  Food('Veg pulao', '1 katori', 230),
  Food('Chicken biryani', '1 plate', 490),
  Food('Bread slice', '1 slice', 75),
  Food('Poha', '1 plate', 250),
  Food('Upma', '1 plate', 270),
  Food('Idli', '1 idli', 58),
  Food('Dosa, plain', '1 dosa', 165),
  Food('Masala dosa', '1 dosa', 290),
  Food('Uttapam', '1 uttapam', 230),
  Food('Medu vada', '1 vada', 145),
  Food('Oats, cooked', '1 bowl', 160),
  Food('Muesli with milk', '1 bowl', 230),
  Food('Cornflakes with milk', '1 bowl', 210),
  Food('Dal tadka', '1 katori', 180),
  Food('Dal makhani', '1 katori', 280),
  Food('Rajma', '1 katori', 215),
  Food('Chole', '1 katori', 240),
  Food('Sambar', '1 katori', 140),
  Food('Paneer butter masala', '1 katori', 330),
  Food('Palak paneer', '1 katori', 275),
  Food('Mixed veg sabzi', '1 katori', 150),
  Food('Aloo sabzi', '1 katori', 190),
  Food('Bhindi masala', '1 katori', 165),
  Food('Chicken curry', '1 katori', 290),
  Food('Egg curry', '1 katori', 240),
  Food('Fish curry', '1 katori', 250),
  Food('Mutton curry', '1 katori', 350),
  Food('Egg, boiled', '1 egg', 78),
  Food('Omelette, 2 egg', '1 omelette', 220),
  Food('Chicken breast, grilled', '1 piece', 165),
  Food('Paneer, raw', '50 g', 145),
  Food('Tofu', '100 g', 145),
  Food('Curd / dahi', '1 katori', 100),
  Food('Greek yogurt', '1 cup', 130),
  Food('Whey protein', '1 scoop', 120),
  Food('Peanuts', '1 handful', 170),
  Food('Almonds', '10 almonds', 70),
  Food('Samosa', '1 samosa', 260),
  Food('Pakora', '4 pieces', 220),
  Food('Bhel puri', '1 plate', 210),
  Food('Pav bhaji', '1 plate', 400),
  Food('Vada pav', '1 piece', 290),
  Food('Veg sandwich', '1 sandwich', 250),
  Food('Maggi noodles', '1 pack', 310),
  Food('Marie biscuits', '4 biscuits', 95),
  Food('Potato chips', '1 small pack', 160),
  Food('Dark chocolate', '2 squares', 110),
  Food('Tea with milk & sugar', '1 cup', 90),
  Food('Coffee with milk', '1 cup', 80),
  Food('Black coffee', '1 cup', 5),
  Food('Milk, full fat', '1 glass', 150),
  Food('Buttermilk', '1 glass', 60),
  Food('Sweet lassi', '1 glass', 260),
  Food('Orange juice', '1 glass', 110),
  Food('Cola', '1 can', 140),
  Food('Beer', '1 bottle', 145),
  Food('Banana', '1 banana', 105),
  Food('Apple', '1 apple', 95),
  Food('Orange', '1 orange', 62),
  Food('Mango', '1 mango', 200),
  Food('Papaya', '1 bowl', 60),
  Food('Green salad', '1 bowl', 45),
  Food('Ghee', '1 tsp', 45),
  Food('Cooking oil', '1 tbsp', 120),
  Food('Butter', '1 tsp', 36),
  Food('Sugar', '1 tsp', 16),
];

enum Meal { breakfast, lunch, snack, dinner }

extension MealLabel on Meal {
  String get label => switch (this) {
        Meal.breakfast => 'Breakfast',
        Meal.lunch => 'Lunch',
        Meal.snack => 'Snack',
        Meal.dinner => 'Dinner',
      };
}

Meal mealFor(int minutes) => minutes < 11 * 60
    ? Meal.breakfast
    : minutes < 16 * 60
        ? Meal.lunch
        : minutes < 19 * 60
            ? Meal.snack
            : Meal.dinner;

class FoodGroup {
  final String label;
  final List<Food> items;
  const FoodGroup(this.label, this.items);
}

/// Browse order: recents in recency order, then everything else lightest-first.
///
/// Never length-capped. A cap on top of a lightest-first sort silently buries every
/// heavy item — biryani, samosa, pav bhaji — where browsing cannot reach them.
List<FoodGroup> browseGroups(List<String> recents, List<Food> custom) {
  final all = [...custom, ...seedFoods];
  final rec = <Food>[];
  for (final n in recents) {
    final hit = all.where((f) => f.n == n);
    if (hit.isNotEmpty) rec.add(hit.first);
  }
  final mine = custom.where((f) => !recents.contains(f.n)).toList();
  final rest = seedFoods.where((f) => !recents.contains(f.n)).toList()
    ..sort((a, b) => a.k - b.k);

  return [
    FoodGroup('Recent', rec),
    FoodGroup('Your foods', mine),
    FoodGroup('All foods · lightest first', rest),
  ].where((g) => g.items.isNotEmpty).toList();
}

List<Food> searchFoods(String q, List<String> recents, List<Food> custom) {
  final needle = q.trim().toLowerCase();
  final hit =
      [...custom, ...seedFoods].where((f) => f.n.toLowerCase().contains(needle)).toList();
  final inRecents = hit.where((f) => recents.contains(f.n)).toList();
  final others = hit.where((f) => !recents.contains(f.n)).toList()
    ..sort((a, b) => a.k - b.k);
  return [...inRecents, ...others];
}
