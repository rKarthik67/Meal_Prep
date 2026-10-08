import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/emoji_art.dart';
import '../widgets/skeleton.dart';

/// Bookings for both customers and cooks, split into upcoming and past.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late Future<List<Booking>> _future;
  late int _rev;

  @override
  void initState() {
    super.initState();
    _rev = context.read<Session>().revision;
    _future = context.read<Session>().api.bookings();
  }

  void _reload() => setState(() => _future = context.read<Session>().api.bookings());

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.revision != _rev) {
      _rev = session.revision;
      _future = session.api.bookings();
    }
    final isCook = session.user!.isCook;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: DefaultTabController(
        length: 2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(isCook ? 'Jobs' : 'My bookings', style: t.headlineSmall),
            ),
          const TabBar(
            labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')],
          ),
          Expanded(
            child: FutureBuilder<List<Booking>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return ListView(padding: const EdgeInsets.all(16), children: const [
                    Skeleton(height: 150),
                    SizedBox(height: 12),
                    Skeleton(height: 150),
                  ]);
                }
                if (snap.hasError) {
                  return EmptyState(emoji: '😕', title: 'Couldn\'t load bookings', message: '${snap.error}',
                      action: 'Retry', onAction: _reload);
                }
                final all = snap.data!;
                final upcoming = all.where((b) => b.isActive).toList()
                  ..sort((a, b) => '${a.serviceDate}${a.startTime}'.compareTo('${b.serviceDate}${b.startTime}'));
                final past = all.where((b) => !b.isActive).toList();
                return TabBarView(children: [
                  _list(upcoming, isCook,
                      EmptyState(
                        emoji: isCook ? '🧑‍🍳' : '📅',
                        title: isCook ? 'No upcoming jobs' : 'No upcoming bookings',
                        message: isCook
                            ? 'Keep your profile complete and active to get requests.'
                            : 'Find a cook or pick a diet chart to get started.',
                      )),
                  _list(past, isCook, const EmptyState(emoji: '🍽️', title: 'No past bookings yet')),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _list(List<Booking> items, bool isCook, Widget empty) => RefreshIndicator(
        onRefresh: () async => _reload(),
        child: items.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.only(top: 40), child: empty)])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: items.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(booking: items[i], isCook: isCook, onChanged: _reload),
                ),
              ),
      );
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.isCook, required this.onChanged});
  final Booking booking;
  final bool isCook;
  final VoidCallback onChanged;

  List<(String, String)> get _actions {
    if (isCook) {
      return switch (booking.status) {
        'requested' => [('reject', 'Decline'), ('accept', 'Accept')],
        'accepted' => [('start', 'Start cooking')],
        'in_progress' => [('complete', 'Mark as done')],
        _ => [],
      };
    }
    return switch (booking.status) {
      'requested' || 'accepted' => [('cancel', 'Cancel')],
      _ => [],
    };
  }

  Future<void> _act(BuildContext context, String action) async {
    if (action == 'cancel' || action == 'reject') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action == 'cancel' ? 'Cancel this booking?' : 'Decline this request?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    try {
      await context.read<Session>().api.act(booking.id, action);
      onChanged();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _review(BuildContext context) async {
    int rating = 5;
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const EmojiArt('😋', size: 72),
            const SizedBox(height: 8),
            Text('How was ${booking.cookName}\'s food?', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.turmeric),
                  onPressed: () => setLocal(() => rating = i),
                ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: comment,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Tell others what you loved (optional)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit review')),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<Session>().api.review(booking.id, rating, comment.text);
      onChanged();
      if (context.mounted) showInfo(context, 'Thanks for your review!');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final canReview = !isCook && b.status == 'completed' && b.rating == null;
    final counterpart = isCook ? b.customerName : b.cookName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            isCook
                ? FoodTile(emoji: mealTypeIcons[b.mealType] ?? '🍛', size: 52)
                : CookAvatar(name: b.cookName, id: b.cookId, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(counterpart, style: t.titleMedium, overflow: TextOverflow.ellipsis),
                Text('${mealTypes[b.mealType] ?? b.mealType} · ${b.guests} people', style: t.bodySmall),
              ]),
            ),
            StatusChip(b.status),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              _info(context, Icons.event_rounded,
                  '${prettyDate(b.date)} · ${prettyTime(b.startTime)} · ${b.durationHours} h'),
              _info(context, Icons.location_on_outlined, '${b.address.line1}, ${b.address.area} ${b.address.pincode}'),
              if (b.mealPlanTitle != null) _info(context, Icons.menu_book_rounded, 'Plan: ${b.mealPlanTitle}'),
              if (b.notes.isNotEmpty) _info(context, Icons.sticky_note_2_outlined, b.notes),
            ]),
          ),
          if (b.status != 'rejected' && b.status != 'cancelled') ...[
            const SizedBox(height: 12),
            _Progress(status: b.status),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Text(rupees(b.priceEstimate), style: t.titleMedium?.copyWith(color: scheme.primary)),
            if (b.rating != null) ...[
              const SizedBox(width: 10),
              Pill('${b.rating} ★', color: AppColors.turmeric),
            ],
            const Spacer(),
            for (final (action, label) in _actions)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: action == 'reject' || action == 'cancel'
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => _act(context, action),
                        child: Text(label),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => _act(context, action),
                        child: Text(label),
                      ),
              ),
            if (canReview)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _review(context),
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Rate'),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

/// requested → accepted → cooking → done
class _Progress extends StatelessWidget {
  const _Progress({required this.status});
  final String status;

  static const _steps = ['requested', 'accepted', 'in_progress', 'completed'];
  static const _labels = ['Requested', 'Accepted', 'Cooking', 'Done'];

  @override
  Widget build(BuildContext context) {
    final idx = _steps.indexOf(status);
    final c = Theme.of(context).colorScheme.primary;
    final off = Theme.of(context).dividerColor;
    return Column(children: [
      Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i <= idx ? c : off),
            child: i <= idx ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
          ),
          if (i < _steps.length - 1)
            Expanded(child: Container(height: 3, color: i < idx ? c : off)),
        ],
      ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < _labels.length; i++)
          Text(_labels[i],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: i <= idx ? c : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500,
                  )),
      ]),
    ]);
  }
}
