import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import 'booking_form_screen.dart';

class CookDetailScreen extends StatefulWidget {
  const CookDetailScreen({super.key, required this.cookId, this.mealType, this.mealPlanId});
  final int cookId;
  final String? mealType;
  final int? mealPlanId;

  @override
  State<CookDetailScreen> createState() => _CookDetailScreenState();
}

class _CookDetailScreenState extends State<CookDetailScreen> {
  late final Future<Cook> _future = context.read<Session>().api.cook(widget.cookId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Cook>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.hasError
                ? EmptyState(emoji: '😕', title: 'Couldn\'t load this cook', message: '${snap.error}')
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return _CookDetail(cook: snap.data!, mealType: widget.mealType, mealPlanId: widget.mealPlanId);
      },
    );
  }
}

class _CookDetail extends StatelessWidget {
  const _CookDetail({required this.cook, this.mealType, this.mealPlanId});
  final Cook cook;
  final String? mealType;
  final int? mealPlanId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = accentFor(cook.userId);
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          stretch: true,
          backgroundColor: accent,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(cook.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.lerp(accent, Colors.white, 0.2)!, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(children: [
                Positioned(
                  right: -40,
                  top: -20,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 40,
                  child: EmojiArt(['👩‍🍳', '🧑‍🍳', '👨‍🍳'][cook.userId % 3], size: 150),
                ),
                Positioned(
                  left: 20,
                  bottom: 70,
                  child: Row(children: [
                    for (final c in cook.cuisines.take(3))
                      Padding(padding: const EdgeInsets.only(right: 6), child: EmojiArt(cuisineEmoji(c), size: 40)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _Fact(value: rupees(cook.hourlyRate), label: 'per hour')),
                Expanded(
                  child: _Fact(
                    value: cook.ratingCount == 0 ? 'New' : '★ ${cook.ratingAvg.toStringAsFixed(1)}',
                    label: cook.ratingCount == 0 ? 'no reviews yet' : '${cook.ratingCount} reviews',
                  ),
                ),
                Expanded(child: _Fact(value: '${cook.experienceYears} yrs', label: 'experience')),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (cook.verified) const Pill('ID & background verified', icon: Icons.verified_user_rounded, color: Color(0xFF2F6FED)),
                if (cook.vegOnly) const Pill('Pure veg kitchen', icon: Icons.eco_rounded, color: AppColors.veg),
                for (final l in cook.languages) Pill(l, icon: Icons.translate_rounded, color: AppColors.aiBlue),
              ]),
              const SizedBox(height: 20),
              Text('About', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(cook.bio.isEmpty ? 'This cook hasn\'t written a bio yet.' : cook.bio,
                  style: t.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 20),
              Text('Cuisines', style: t.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in cook.cuisines)
                  Chip(avatar: EmojiArt(cuisineEmoji(c), size: 20), label: Text(c)),
              ]),
              const SizedBox(height: 20),
              Text('Signature dishes', style: t.titleMedium),
              const SizedBox(height: 8),
              if (cook.dishes.isEmpty) Text('No dishes listed yet', style: t.bodySmall),
              for (final d in cook.dishes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Card(
                    child: ListTile(
                      leading: FoodTile(emoji: cuisineEmoji(d.cuisine), size: 44, radius: 12),
                      title: Text(d.name, style: t.titleSmall),
                      subtitle: Text('${d.cuisine.isEmpty ? 'Home style' : d.cuisine} · ~${d.prepMinutes} min'),
                      trailing: VegDot(isVeg: d.isVeg),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Serves ${cook.servicePincodes.join(', ')}',
                      style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ]),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: GradientButton(
            label: 'Book ${cook.name.split(' ').first}',
            icon: Icons.calendar_month_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingFormScreen(cook: cook, mealType: mealType, mealPlanId: mealPlanId),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      Text(label, style: t.bodySmall),
    ]);
  }
}
