/**
 * Seed food list.
 *
 * Portions in natural units — "1 katori", "1 roti" — never grams. Asking for grams is
 * the largest single source of entry friction and of the guessing noise that biases the
 * expenditure measurement downward (REQUIREMENTS §5.2, §10.3).
 *
 * ~70 items here; §5.2 puts the shipping target at 150–300. This is scaffolding: after
 * about two weeks a user's own history is their database.
 */

export interface Food {
  n: string;
  u: string;
  k: number;
}

export const FOODS: Food[] = [
  { n: 'Roti / chapati', u: '1 roti', k: 120 },
  { n: 'Paratha, plain', u: '1 paratha', k: 210 },
  { n: 'Naan', u: '1 naan', k: 260 },
  { n: 'Rice, cooked', u: '1 katori', k: 205 },
  { n: 'Jeera rice', u: '1 katori', k: 240 },
  { n: 'Veg pulao', u: '1 katori', k: 230 },
  { n: 'Chicken biryani', u: '1 plate', k: 490 },
  { n: 'Bread slice', u: '1 slice', k: 75 },
  { n: 'Poha', u: '1 plate', k: 250 },
  { n: 'Upma', u: '1 plate', k: 270 },
  { n: 'Idli', u: '1 idli', k: 58 },
  { n: 'Dosa, plain', u: '1 dosa', k: 165 },
  { n: 'Masala dosa', u: '1 dosa', k: 290 },
  { n: 'Uttapam', u: '1 uttapam', k: 230 },
  { n: 'Medu vada', u: '1 vada', k: 145 },
  { n: 'Oats, cooked', u: '1 bowl', k: 160 },
  { n: 'Muesli with milk', u: '1 bowl', k: 230 },
  { n: 'Cornflakes with milk', u: '1 bowl', k: 210 },
  { n: 'Dal tadka', u: '1 katori', k: 180 },
  { n: 'Dal makhani', u: '1 katori', k: 280 },
  { n: 'Rajma', u: '1 katori', k: 215 },
  { n: 'Chole', u: '1 katori', k: 240 },
  { n: 'Sambar', u: '1 katori', k: 140 },
  { n: 'Paneer butter masala', u: '1 katori', k: 330 },
  { n: 'Palak paneer', u: '1 katori', k: 275 },
  { n: 'Mixed veg sabzi', u: '1 katori', k: 150 },
  { n: 'Aloo sabzi', u: '1 katori', k: 190 },
  { n: 'Bhindi masala', u: '1 katori', k: 165 },
  { n: 'Chicken curry', u: '1 katori', k: 290 },
  { n: 'Egg curry', u: '1 katori', k: 240 },
  { n: 'Fish curry', u: '1 katori', k: 250 },
  { n: 'Mutton curry', u: '1 katori', k: 350 },
  { n: 'Egg, boiled', u: '1 egg', k: 78 },
  { n: 'Omelette, 2 egg', u: '1 omelette', k: 220 },
  { n: 'Chicken breast, grilled', u: '1 piece', k: 165 },
  { n: 'Paneer, raw', u: '50 g', k: 145 },
  { n: 'Tofu', u: '100 g', k: 145 },
  { n: 'Curd / dahi', u: '1 katori', k: 100 },
  { n: 'Greek yogurt', u: '1 cup', k: 130 },
  { n: 'Whey protein', u: '1 scoop', k: 120 },
  { n: 'Peanuts', u: '1 handful', k: 170 },
  { n: 'Almonds', u: '10 almonds', k: 70 },
  { n: 'Samosa', u: '1 samosa', k: 260 },
  { n: 'Pakora', u: '4 pieces', k: 220 },
  { n: 'Bhel puri', u: '1 plate', k: 210 },
  { n: 'Pav bhaji', u: '1 plate', k: 400 },
  { n: 'Vada pav', u: '1 piece', k: 290 },
  { n: 'Veg sandwich', u: '1 sandwich', k: 250 },
  { n: 'Maggi noodles', u: '1 pack', k: 310 },
  { n: 'Marie biscuits', u: '4 biscuits', k: 95 },
  { n: 'Potato chips', u: '1 small pack', k: 160 },
  { n: 'Dark chocolate', u: '2 squares', k: 110 },
  { n: 'Tea with milk & sugar', u: '1 cup', k: 90 },
  { n: 'Coffee with milk', u: '1 cup', k: 80 },
  { n: 'Black coffee', u: '1 cup', k: 5 },
  { n: 'Milk, full fat', u: '1 glass', k: 150 },
  { n: 'Buttermilk', u: '1 glass', k: 60 },
  { n: 'Sweet lassi', u: '1 glass', k: 260 },
  { n: 'Orange juice', u: '1 glass', k: 110 },
  { n: 'Cola', u: '1 can', k: 140 },
  { n: 'Beer', u: '1 bottle', k: 145 },
  { n: 'Banana', u: '1 banana', k: 105 },
  { n: 'Apple', u: '1 apple', k: 95 },
  { n: 'Orange', u: '1 orange', k: 62 },
  { n: 'Mango', u: '1 mango', k: 200 },
  { n: 'Papaya', u: '1 bowl', k: 60 },
  { n: 'Green salad', u: '1 bowl', k: 45 },
  { n: 'Ghee', u: '1 tsp', k: 45 },
  { n: 'Cooking oil', u: '1 tbsp', k: 120 },
  { n: 'Butter', u: '1 tsp', k: 36 },
  { n: 'Sugar', u: '1 tsp', k: 16 },
];

export type Meal = 'breakfast' | 'lunch' | 'snack' | 'dinner';

export const MEALS: { k: Meal; label: string }[] = [
  { k: 'breakfast', label: 'Breakfast' },
  { k: 'lunch', label: 'Lunch' },
  { k: 'snack', label: 'Snack' },
  { k: 'dinner', label: 'Dinner' },
];

export const mealFor = (minutes: number): Meal =>
  minutes < 11 * 60 ? 'breakfast' : minutes < 16 * 60 ? 'lunch' : minutes < 19 * 60 ? 'snack' : 'dinner';

export const mealLabel = (m: Meal): string => MEALS.find((x) => x.k === m)?.label ?? 'Snack';

/**
 * Browse order: recents in recency order, then everything else lightest-first.
 *
 * Never length-capped. A cap on top of a lightest-first sort silently buries every heavy
 * item — biryani, samosa, pav bhaji — where browsing cannot reach them.
 */
export function browseGroups(
  recents: string[],
  custom: Food[],
): { label: string; items: Food[] }[] {
  const all = [...custom, ...FOODS];
  const rec = recents.map((n) => all.find((x) => x.n === n)).filter((x): x is Food => !!x);
  const mine = custom.filter((x) => !recents.includes(x.n));
  const rest = FOODS.filter((x) => !recents.includes(x.n)).sort((a, b) => a.k - b.k);
  return [
    { label: 'Recent', items: rec },
    { label: 'Your foods', items: mine },
    { label: 'All foods · lightest first', items: rest },
  ].filter((g) => g.items.length > 0);
}

export function search(q: string, recents: string[], custom: Food[]): Food[] {
  const needle = q.trim().toLowerCase();
  const hit = [...custom, ...FOODS].filter((x) => x.n.toLowerCase().includes(needle));
  const inRecents = hit.filter((x) => recents.includes(x.n));
  const others = hit.filter((x) => !recents.includes(x.n)).sort((a, b) => a.k - b.k);
  return [...inRecents, ...others];
}
