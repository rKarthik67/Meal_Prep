import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Spend (customer) or earnings (cook) dashboard.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<Stats> _future = context.read<Session>().api.stats();

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<Stats>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            emoji: '📊',
            title: 'Couldn\'t load insights',
            message: '${snap.error}',
            action: 'Retry',
            onAction: () => setState(() => _future = context.read<Session>().api.stats()),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return InsightsView(stats: snap.data!);
      },
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Insights')), body: body);
  }
}

class InsightsView extends StatelessWidget {
  const InsightsView({super.key, required this.stats});
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final cook = s.role == 'cook';
    final t = Theme.of(context).textTheme;
    final thisMonth = s.monthly.isEmpty ? 0 : s.monthly.last.$2;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          StatTile(emoji: '💰', value: rupees(thisMonth), label: cook ? 'earned this month' : 'spent this month'),
          StatTile(
            emoji: '📅',
            value: '${s.upcoming}',
            label: cook ? 'upcoming jobs' : 'upcoming bookings',
            color: AppColors.aiBlue,
          ),
          StatTile(
            emoji: cook ? '⭐' : '⏰',
            value: cook ? (s.ratingCount == null || s.ratingCount == 0 ? 'New' : s.ratingAvg!.toStringAsFixed(1)) : '${s.hoursSaved} h',
            label: cook ? '${s.ratingCount ?? 0} reviews' : 'kitchen time saved',
            color: AppColors.turmeric,
          ),
          StatTile(
            emoji: '✅',
            value: '${s.completed}',
            label: cook ? 'jobs completed' : 'meals enjoyed',
            color: AppColors.curryLeaf,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cook ? 'Earnings · last 6 months' : 'Spend · last 6 months', style: t.titleMedium),
            Text('Total ${rupees(s.totalAmount)}', style: t.bodySmall),
            const SizedBox(height: 16),
            SimpleBarChart(
              values: [for (final m in s.monthly) (m.$1, m.$2.toDouble())],
              gradient: cook
                  ? const LinearGradient(
                      colors: [Color(0xFF5FB98E), AppColors.curryLeaf],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [AppColors.saffronLight, AppColors.saffron],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              valueFormatter: (v) => rupees(v),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bookings by meal type', style: t.titleMedium),
            const SizedBox(height: 10),
            ShareBars(data: s.byMealType, labelFor: (k) => mealTypes[k] ?? k),
          ]),
        ),
      ),
      if (!cook && s.byCuisine.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Favourite cuisines', style: t.titleMedium),
              const SizedBox(height: 10),
              ShareBars(data: s.byCuisine),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Status overview', style: t.titleMedium),
            const SizedBox(height: 10),
            ShareBars(
              data: s.byStatus,
              labelFor: (k) => k.replaceAll('_', ' '),
              colorFor: (k) => StatusChip.styleFor(k).$1,
            ),
          ]),
        ),
      ),
    ]);
  }
}
