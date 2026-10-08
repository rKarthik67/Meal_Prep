import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import '../ai/chat_screen.dart';
import '../customer/find_cooks_screen.dart';

class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final int planId;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  late Future<MealPlanDetail> _future = context.read<Session>().api.mealPlan(widget.planId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MealPlanDetail>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.hasError
                ? EmptyState(
                    emoji: '😕',
                    title: 'Couldn\'t load this plan',
                    message: '${snap.error}',
                    action: 'Retry',
                    onAction: () => setState(() => _future = context.read<Session>().api.mealPlan(widget.planId)),
                  )
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return _PlanView(plan: snap.data!);
      },
    );
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan});
  final MealPlanDetail plan;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: const Text('This removes it from your plans. Bookings that used it are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final session = context.read<Session>();
    try {
      await session.api.deletePlan(plan.summary.id);
      session.bump();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = plan.summary;
    final t = Theme.of(context).textTheme;
    final color = AppColors.fromHex(s.color);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 230,
              pinned: true,
              backgroundColor: color,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Ask AI about this plan',
                  icon: const Icon(Icons.auto_awesome_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        agentKey: 'nutrition_coach',
                        initialMessage: 'Tell me about the nutrition of plan #${s.id} (${s.title})',
                      ),
                    ),
                  ),
                ),
                if (!s.isTemplate)
                  IconButton(
                    tooltip: 'Delete plan',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  PlanCover(plan: s, height: 230),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 140,
                    bottom: 18,
                    child: Text(s.title,
                        maxLines: 2,
                        style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.subtitle, style: t.titleSmall),
                  if (plan.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(plan.description, style: t.bodyMedium?.copyWith(height: 1.45)),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _Kpi('🔥', '${plan.nutrition.dailyAverage.kcal}', 'kcal/day')),
                    Expanded(child: _Kpi('💪', '${plan.nutrition.dailyAverage.protein.round()} g', 'protein')),
                    Expanded(child: _Kpi('🥦', '${plan.nutrition.dailyAverage.fibre.round()} g', 'fibre')),
                    Expanded(child: _Kpi('📅', '${plan.days.length}', 'days')),
                  ]),
                ]),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                TabBar(
                  labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'Menu'), Tab(text: 'Nutrition'), Tab(text: 'Groceries')],
                ),
                Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
          body: TabBarView(children: [
            _MenuTab(plan: plan),
            _NutritionTab(plan: plan),
            _GroceryTab(plan: plan),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: GradientButton(
              label: 'Book a cook for this plan',
              icon: Icons.soup_kitchen_rounded,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindCooksScreen(
                    cuisine: s.cuisine == 'Mixed' ? null : s.cuisine,
                    mealType: 'meal_prep',
                    mealPlanId: s.id,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.emoji, this.value, this.label);
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      EmojiArt(emoji, size: 28),
      const SizedBox(height: 2),
      Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      Text(label, style: t.bodySmall),
    ]);
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader(this.tabBar, this.color);
  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: color, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) => oldDelegate.color != color;
}

