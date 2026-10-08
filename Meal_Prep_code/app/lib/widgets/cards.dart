import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'emoji_art.dart';

const _cuisineEmoji = <String, String>{
  'south indian': '🍛',
  'karnataka': '🍲',
  'north indian': '🫓',
  'mughlai': '🍗',
  'kerala': '🥥',
  'chettinad': '🌶️',
  'andhra': '🌶️',
  'hyderabadi': '🍛',
  'bengali': '🐟',
  'gujarati': '🫓',
  'jain': '🪷',
  'coastal': '🦐',
  'indo-chinese': '🍜',
  'maharashtrian': '🥘',
};

String cuisineEmoji(String cuisine) => _cuisineEmoji[cuisine.toLowerCase()] ?? '🍽️';

/// Deterministic accent colour per cook so avatars feel personal.
Color accentFor(int id) {
  const palette = [
    AppColors.saffron,
    AppColors.curryLeaf,
    AppColors.aiViolet,
    Color(0xFF1E8C93),
    Color(0xFFC0392B),
    Color(0xFF8D6E3F),
  ];
  return palette[id % palette.length];
}

class CookAvatar extends StatelessWidget {
  const CookAvatar({super.key, required this.name, required this.id, this.size = 56, this.verified = false});
  final String name;
  final int id;
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = accentFor(id);
    final chef = ['👩‍🍳', '🧑‍🍳', '👨‍🍳'][id % 3];
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        padding: EdgeInsets.all(size * 0.1),
        child: EmojiArt(chef, size: size * 0.8),
      ),
      if (verified)
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.verified_rounded, color: const Color(0xFF2F6FED), size: size * 0.3),
          ),
        ),
    ]);
  }
}

/// Full-width cook card for search results.
class CookCard extends StatelessWidget {
  const CookCard({super.key, required this.cook, this.onTap});
  final Cook cook;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CookAvatar(name: cook.name, id: cook.userId, size: 64, verified: cook.verified),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(cook.name, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
                  RatingBadge(rating: cook.ratingAvg, count: cook.ratingCount),
                ]),
                const SizedBox(height: 2),
                Text(cook.cuisines.join(' · '),
                    style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill('${cook.experienceYears} yrs', icon: Icons.workspace_premium_rounded, color: AppColors.curryLeaf),
                  if (cook.vegOnly) const Pill('Pure veg', icon: Icons.eco_rounded, color: AppColors.veg),
                  if (cook.languages.isNotEmpty)
                    Pill(cook.languages.take(2).join(', '), icon: Icons.translate_rounded, color: AppColors.aiBlue),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text(rupees(cook.hourlyRate), style: t.titleMedium?.copyWith(color: scheme.primary)),
                  Text(' / hour', style: t.bodySmall),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.primary),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Compact cook card for horizontal carousels.
class CookMiniCard extends StatelessWidget {
  const CookMiniCard({super.key, required this.cook, this.onTap});
  final Cook cook;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 168,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CookAvatar(name: cook.name, id: cook.userId, size: 48, verified: cook.verified),
                const Spacer(),
                RatingBadge(rating: cook.ratingAvg, count: cook.ratingCount),
              ]),
              const SizedBox(height: 10),
              Text(cook.name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(cook.cuisines.take(2).join(' · '), style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('${rupees(cook.hourlyRate)}/hr',
                  style: t.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Diet-chart card with a coloured cover and 3D artwork.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, this.onTap, this.width, this.compact = false});
  final MealPlanSummary plan;
  final VoidCallback? onTap;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.fromHex(plan.color);
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            PlanCover(plan: plan, height: compact ? 110 : 130),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(plan.subtitle, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  _Metric(icon: Icons.local_fire_department_rounded, text: '${plan.avgKcal} kcal', color: c),
                  const SizedBox(width: 10),
                  _Metric(icon: Icons.fitness_center_rounded, text: '${plan.avgProtein.round()} g', color: AppColors.protein),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]);
}

class PlanCover extends StatelessWidget {
  const PlanCover({super.key, required this.plan, this.height = 130, this.radius = 0});
  final MealPlanSummary plan;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.fromHex(plan.color);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [Color.lerp(c, Colors.white, 0.15)!, c],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: height * 1.1,
            height: height * 1.1,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        Positioned(right: 10, bottom: 6, child: EmojiArt(plan.emoji, size: height * 0.78)),
        Positioned(
          left: 12,
          top: 12,
          child: Wrap(spacing: 6, children: [
            _CoverTag(plan.createdByAi ? '✨ AI' : plan.goalLabel),
            _CoverTag(switch (plan.diet) { 'veg' => '🟢 Veg', 'egg' => '🥚 Egg', _ => '🔴 Non-veg' }),
          ]),
        ),
        if (plan.tags.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            child: Text(plan.tags.first.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.1)),
          ),
      ]),
    );
  }
}

class _CoverTag extends StatelessWidget {
  const _CoverTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink)),
      );
}
