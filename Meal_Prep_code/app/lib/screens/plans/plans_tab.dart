import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../ai/chat_screen.dart';
import 'plan_detail_screen.dart';

/// Browse ready-made diet charts and your own (incl. AI-generated) plans.
class PlansTab extends StatefulWidget {
  const PlansTab({super.key});

  @override
  State<PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<PlansTab> {
  String? _goal;
  String? _diet;
  late Future<List<MealPlanSummary>> _future;
  late int _rev;

  @override
  void initState() {
    super.initState();
    _rev = context.read<Session>().revision;
    _future = _load();
  }

  Future<List<MealPlanSummary>> _load() => context.read<Session>().api.mealPlans(goal: _goal, diet: _diet);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final rev = context.select<Session, int>((s) => s.revision);
    if (rev != _rev) {
      _rev = rev;
      _future = _load();
    }
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Diet charts', style: t.headlineSmall),
                Text('Weekly meal plans with nutrition and grocery lists', style: t.bodyMedium),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: _AiPlanBanner(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(
                      agentKey: 'meal_planner',
                      initialMessage: 'Create a custom weekly plan for my family',
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _chip('All', _goal == null && _diet == null, () {
                    _goal = null;
                    _diet = null;
                    _reload();
                  }),
                  _chip('🟢 Veg', _diet == 'veg', () {
                    _diet = _diet == 'veg' ? null : 'veg';
                    _reload();
                  }),
                  _chip('🥚 Egg', _diet == 'egg', () {
                    _diet = _diet == 'egg' ? null : 'egg';
                    _reload();
                  }),
                  _chip('🔴 Non-veg', _diet == 'nonveg', () {
                    _diet = _diet == 'nonveg' ? null : 'nonveg';
                    _reload();
                  }),
                  for (final g in goalLabels.entries)
                    _chip(g.value, _goal == g.key, () {
                      _goal = _goal == g.key ? null : g.key;
                      _reload();
                    }),
                ],
              ),
            ),
          ),
          FutureBuilder<List<MealPlanSummary>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid.count(
                    crossAxisCount: _columns(context),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                    children: List.generate(4, (_) => const Skeleton(height: 220)),
                  ),
                );
              }
              if (snap.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(emoji: '😕', title: 'Couldn\'t load plans', message: '${snap.error}',
                      action: 'Retry', onAction: _reload),
                );
              }
              final plans = snap.data!;
              if (plans.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(emoji: '🥗', title: 'No plans match', message: 'Try a different filter.'),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 236,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, i) => PlanCard(
                    plan: plans[i],
                    compact: true,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: plans[i].id)),
                      );
                      _reload();
                    },
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  int _columns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > 1100 ? 4 : (w > 700 ? 3 : 2);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _AiPlanBanner extends StatelessWidget {
  const _AiPlanBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.aiViolet.withValues(alpha: 0.12),
              AppColors.aiBlue.withValues(alpha: 0.12),
            ]),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(gradient: AppColors.aiGradient, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Build my own plan with AI', style: Theme.of(context).textTheme.titleSmall),
                Text('Tell us your family, diet and goals. Ready in seconds.',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}
