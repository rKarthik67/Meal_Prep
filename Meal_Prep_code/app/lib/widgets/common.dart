import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'emoji_art.dart';
import 'skeleton.dart';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(error.toString())),
      ]),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
}

void showInfo(BuildContext context, String message, {IconData icon = Icons.check_circle_outline}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

String rupees(num amount) {
  final s = amount.round().toString();
  if (s.length <= 3) return '₹$s';
  // Indian grouping: 1,23,456
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String prettyDate(DateTime d) {
  final today = DateTime.now();
  final t = DateTime(today.year, today.month, today.day);
  final diff = DateTime(d.year, d.month, d.day).difference(t).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

String prettyTime(String hhmmss) {
  final parts = hhmmss.split(':');
  var h = int.parse(parts[0]);
  final m = parts[1];
  final ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 == 0 ? 12 : h % 12;
  return '$h:$m $ampm';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

// ---------------------------------------------------------------- small widgets
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  static (Color, IconData) styleFor(String status) => switch (status) {
        'requested' => (const Color(0xFFE08A00), Icons.hourglass_top_rounded),
        'accepted' => (const Color(0xFF2F6FED), Icons.thumb_up_alt_rounded),
        'in_progress' => (AppColors.aiViolet, Icons.soup_kitchen_rounded),
        'completed' => (AppColors.curryLeaf, Icons.check_circle_rounded),
        'rejected' => (const Color(0xFF9E9E9E), Icons.block_rounded),
        _ => (const Color(0xFF9E9E9E), Icons.cancel_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          status.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

class VegDot extends StatelessWidget {
  const VegDot({super.key, required this.isVeg, this.size = 14});
  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = isVeg ? AppColors.veg : AppColors.nonVeg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(3)),
      child: Center(
        child: Container(
          width: size * 0.45,
          height: size * 0.45,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Small rounded label with optional icon.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color, this.filled = false});
  final String text;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: filled ? Colors.white : c), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: filled ? Colors.white : c, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const Pill('New', icon: Icons.fiber_new_rounded, color: AppColors.aiViolet);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.curryLeaf, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(rating.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(width: 2),
        const Icon(Icons.star_rounded, color: Colors.white, size: 14),
        Text(' ($count)', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action, this.onAction, this.padding});
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge),
            if (subtitle != null)
              Text(subtitle!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message, this.action, this.onAction});
  final String emoji;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EmojiArt(emoji, size: 96),
          const SizedBox(height: 16),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}

/// Generic loader for a Future-backed list with pull-to-refresh, skeletons and empty state.
class AsyncList<T> extends StatefulWidget {
  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    this.empty,
    this.header,
    this.padding = const EdgeInsets.only(bottom: 100),
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) itemBuilder;
  final Widget? empty;
  final Widget? header;
  final EdgeInsets padding;

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _future = widget.load();

  void reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return ListView(padding: widget.padding, children: [
            if (widget.header != null) widget.header!,
            for (var i = 0; i < 4; i++)
              const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 6), child: Skeleton(height: 96)),
          ]);
        }
        if (snap.hasError) {
          return EmptyState(
            emoji: '😕',
            title: 'Something went wrong',
            message: '${snap.error}',
            action: 'Try again',
            onAction: reload,
          );
        }
        final items = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView.builder(
            padding: widget.padding,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: (widget.header != null ? 1 : 0) + (items.isEmpty ? 1 : items.length),
            itemBuilder: (c, i) {
              if (widget.header != null) {
                if (i == 0) return widget.header!;
                i -= 1;
              }
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: widget.empty ?? const EmptyState(emoji: '🍽️', title: 'Nothing here yet'),
                );
              }
              return widget.itemBuilder(c, items[i], reload);
            },
          ),
        );
      },
    );
  }
}

/// Primary call-to-action with a brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppColors.brandGradient,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: gradient.colors.last.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                        Text(label,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
