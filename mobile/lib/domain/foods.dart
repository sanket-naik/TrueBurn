/// Seed food list.
///
/// Portions in natural units by default — "1 katori", "1 roti". Asking for grams on a
/// roti is entry friction, and friction is what stops people logging (§5.2).
///
/// **But grams where grams are how the food is actually handled.** "Chicken breast,
/// 1 piece" is not a natural unit, it is a vague one — a piece is anywhere from 80 g to
/// 250 g, and that spread is exactly the guessing noise the natural-units rule exists to
/// avoid (§10.3). For meat, nuts, cheese and anything bought by weight, 100 g is both
/// more precise *and* less effort, because the packet already says it. The rule is
/// "whichever unit the user does not have to estimate", which is natural units for
/// cooked dishes and grams for weighed ingredients.
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
  Food('Chicken breast, grilled', '100 g', 165),
  Food('Paneer, raw', '50 g', 145),
  Food('Tofu', '100 g', 145),
  Food('Curd / dahi', '1 katori', 100),
  Food('Greek yogurt', '1 cup', 130),
  Food('Whey protein', '1 scoop', 120),
  Food('Peanuts', '100 g', 567),
  Food('Almonds', '10 almonds', 70),
  Food('Almonds, weighed', '100 g', 579),
  Food('Cashews', '100 g', 553),
  Food('Walnuts', '100 g', 654),
  Food('Cheese, cheddar', '100 g', 402),
  Food('Chicken, cooked', '100 g', 239),
  Food('Mutton, cooked', '100 g', 294),
  Food('Fish, cooked', '100 g', 206),
  Food('Prawns, cooked', '100 g', 99),
  Food('Soya chunks, dry', '100 g', 345),
  Food('Oats, dry', '100 g', 389),
  Food('Muesli', '100 g', 375),
  Food('Dates', '100 g', 277),
  Food('Boiled potato', '100 g', 87),
  Food('Sweet potato, boiled', '100 g', 76),
  Food('Sweet corn', '100 g', 96),
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

  // ---- breads & grains
  Food('Roti, multigrain', '1 roti', 130),
  Food('Bajra roti', '1 roti', 110),
  Food('Jowar roti', '1 roti', 105),
  Food('Missi roti', '1 roti', 175),
  Food('Aloo paratha', '1 paratha', 300),
  Food('Paneer paratha', '1 paratha', 330),
  Food('Butter naan', '1 naan', 320),
  Food('Tandoori roti', '1 roti', 140),
  Food('Kulcha', '1 kulcha', 230),
  Food('Puri', '1 puri', 100),
  Food('Bhatura', '1 bhatura', 300),
  Food('Brown bread slice', '1 slice', 70),
  Food('Pav', '1 pav', 130),
  Food('Rice, brown cooked', '1 katori', 195),
  Food('Curd rice', '1 katori', 230),
  Food('Lemon rice', '1 katori', 250),
  Food('Fried rice, veg', '1 plate', 340),
  Food('Khichdi', '1 katori', 200),
  Food('Daliya', '1 katori', 160),
  Food('Quinoa, cooked', '1 katori', 140),
  Food('Pasta, cooked', '1 katori', 200),
  Food('Noodles, cooked', '1 katori', 220),

  // ---- south indian
  Food('Rava dosa', '1 dosa', 240),
  Food('Rasam', '1 katori', 60),
  Food('Coconut chutney', '2 tbsp', 90),
  Food('Appam', '1 appam', 120),
  Food('Puttu', '1 serving', 200),

  // ---- dals & curries
  Food('Dal fry', '1 katori', 170),
  Food('Chana masala', '1 katori', 220),
  Food('Kadhi', '1 katori', 160),
  Food('Shahi paneer', '1 katori', 330),
  Food('Malai kofta', '1 katori', 360),
  Food('Aloo gobi', '1 katori', 150),
  Food('Aloo matar', '1 katori', 170),
  Food('Baingan bharta', '1 katori', 160),
  Food('Mixed veg curry', '1 katori', 165),
  Food('Butter chicken', '1 katori', 340),
  Food('Chicken tikka masala', '1 katori', 320),
  Food('Tandoori chicken', '2 pieces', 260),
  Food('Chicken tikka', '4 pieces', 220),
  Food('Fish fry', '1 piece', 200),
  Food('Prawn curry', '1 katori', 230),
  Food('Keema', '1 katori', 300),

  // ---- snacks & street
  Food('Idli sambar', '2 idli', 180),
  Food('Sabudana khichdi', '1 plate', 300),
  Food('Dhokla', '2 pieces', 120),
  Food('Khandvi', '3 pieces', 110),
  Food('Chole bhature', '1 plate', 650),
  Food('Momos, veg', '6 pieces', 250),
  Food('Momos, chicken', '6 pieces', 290),
  Food('Spring roll', '1 roll', 180),
  Food('Frankie / roll', '1 roll', 350),
  Food('Chicken shawarma', '1 roll', 400),
  Food('Burger, veg', '1 burger', 350),
  Food('Burger, chicken', '1 burger', 450),
  Food('Pizza slice', '1 slice', 270),
  Food('French fries', '1 small', 230),
  Food('Sev puri', '1 plate', 230),
  Food('Pani puri', '6 pieces', 180),
  Food('Dahi puri', '1 plate', 260),
  Food('Aloo tikki', '1 piece', 150),
  Food('Kachori', '1 piece', 190),
  Food('Poppadom', '1 papad', 45),
  Food('Murukku', '2 pieces', 110),
  Food('Bhujia / namkeen', '1 handful', 150),
  Food('Popcorn, plain', '1 bowl', 100),

  // ---- eggs & protein
  Food('Egg white, boiled', '1 egg', 17),
  Food('Egg bhurji', '2 eggs', 240),
  Food('Egg, fried', '1 egg', 90),
  Food('Paneer, grilled', '100 g', 265),
  Food('Tofu, grilled', '100 g', 160),
  Food('Soya chunks, cooked', '1 katori', 180),
  Food('Peanut butter', '1 tbsp', 95),
  Food('Sprouts salad', '1 katori', 110),

  // ---- fruit & veg
  Food('Grapes', '1 bowl', 90),
  Food('Watermelon', '1 bowl', 45),
  Food('Pomegranate', '1 bowl', 85),
  Food('Guava', '1 guava', 65),
  Food('Pear', '1 pear', 100),
  Food('Chikoo', '1 chikoo', 95),
  Food('Pineapple', '1 bowl', 80),
  Food('Custard apple', '1 fruit', 145),
  Food('Coconut water', '1 glass', 45),
  Food('Cucumber', '1 bowl', 20),
  Food('Carrot', '1 carrot', 25),
  Food('Tomato', '1 tomato', 20),
  Food('Sprouted moong', '1 katori', 100),
  Food('Boiled corn', '1 cob', 100),

  // ---- dairy & drinks
  Food('Milk, toned', '1 glass', 110),
  Food('Milk, skimmed', '1 glass', 85),
  Food('Curd, low fat', '1 katori', 70),
  Food('Paneer tikka', '4 pieces', 250),
  Food('Cheese slice', '1 slice', 70),
  Food('Masala chai', '1 cup', 100),
  Food('Green tea', '1 cup', 2),
  Food('Cold coffee', '1 glass', 220),
  Food('Filter coffee', '1 cup', 90),
  Food('Salted lassi', '1 glass', 110),
  Food('Mango shake', '1 glass', 280),
  Food('Banana shake', '1 glass', 250),
  Food('Fresh lime soda', '1 glass', 90),
  Food('Iced tea', '1 glass', 90),
  Food('Diet cola', '1 can', 2),
  Food('Whisky, 30 ml', '1 peg', 70),
  Food('Wine', '1 glass', 125),

  // ---- sweets
  Food('Gulab jamun', '1 piece', 150),
  Food('Rasgulla', '1 piece', 106),
  Food('Jalebi', '2 pieces', 200),
  Food('Ladoo', '1 piece', 185),
  Food('Barfi', '1 piece', 130),
  Food('Halwa', '1 katori', 280),
  Food('Kheer', '1 katori', 250),
  Food('Ice cream', '1 scoop', 140),
  Food('Chocolate bar', '1 bar', 250),
  Food('Biscuit, cream', '2 biscuits', 100),
  Food('Rusk', '2 pieces', 100),
  Food('Cake slice', '1 slice', 300),
  Food('Jaggery', '1 tsp', 20),
  Food('Honey', '1 tsp', 22),

  // ---- fats & extras
  Food('Mayonnaise', '1 tbsp', 90),
  Food('Tomato ketchup', '1 tbsp', 20),
  Food('Olive oil', '1 tbsp', 120),
  Food('Cream', '1 tbsp', 50),
  Food('Pickle', '1 tsp', 25),
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
/// Browse groups, optionally led by what this user usually eats at this hour.
///
/// [habitual] is food names ordered by how often they appear in the current meal, from
/// `domain/insights.dart`. Recency alone puts last night's biryani at the top of the
/// breakfast list; what people want is what they normally eat *now*. Passing an empty
/// list gives the old recency-only behaviour, which is what a new user gets.
List<FoodGroup> browseGroups(
  List<String> recents,
  List<Food> custom, {
  List<String> habitual = const [],
  String habitLabel = 'Usually now',
}) {
  final all = [...custom, ...seedFoods];
  Food? find(String n) {
    final hit = all.where((f) => f.n == n);
    return hit.isEmpty ? null : hit.first;
  }

  final usual = <Food>[for (final n in habitual) ?find(n)];
  final taken = usual.map((f) => f.n).toSet();

  final rec = <Food>[
    for (final n in recents)
      if (!taken.contains(n)) ?find(n),
  ];
  taken.addAll(rec.map((f) => f.n));

  final mine = custom.where((f) => !taken.contains(f.n)).toList();
  final rest = seedFoods.where((f) => !taken.contains(f.n)).toList()
    ..sort((a, b) => a.k - b.k);

  return [
    FoodGroup(habitLabel, usual),
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
