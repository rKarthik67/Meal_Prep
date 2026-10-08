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
import '../customer/booking_form_screen.dart';
import '../customer/cook_detail_screen.dart';
import '../plans/plan_detail_screen.dart';

/// Renders a rich UI block returned by an AI agent tool call.
class AiBlock extends StatelessWidget {
  const AiBlock({super.key, required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    switch (block['type']) {
      case 'cooks':
        return _CooksBlock(cooks: (block['cooks'] as List).map((c) => Cook.fromJson(c as Map<String, dynamic>)).toList());
      case 'meal_plans':
        return _PlansBlock(
            plans: (block['plans'] as List).map((p) => MealPlanSummary.fromJson(p as Map<String, dynamic>)).toList());
      case 'meal_plan':
        return _PlansBlock(plans: [MealPlanSummary.fromJson(block['plan'] as Map<String, dynamic>)]);
      case 'nutrition':
        return _NutritionBlock(
          title: block['title'] as String,
          planId: block['plan_id'] as int,
          nutrition: Nutrition.fromJson(block['nutrition'] as Map<String, dynamic>),
        );
      case 'grocery_list':
        return _GroceryBlock(
          title: block['title'] as String,
          people: block['people'] as int,
          categories: GroceryCategory.listFrom(block['categories']),
        );
      case 'booking_draft':
        return BookingDraftCard(block: block);
      case 'profile_suggestion':
        return ProfileSuggestionCard(block: block);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CooksBlock extends StatelessWidget {
  const _CooksBlock({required this.cooks});
  final List<Cook> cooks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cooks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => CookMiniCard(
          cook: cooks[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CookDetailScreen(cookId: cooks[i].userId)),
          ),
        ),
      ),
    );
  }
}

class _PlansBlock extends StatelessWidget {
  const _PlansBlock({required this.plans});
  final List<MealPlanSummary> plans;

  void _open(BuildContext context, MealPlanSummary p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: p.id)));

  @override
  Widget build(BuildContext context) {
    if (plans.length == 1) {
      return SizedBox(width: 280, child: PlanCard(plan: plans.first, onTap: () => _open(context, plans.first)));
    }
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => PlanCard(plan: plans[i], width: 210, compact: true, onTap: () => _open(context, plans[i])),
      ),
    );
  }
}

class _NutritionBlock extends StatelessWidget {
  const _NutritionBlock({required this.title, required this.planId, required this.nutrition});
  final String title;
  final int planId;
  final Nutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.monitor_heart_rounded, color: AppColors.aiViolet, size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text('Nutrition · $title', style: t.titleSmall, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          MacroDonut(nutrition: nutrition, size: 130),
          const SizedBox(height: 12),
          Text('Calories per day', style: t.labelLarge),
          const SizedBox(height: 6),
          SimpleBarChart(
            height: 130,
            values: [for (final d in nutrition.perDay) (d.$1, d.$2.kcal.toDouble())],
            gradient: const LinearGradient(
              colors: [AppColors.saffronLight, AppColors.saffron],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            valueFormatter: (v) => '${v.round()} kcal',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: planId)),
              ),
              child: const Text('Open plan →'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GroceryBlock extends StatelessWidget {
  const _GroceryBlock({required this.title, required this.people, required this.categories});
  final String title;
  final int people;
  final List<GroceryCategory> categories;

  String _asText() => '$title ($people people)\n\n${categories.map((c) => '${c.category}\n${c.items.map((i) => '• ${i.item}: ${i.amount}').join('\n')}').join('\n\n')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = categories.fold<int>(0, (a, c) => a + c.items.length);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const EmojiArt('🛒', size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Grocery list · $people people', style: t.titleSmall),
                Text('$total items · $title', style: t.bodySmall, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in categories) Pill('${c.category} · ${c.items.length}', color: AppColors.curryLeaf),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.checklist_rounded, size: 18),
              label: const Text('Open checklist'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _GrocerySheet(title: title, categories: categories),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _asText()));
                showInfo(context, 'Grocery list copied');
              },
            ),
          ]),
        ]),
      ),
    );
  }
}

class _GrocerySheet extends StatefulWidget {
  const _GrocerySheet({required this.title, required this.categories});
  final String title;
  final List<GroceryCategory> categories;

  @override
  State<_GrocerySheet> createState() => _GrocerySheetState();
}

