import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../ai/chat_screen.dart';

const _allCuisines = [
  'South Indian', 'North Indian', 'Karnataka', 'Kerala', 'Chettinad', 'Andhra', 'Mughlai', 'Bengali',
  'Gujarati', 'Hyderabadi', 'Jain', 'Indo-Chinese', 'Continental',
];
const _allLanguages = ['Kannada', 'Tamil', 'Telugu', 'Malayalam', 'Hindi', 'English', 'Bengali', 'Marathi'];

class CookProfileEditor extends StatefulWidget {
  const CookProfileEditor({super.key});

  @override
  State<CookProfileEditor> createState() => _CookProfileEditorState();
}

class _CookProfileEditorState extends State<CookProfileEditor> {
  final _bio = TextEditingController();
  final _pincodes = TextEditingController();
  final _rate = TextEditingController(text: '250');
  final _exp = TextEditingController(text: '0');
  final Set<String> _cuisines = {};
  final Set<String> _languages = {};
  bool _vegOnly = false;
  bool _active = true;
  List<Dish> _dishes = [];
  bool _exists = false;
  bool _loading = true;
  bool _busy = false;
  late int _rev;

  @override
  void initState() {
    super.initState();
    _rev = context.read<Session>().revision;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_bio, _pincodes, _rate, _exp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await context.read<Session>().api.myCookProfile();
      if (!mounted) return;
      setState(() {
        if (p != null) {
          _bio.text = p.bio;
          _pincodes.text = p.servicePincodes.join(', ');
          _rate.text = '${p.hourlyRate}';
          _exp.text = '${p.experienceYears}';
          _cuisines
            ..clear()
            ..addAll(p.cuisines);
          _languages
            ..clear()
            ..addAll(p.languages);
          _vegOnly = p.vegOnly;
          _active = p.isActive;
          _dishes = p.dishes;
        }
        _exists = p != null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final pins = _pincodes.text.split(RegExp(r'[,\s]+')).where((p) => RegExp(r'^\d{6}$').hasMatch(p)).toList();
    if (_cuisines.isEmpty) {
      showError(context, 'Pick at least one cuisine');
      return;
    }
    if (pins.isEmpty) {
      showError(context, 'Add at least one 6-digit pincode you serve');
      return;
    }
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      final p = await session.api.saveCookProfile({
        'bio': _bio.text.trim(),
        'cuisines': _cuisines.toList(),
        'languages': _languages.toList(),
        'service_pincodes': pins,
        'hourly_rate': int.tryParse(_rate.text) ?? 250,
        'experience_years': int.tryParse(_exp.text) ?? 0,
        'veg_only': _vegOnly,
        'is_active': _active,
      });
      _rev = session.revision + 1; // our own change; don't reload over the form
      session.bump();
      if (!mounted) return;
      setState(() {
        _exists = true;
        _dishes = p.dishes;
      });
      showInfo(context, 'Profile saved');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addDish() async {
    final name = TextEditingController();
    final cuisine = TextEditingController(text: _cuisines.isEmpty ? '' : _cuisines.first);
    bool veg = true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add a signature dish', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Dish name')),
            const SizedBox(height: 12),
            TextField(controller: cuisine, decoration: const InputDecoration(labelText: 'Cuisine')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vegetarian'),
              value: veg,
              onChanged: (v) => setLocal(() => veg = v),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add dish')),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted || name.text.trim().length < 2) return;
    try {
      await context.read<Session>().api.addDish({'name': name.text.trim(), 'cuisine': cuisine.text.trim(), 'is_veg': veg});
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = context.select<Session, int>((s) => s.revision);
    if (rev > _rev) {
      // changed elsewhere, e.g. AI suggestion applied → refresh the form
      _rev = rev;
      _load();
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Row(children: [
          Expanded(child: Text('My profile', style: t.headlineSmall)),
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Improve with AI'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChatScreen(agentKey: 'cook_assistant', initialMessage: 'Write a better bio for my profile'),
              ),
            ),
          ),
        ]),
        if (!_exists)
          Card(
            color: AppColors.saffron.withValues(alpha: 0.08),
            child: const ListTile(
              leading: Icon(Icons.info_outline_rounded, color: AppColors.saffron),
              title: Text('Set up your profile so families can find and book you.'),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _bio,
          maxLines: 4,
          maxLength: 400,
          decoration: const InputDecoration(labelText: 'About you', hintText: 'Experience, specialities, hygiene…'),
        ),
        _label('Cuisines you cook'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in {..._allCuisines, ..._cuisines})
            FilterChip(
              label: Text('${cuisineEmoji(c)} $c'),
              selected: _cuisines.contains(c),
              onSelected: (v) => setState(() => v ? _cuisines.add(c) : _cuisines.remove(c)),
            ),
        ]),
        _label('Languages you speak'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in {..._allLanguages, ..._languages})
            FilterChip(
              label: Text(l),
              selected: _languages.contains(l),
              onSelected: (v) => setState(() => v ? _languages.add(l) : _languages.remove(l)),
            ),
        ]),
        _label('Where you work'),
        TextField(
          controller: _pincodes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Pincodes you serve',
            hintText: '560034, 560095',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _rate,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Rate (₹/hour)', prefixIcon: Icon(Icons.currency_rupee_rounded)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _exp,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Experience (yrs)', prefixIcon: Icon(Icons.workspace_premium_outlined)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.eco_rounded, color: AppColors.veg),
          title: const Text('I cook vegetarian only'),
          value: _vegOnly,
          onChanged: (v) => setState(() => _vegOnly = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.event_available_rounded),
          title: const Text('Accepting new bookings'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        const SizedBox(height: 8),
        GradientButton(label: 'Save profile', icon: Icons.check_rounded, busy: _busy, onPressed: _save),
        if (_exists) ...[
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: Text('Signature dishes', style: t.titleMedium)),
            TextButton.icon(onPressed: _addDish, icon: const Icon(Icons.add_rounded), label: const Text('Add dish')),
          ]),
          if (_dishes.isEmpty) Text('Add 3–5 dishes you\'re known for.', style: t.bodySmall),
          for (final d in _dishes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: VegDot(isVeg: d.isVeg),
                  title: Text(d.name, style: t.titleSmall),
                  subtitle: Text(d.cuisine),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final api = context.read<Session>().api;
                      await api.deleteDish(d.id);
                      if (mounted) await _load();
                    },
                  ),
                ),
              ),
            ),
        ],
      ]),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}
