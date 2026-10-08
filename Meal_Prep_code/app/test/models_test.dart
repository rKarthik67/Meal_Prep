import 'package:flutter_test/flutter_test.dart';
import 'package:meal_prep/models.dart';
import 'package:meal_prep/widgets/common.dart';
import 'package:meal_prep/widgets/emoji_art.dart';

void main() {
  test('Cook.fromJson parses API payload', () {
    final cook = Cook.fromJson({
      'user_id': 1,
      'name': 'Lakshmi Amma',
      'bio': 'South Indian',
      'cuisines': ['South Indian'],
      'languages': ['Kannada'],
      'service_pincodes': ['560041'],
      'veg_only': true,
      'experience_years': 12,
      'hourly_rate': 300,
      'rating_avg': 4,
      'rating_count': 1,
      'verified': true,
      'is_active': true,
      'dishes': [
        {'id': 1, 'name': 'Bisi Bele Bath', 'cuisine': 'Karnataka', 'is_veg': true, 'prep_minutes': 60},
      ],
    });
    expect(cook.ratingAvg, 4.0);
    expect(cook.dishes.single.name, 'Bisi Bele Bath');
  });

  test('MealPlanDetail parses nutrition and days', () {
    final macros = {'kcal': 300, 'protein': 10.5, 'carbs': 40, 'fat': 8.0, 'fibre': 4};
    final plan = MealPlanDetail.fromJson({
      'id': 3, 'title': 'Test', 'subtitle': '', 'emoji': '🍛', 'color': '#E5632B', 'goal': 'balanced',
      'goal_label': 'Balanced', 'diet': 'veg', 'cuisine': 'Mixed', 'tags': ['x'], 'is_template': true,
      'created_by_ai': false, 'days_count': 1, 'avg_kcal': 300, 'avg_protein': 10.5, 'description': 'd',
      'days': [
        {'day': 1, 'label': 'Mon', 'totals': macros, 'meals': [
          {'slot': 'lunch', 'name': 'Rice', 'emoji': '🍚', 'cuisine': '', 'diet': 'veg', 'servings': 1, ...macros},
        ]},
      ],
      'nutrition': {
        'per_day': [{'day': 1, 'label': 'Mon', ...macros}],
        'daily_average': macros,
        'macro_split_pct': {'protein': 14, 'carbs': 53, 'fat': 24},
      },
    });
    expect(plan.days.single.meals.single.macros.protein, 10.5);
    expect(plan.nutrition.perDay.single.$1, 'Mon');
    expect(plan.summary.tags, ['x']);
  });

  test('Indian rupee grouping', () {
    expect(rupees(950), '₹950');
    expect(rupees(12500), '₹12,500');
    expect(rupees(1234567), '₹12,34,567');
  });

  test('3D emoji asset lookup', () {
    expect(emojiAsset('🍛'), 'assets/emoji/emoji_u1f35b.png');
    expect(emojiAsset('🌶️'), 'assets/emoji/emoji_u1f336.png'); // variation selector ignored
    expect(emojiAsset('🧑‍🍳'), 'assets/emoji/emoji_u1f9d1_200d_1f373.png');
    expect(emojiAsset('🛸'), isNull);
  });
}