class _GrocerySheetState extends State<_GrocerySheet> {
  final Set<String> _checked = {};

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(controller: controller, padding: const EdgeInsets.all(16), children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final c in widget.categories)
          GroceryCategoryCard(
            category: c,
            checked: _checked,
            onToggle: (k) => setState(() => _checked.contains(k) ? _checked.remove(k) : _checked.add(k)),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ booking draft
class BookingDraftCard extends StatefulWidget {
  const BookingDraftCard({super.key, required this.block});
  final Map<String, dynamic> block;

  @override
  State<BookingDraftCard> createState() => _BookingDraftCardState();
}

class _BookingDraftCardState extends State<BookingDraftCard> {
  bool _busy = false;
  bool _done = false;

  Map<String, dynamic> get _p => widget.block['payload'] as Map<String, dynamic>;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      await session.api.createBookingFromDraft(_p);
      session.bump();
      if (!mounted) return;
      setState(() => _done = true);
      showInfo(context, 'Booking request sent to ${widget.block['cook_name']}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final api = context.read<Session>().api;
    try {
      final cook = await api.cook(_p['cook_id'] as int);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingFormScreen(
            cook: cook,
            mealType: _p['meal_type'] as String?,
            mealPlanId: _p['meal_plan_id'] as int?,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = widget.block;
    final q = b['quote'] as Map<String, dynamic>;
    final date = DateTime.parse(_p['service_date'] as String);
    final meal = _p['meal_type'] as String;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: Row(children: [
            EmojiArt(mealTypeIcons[meal] ?? '🍛', size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_done ? 'Request sent ✓' : 'Booking draft',
                    style: t.labelMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
                Text(b['cook_name'] as String, style: t.titleMedium?.copyWith(color: Colors.white)),
              ]),
            ),
            Text(rupees(q['total'] as num), style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _row(Icons.event_rounded, '${prettyDate(date)} · ${prettyTime(_p['start_time'] as String)} · ${_p['duration_hours']} h'),
            _row(Icons.restaurant_rounded, '${mealTypes[meal] ?? meal} for ${_p['guests']} people'),
            _row(Icons.location_on_rounded, b['address'] as String),
            if (b['meal_plan_title'] != null) _row(Icons.menu_book_rounded, 'Plan: ${b['meal_plan_title']}'),
            if ((_p['notes'] as String? ?? '').isNotEmpty) _row(Icons.sticky_note_2_rounded, _p['notes'] as String),
            const SizedBox(height: 10),
            if (_done)
              const Pill('Waiting for the cook to accept', icon: Icons.hourglass_top_rounded, color: AppColors.curryLeaf)
            else
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _busy ? null : _edit, child: const Text('Edit'))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _confirm,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: const Text('Confirm booking'),
                  ),
                ),
              ]),
          ]),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

// ------------------------------------------------------------------ cook profile suggestion
class ProfileSuggestionCard extends StatefulWidget {
  const ProfileSuggestionCard({super.key, required this.block});
  final Map<String, dynamic> block;

  @override
  State<ProfileSuggestionCard> createState() => _ProfileSuggestionCardState();
}

class _ProfileSuggestionCardState extends State<ProfileSuggestionCard> {
  bool _busy = false;
  bool _applied = false;

  Map<String, dynamic> get _c => widget.block['changes'] as Map<String, dynamic>;

  Future<void> _apply() async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      final current = await session.api.myCookProfile();
      final body = <String, dynamic>{
        'bio': _c['bio'] ?? current?.bio ?? '',
        'cuisines': _c['cuisines'] ?? current?.cuisines ?? <String>[],
        'languages': _c['languages'] ?? current?.languages ?? <String>[],
        'service_pincodes': current?.servicePincodes ?? <String>[],
        'veg_only': current?.vegOnly ?? false,
        'experience_years': current?.experienceYears ?? 0,
        'hourly_rate': _c['hourly_rate'] ?? current?.hourlyRate ?? 250,
        'is_active': current?.isActive ?? true,
      };
      await session.api.saveCookProfile(body);
      for (final d in (_c['new_dishes'] as List?) ?? const []) {
        final dish = d as Map<String, dynamic>;
        await session.api.addDish({
          'name': dish['name'],
          'cuisine': dish['cuisine'] ?? '',
          'is_veg': dish['is_veg'] ?? true,
        });
      }
      session.bump();
      if (!mounted) return;
      setState(() => _applied = true);
      showInfo(context, 'Profile updated');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reason = widget.block['reason'] as String? ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_fix_high_rounded, color: AppColors.aiViolet),
            const SizedBox(width: 8),
            Text('Suggested profile update', style: t.titleSmall),
          ]),
          if (reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(reason, style: t.bodySmall)),
          if (_c['bio'] != null) _field('Bio', _c['bio'] as String),
          if (_c['cuisines'] != null) _field('Cuisines', (_c['cuisines'] as List).join(', ')),
          if (_c['languages'] != null) _field('Languages', (_c['languages'] as List).join(', ')),
          if (_c['hourly_rate'] != null) _field('Hourly rate', rupees(_c['hourly_rate'] as num)),
          if (_c['new_dishes'] != null)
            _field('New dishes', (_c['new_dishes'] as List).map((d) => (d as Map)['name']).join(', ')),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _applied
                ? const Pill('Applied to your profile', icon: Icons.check_circle_rounded, color: AppColors.curryLeaf)
                : FilledButton.icon(
                    onPressed: _busy ? null : _apply,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Apply to my profile'),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}
