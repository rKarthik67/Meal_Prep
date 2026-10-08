import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Donut of protein / carbs / fat energy split with the daily kcal in the middle.
class MacroDonut extends StatelessWidget {
  const MacroDonut({super.key, required this.nutrition, this.size = 170});
  final Nutrition nutrition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final parts = [
      ('Protein', nutrition.proteinPct, AppColors.protein, nutrition.dailyAverage.protein),
      ('Carbs', nutrition.carbsPct, AppColors.carbs, nutrition.dailyAverage.carbs),
      ('Fat', nutrition.fatPct, AppColors.fat, nutrition.dailyAverage.fat),
    ];
    return Row(children: [
      SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: size * 0.32,
              startDegreeOffset: -90,
              sections: [
                for (final p in parts)
                  PieChartSectionData(
                    value: p.$2.toDouble().clamp(1, 100),
                    color: p.$3,
                    radius: size * 0.16,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${nutrition.dailyAverage.kcal}', style: t.headlineSmall),
            Text('kcal / day', style: t.bodySmall),
          ]),
        ]),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _LegendBar(label: p.$1, pct: p.$2, color: p.$3, grams: p.$4),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Fibre ${nutrition.dailyAverage.fibre.toStringAsFixed(0)} g / day',
                style: t.bodySmall?.copyWith(color: AppColors.fibre, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ]);
  }
}

class _LegendBar extends StatelessWidget {
  const _LegendBar({required this.label, required this.pct, required this.color, required this.grams});
  final String label;
  final int pct;
  final Color color;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text('${grams.toStringAsFixed(0)} g', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct / 100,
          minHeight: 6,
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
      ),
    ]);
  }
}

/// Vertical bars with labels underneath, e.g. kcal per weekday or spend per month.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    this.color,
    this.gradient,
    this.height = 180,
    this.valueFormatter,
    this.highlightIndex,
  });

  final List<(String, double)> values;
  final Color? color;
  final Gradient? gradient;
  final double height;
  final String Function(double)? valueFormatter;
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final maxV = values.fold<double>(0, (m, v) => v.$2 > m ? v.$2 : m);
    final fmt = valueFormatter ?? (double v) => v.toStringAsFixed(0);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxV == 0 ? 1 : maxV * 1.2,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= values.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(values[i].$1,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                fmt(rod.toY),
                TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i].$2,
                  width: values.length > 8 ? 12 : 20,
                  borderRadius: BorderRadius.circular(8),
                  color: gradient == null ? (highlightIndex == null || highlightIndex == i ? c : c.withValues(alpha: 0.35)) : null,
                  gradient: gradient,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxV == 0 ? 1 : maxV * 1.2,
                    color: c.withValues(alpha: 0.06),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Stacked protein/carbs/fat grams per day.
class MacroStackChart extends StatelessWidget {
  const MacroStackChart({super.key, required this.nutrition, this.height = 200});
  final Nutrition nutrition;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = nutrition.perDay;
    final maxV = days.fold<double>(0, (m, d) {
      final s = d.$2.protein + d.$2.carbs + d.$2.fat;
      return s > m ? s : m;
    });
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxV * 1.1,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxV <= 0 ? 50 : (maxV / 4).ceilToDouble(),
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.toInt()}g', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(days[i].$1, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barTouchData: const BarTouchData(enabled: false),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              () {
                final m = days[i].$2;
                final p = m.protein, c = m.carbs, f = m.fat;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: p + c + f,
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    rodStackItems: [
                      BarChartRodStackItem(0, p, AppColors.protein),
                      BarChartRodStackItem(p, p + c, AppColors.carbs),
                      BarChartRodStackItem(p + c, p + c + f, AppColors.fat),
                    ],
                  ),
                ]);
              }(),
          ],
        ),
      ),
    );
  }
}

/// Smooth area line, e.g. calories across the week.
class TrendLine extends StatelessWidget {
  const TrendLine({super.key, required this.values, this.color, this.height = 140});
  final List<(String, double)> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    if (values.isEmpty) return SizedBox(height: height);
    final maxV = values.map((v) => v.$2).reduce((a, b) => a > b ? a : b);
    final minV = values.map((v) => v.$2).reduce((a, b) => a < b ? a : b);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: (minV * 0.85).floorToDouble(),
          maxY: (maxV * 1.1).ceilToDouble(),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= values.length || v != i.toDouble()) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(values[i].$1, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].$2)],
              isCurved: true,
              color: c,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal share bars for small categorical breakdowns (cuisines, meal types, statuses).
class ShareBars extends StatelessWidget {
  const ShareBars({super.key, required this.data, this.colors, this.labelFor, this.colorFor});
  final Map<String, int> data;
  final List<Color>? colors;
  final Color Function(String)? colorFor;
  final String Function(String)? labelFor;

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final palette = colors ??
        const [AppColors.saffron, AppColors.curryLeaf, AppColors.aiViolet, AppColors.turmeric, AppColors.aiBlue];
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final t = Theme.of(context).textTheme;
    if (total == 0) {
      return Padding(padding: const EdgeInsets.all(12), child: Text('No data yet', style: t.bodySmall));
    }
    return Column(children: [
      for (var i = 0; i < entries.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
              width: 110,
              child: Text(labelFor?.call(entries[i].key) ?? entries[i].key,
                  style: t.bodyMedium, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: entries[i].value / total,
                  minHeight: 10,
                  color: colorFor?.call(entries[i].key) ?? palette[i % palette.length],
                  backgroundColor: (colorFor?.call(entries[i].key) ?? palette[i % palette.length]).withValues(alpha: 0.12),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text('${entries[i].value}', textAlign: TextAlign.right, style: t.labelLarge),
            ),
          ]),
        ),
    ]);
  }
}

/// Number tile used on dashboards.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.emoji, required this.value, required this.label, this.color});
  final String emoji;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 10),
          Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

String compactRupees(double v) => v >= 1000 ? '₹${(v / 1000).toStringAsFixed(1)}k' : rupees(v);
