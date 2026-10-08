import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import '../address_form_screen.dart';

class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({super.key, required this.cook, this.mealType, this.mealPlanId});
  final Cook cook;
  final String? mealType;
  final int? mealPlanId;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  List<Address> _addresses = [];
  List<MealPlanSummary> _plans = [];
  int? _addressId;
  int? _planId;
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  int _hours = 2;
  int _guests = 2;
  late String _mealType = widget.mealType ?? 'lunch';
  String _groceriesBy = 'customer';
  final Set<int> _dishIds = {};
  final _notes = TextEditingController();
  Quote? _quote;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _planId = widget.mealPlanId;
    if (_mealType == 'meal_prep') _hours = 3;
    if (_mealType == 'party') {
      _hours = 4;
      _guests = 8;
    }
    _loadAddresses();
    _loadPlans();
    _refreshQuote();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final list = await context.read<Session>().api.addresses();
    if (!mounted) return;
    setState(() {
      _addresses = list;
      final pins = widget.cook.servicePincodes;
      final serviceable = list.where((a) => pins.isEmpty || pins.contains(a.pincode));
      _addressId ??= serviceable.isNotEmpty ? serviceable.first.id : (list.isNotEmpty ? list.first.id : null);
    });
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await context.read<Session>().api.mealPlans();
      if (mounted) setState(() => _plans = plans);
    } catch (_) {/* optional */}
  }

  Future<void> _refreshQuote() async {
    try {
      final q = await context.read<Session>().api.quote(widget.cook.userId, _hours, _guests);
      if (mounted) setState(() => _quote = q);
    } catch (_) {/* informational */}
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _submit() async {
    if (_addressId == null) {
      showError(context, 'Add an address first');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = context.read<Session>();
      await session.api.createBooking({
        'cook_id': widget.cook.userId,
        'address_id': _addressId,
        'service_date': '${_date.year}-${_two(_date.month)}-${_two(_date.day)}',
        'start_time': '${_two(_time.hour)}:${_two(_time.minute)}:00',
        'duration_hours': _hours,
        'meal_type': _mealType,
        'guests': _guests,
        'dish_ids': _dishIds.toList(),
        'groceries_by': _groceriesBy,
        'notes': _notes.text,
        'meal_plan_id': _planId,
      });
      session.bump();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => _SuccessSheet(cookName: widget.cook.name),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cook = widget.cook;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Book a cook')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CookAvatar(name: cook.name, id: cook.userId, size: 52, verified: cook.verified),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cook.name, style: t.titleMedium),
                  Text('${cook.cuisines.take(2).join(' · ')} · ${rupees(cook.hourlyRate)}/hr', style: t.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
        _Section(
          icon: Icons.restaurant_rounded,
          title: 'What should they cook?',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 100,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in mealTypes.entries)
                  _MealTypeTile(
                    emoji: mealTypeIcons[e.key] ?? '🍛',
                    label: e.value,
                    selected: _mealType == e.key,
                    onTap: () => setState(() => _mealType = e.key),
                  ),
              ]),
            ),
            if (_plans.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _planId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Follow a diet chart (optional)',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('No plan, I\'ll tell the cook')),
                  for (final p in _plans)
                    DropdownMenuItem<int?>(value: p.id, child: Text('${p.emoji}  ${p.title}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _planId = v),
              ),
            ],
            if (cook.dishes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Pick signature dishes', style: t.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in cook.dishes)
                  FilterChip(
                    avatar: VegDot(isVeg: d.isVeg, size: 12),
                    label: Text(d.name),
                    selected: _dishIds.contains(d.id),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _dishIds.add(d.id);
                      } else {
                        _dishIds.remove(d.id);
                      }
                    }),
                  ),
              ]),
            ],
          ]),
        ),
        _Section(
          icon: Icons.schedule_rounded,
          title: 'When?',
          child: Column(children: [
            Row(children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: prettyDate(_date),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.access_time_rounded,
                  label: 'Start time',
                  value: _time.format(context),
                  onTap: () async {
                    final tm = await showTimePicker(context: context, initialTime: _time);
                    if (tm != null) setState(() => _time = tm);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _Stepper(label: 'Hours', icon: Icons.hourglass_bottom_rounded, value: _hours, min: 1, max: 8, onChanged: (v) {
              setState(() => _hours = v);
              _refreshQuote();
            }),
            _Stepper(label: 'People', icon: Icons.groups_rounded, value: _guests, min: 1, max: 50, onChanged: (v) {
              setState(() => _guests = v);
              _refreshQuote();
            }),
          ]),
        ),
        _Section(
          icon: Icons.location_on_rounded,
          title: 'Where?',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final a in _addresses)
              _AddressOption(
                address: a,
                selected: _addressId == a.id,
                serviceable: cook.servicePincodes.isEmpty || cook.servicePincodes.contains(a.pincode),
                onTap: () => setState(() => _addressId = a.id),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add new address'),
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressFormScreen()),
                );
                if (added == true) _loadAddresses();
              },
            ),
          ]),
        ),
        _Section(
          icon: Icons.shopping_basket_rounded,
          title: 'Groceries',
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'customer', label: Text('I\'ll have them'), icon: Icon(Icons.home_rounded)),
              ButtonSegment(value: 'cook', label: Text('Cook brings'), icon: Icon(Icons.shopping_bag_rounded)),
            ],
            selected: {_groceriesBy},
            onSelectionChanged: (s) => setState(() => _groceriesBy = s.first),
          ),
        ),
        _Section(
          icon: Icons.sticky_note_2_rounded,
          title: 'Notes for the cook',
          child: TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Spice level, allergies, where to find things…'),
          ),
        ),
        if (_quote != null)
          Card(
            color: scheme.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _PriceRow('Cook fee ($_hours h × ${rupees(cook.hourlyRate)})', _quote!.cookFee),
                if (_quote!.extraGuestFee > 0) _PriceRow('Extra guests', _quote!.extraGuestFee),
                _PriceRow('Platform & safety fee', _quote!.platformFee),
                const Divider(height: 20),
                _PriceRow('Estimated total', _quote!.total, bold: true),
                if (_groceriesBy == 'cook')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Groceries are billed separately at actuals.', style: t.bodySmall),
                  ),
              ]),
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: GradientButton(
            label: _quote == null ? 'Send request' : 'Send request · ${rupees(_quote!.total)}',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _MealTypeTile extends StatelessWidget {
  const _MealTypeTile({required this.emoji, required this.label, required this.selected, required this.onTap});
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 92,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.12) : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? c : Theme.of(context).dividerColor, width: selected ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            EmojiArt(emoji, size: 40),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: t.labelSmall),
                Text(value, style: t.titleSmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final IconData icon;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        IconButton.outlined(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 40,
          child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.outlined(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ]),
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({required this.address, required this.selected, required this.serviceable, required this.onTap});
  final Address address;
  final bool selected;
  final bool serviceable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c : Theme.of(context).dividerColor, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? c : Theme.of(context).disabledColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(address.label, style: t.titleSmall),
                Text('${address.line1}, ${address.area} ${address.pincode}', style: t.bodySmall),
                if (!serviceable)
                  Text('Outside this cook\'s area', style: t.bodySmall?.copyWith(color: AppColors.nonVeg)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.label, this.amount, {this.bold = false});
  final String label;
  final int amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(rupees(amount), style: style),
      ]),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.cookName});
  final String cookName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const EmojiArt('🎉', size: 96),
        const SizedBox(height: 12),
        Text('Request sent!', style: t.headlineSmall),
        const SizedBox(height: 6),
        Text('$cookName will confirm shortly. You can track it under Bookings.',
            textAlign: TextAlign.center, style: t.bodyMedium),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ),
      ]),
    );
  }
}