// ------------------------------------------------------------------ menu
class _MenuTab extends StatefulWidget {
  const _MenuTab({required this.plan});
  final MealPlanDetail plan;

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    final days = widget.plan.days;
    final day = days[_day];
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final sel = i == _day;
            final c = Theme.of(context).colorScheme.primary;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _day = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                decoration: BoxDecoration(
                  color: sel ? c : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? c : Theme.of(context).dividerColor),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(days[i].label,
                      style: t.labelLarge?.copyWith(color: sel ? Colors.white : null, fontWeight: FontWeight.w700)),
                  Text('Day ${days[i].day}', style: t.labelSmall?.copyWith(color: sel ? Colors.white70 : null)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      for (final m in day.meals) _MealCard(meal: m),
      const SizedBox(height: 6),
      Card(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Macro('kcal', '${day.totals.kcal}', AppColors.saffron),
            _Macro('protein', '${day.totals.protein.round()}g', AppColors.protein),
            _Macro('carbs', '${day.totals.carbs.round()}g', AppColors.carbs),
            _Macro('fat', '${day.totals.fat.round()}g', AppColors.fat),
          ]),
        ),
      ),
    ]);
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final PlanMeal meal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            FoodTile(emoji: meal.emoji, size: 64, radius: 18, color: meal.diet == 'veg' ? AppColors.veg : AppColors.saffron),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text((slotLabels[meal.slot] ?? meal.slot).toUpperCase(),
                      style: t.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(width: 6),
                  VegDot(isVeg: meal.diet == 'veg', size: 12),
                  if (meal.servings != 1) ...[
                    const SizedBox(width: 6),
                    Text('× ${meal.servings}', style: t.labelSmall),
                  ],
                ]),
                Text(meal.name, style: t.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '${meal.macros.kcal} kcal · P ${meal.macros.protein.round()}g · C ${meal.macros.carbs.round()}g · F ${meal.macros.fat.round()}g',
                  style: t.bodySmall,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

// ------------------------------------------------------------------ nutrition
class _NutritionTab extends StatelessWidget {
  const _NutritionTab({required this.plan});
  final MealPlanDetail plan;

  @override
  Widget build(BuildContext context) {
    final n = plan.nutrition;
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      _ChartCard(title: 'Daily average', subtitle: 'Energy split from protein, carbs and fat', child: MacroDonut(nutrition: n)),
      _ChartCard(
        title: 'Calories across the week',
        child: TrendLine(values: [for (final d in n.perDay) (d.$1, d.$2.kcal.toDouble())], color: AppColors.saffron),
      ),
      _ChartCard(
        title: 'Macros per day',
        subtitle: 'Grams of protein, carbs and fat',
        child: Column(children: [
          MacroStackChart(nutrition: n),
          const SizedBox(height: 8),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendDot('Protein', AppColors.protein),
            _LegendDot('Carbs', AppColors.carbs),
            _LegendDot('Fat', AppColors.fat),
          ]),
        ]),
      ),
      _ChartCard(
        title: 'Protein per day',
        child: SimpleBarChart(
          values: [for (final d in n.perDay) (d.$1, d.$2.protein)],
          color: AppColors.protein,
          valueFormatter: (v) => '${v.round()} g',
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Values are per person and approximate for home recipes. For medical diets, check with your doctor or dietitian.',
          style: t.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            if (subtitle != null) Text(subtitle!, style: t.bodySmall),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

// ------------------------------------------------------------------ groceries
class _GroceryTab extends StatefulWidget {
  const _GroceryTab({required this.plan});
  final MealPlanDetail plan;

  @override
  State<_GroceryTab> createState() => _GroceryTabState();
}

class _GroceryTabState extends State<_GroceryTab> {
  int _people = 2;
  late Future<List<GroceryCategory>> _future = _load();
  final Set<String> _checked = {};

  Future<List<GroceryCategory>> _load() => context.read<Session>().api.grocery(widget.plan.summary.id, _people);

  void _setPeople(int p) {
    setState(() {
      _people = p;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<GroceryCategory>>(
      future: _future,
      builder: (context, snap) {
        final cats = snap.data;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                const EmojiArt('🛒', size: 36),
                const SizedBox(width: 10),
                Expanded(child: Text('Weekly list for', style: t.titleSmall)),
                IconButton(
                  onPressed: _people > 1 ? () => _setPeople(_people - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text('$_people people', style: t.titleSmall),
                IconButton(
                  onPressed: _people < 30 ? () => _setPeople(_people + 1) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          if (cats == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else ...[
            Row(children: [
              Text('${_checked.length} of ${cats.fold<int>(0, (a, c) => a + c.items.length)} in basket',
                  style: t.bodySmall),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy list'),
                onPressed: () {
                  final text = cats
                      .map((c) => '${c.category}\n${c.items.map((i) => '• ${i.item}: ${i.amount}').join('\n')}')
                      .join('\n\n');
                  Clipboard.setData(ClipboardData(text: '${widget.plan.summary.title} ($_people people)\n\n$text'));
                  showInfo(context, 'Grocery list copied');
                },
              ),
            ]),
            for (final c in cats) GroceryCategoryCard(category: c, checked: _checked, onToggle: (k) {
              setState(() => _checked.contains(k) ? _checked.remove(k) : _checked.add(k));
            }),
          ],
        ]);
      },
    );
  }
}

const _categoryEmoji = <String, String>{
  'Vegetables': '🥕',
  'Grains & Flours': '🌾',
  'Pulses & Lentils': '🫘',
  'Dairy & Eggs': '🥛',
  'Meat & Seafood': '🍗',
  'Fruits & Nuts': '🍎',
  'Oils & Ghee': '🫕',
  'Spices & Masalas': '🌶️',
  'Other': '🧺',
};

/// Grocery checklist card (also used by AI chat blocks).
class GroceryCategoryCard extends StatelessWidget {
  const GroceryCategoryCard({super.key, required this.category, required this.checked, required this.onToggle});
  final GroceryCategory category;
  final Set<String> checked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Row(children: [
                EmojiArt(_categoryEmoji[category.category] ?? '🧺', size: 28),
                const SizedBox(width: 8),
                Text(category.category, style: t.titleSmall),
                const Spacer(),
                Text('${category.items.length}', style: t.labelMedium),
              ]),
            ),
            for (final i in category.items)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: checked.contains('${category.category}/${i.item}'),
                onChanged: (_) => onToggle('${category.category}/${i.item}'),
                title: Text(
                  i.item,
                  style: checked.contains('${category.category}/${i.item}')
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                secondary: Text(i.amount, style: t.labelLarge),
              ),
          ]),
        ),
      ),
    );
  }
}
