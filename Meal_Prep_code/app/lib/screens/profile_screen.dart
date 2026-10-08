import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/emoji_art.dart';
import 'address_form_screen.dart';
import 'insights_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Stats> _stats = context.read<Session>().api.stats();
  late int _rev = context.read<Session>().revision;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.revision != _rev) {
      _rev = session.revision;
      _stats = session.api.stats();
    }
    final user = session.user!;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(28)),
          child: Row(children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: EmojiArt(user.isCook ? '🧑‍🍳' : '😋', size: 56),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                Text(user.phone, style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                  child: Text(user.isCook ? 'Home cook' : 'Member',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ]),
        ),
        FutureBuilder<Stats>(
          future: _stats,
          builder: (context, snap) {
            final s = snap.data;
            if (s == null) return const SizedBox(height: 16);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(child: StatTile(emoji: '✅', value: '${s.completed}', label: user.isCook ? 'jobs done' : 'meals booked')),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    emoji: '💰',
                    value: compactRupees(s.totalAmount.toDouble()),
                    label: user.isCook ? 'earned' : 'spent',
                    color: AppColors.curryLeaf,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    emoji: '⏰',
                    value: '${s.hoursSaved} h',
                    label: user.isCook ? 'cooked' : 'saved',
                    color: AppColors.aiViolet,
                  ),
                ),
              ]),
            );
          },
        ),
        const SizedBox(height: 12),
        _Group(children: [
          _Item(
            icon: Icons.insights_rounded,
            color: AppColors.aiViolet,
            title: user.isCook ? 'Earnings & insights' : 'Spending & insights',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsScreen())),
          ),
          if (!user.isCook)
            _Item(
              icon: Icons.location_on_rounded,
              color: AppColors.saffron,
              title: 'Saved addresses',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen())),
            ),
        ]),
        _Group(children: [
          _Item(
            icon: Icons.support_agent_rounded,
            color: AppColors.curryLeaf,
            title: 'Help & support',
            onTap: () => showInfo(context, 'Write to us at support@mealprep.app', icon: Icons.mail_outline_rounded),
          ),
          _Item(
            icon: Icons.verified_user_rounded,
            color: const Color(0xFF2F6FED),
            title: 'Safety & verification',
            onTap: () => showModalBottomSheet<void>(context: context, builder: (_) => const _SafetySheet()),
          ),
          _Item(
            icon: Icons.info_outline_rounded,
            color: AppColors.turmeric,
            title: 'About',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Meal Prep',
              applicationVersion: '0.2.0',
              applicationIcon: const EmojiArt('🍛', size: 48),
              children: [
                const Text('3D food artwork: Noto Emoji by Google (SIL Open Font License).'),
                const SizedBox(height: 6),
                Text('API: $apiBaseUrl'),
              ],
            ),
          ),
        ]),
        _Group(children: [
          _Item(
            icon: Icons.logout_rounded,
            color: Theme.of(context).colorScheme.error,
            title: 'Log out',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                  ],
                ),
              );
              if (ok == true) await session.logout();
            },
          ),
        ]),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(indent: 64),
            ],
          ]),
        ),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.color, required this.title, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

class _SafetySheet extends StatelessWidget {
  const _SafetySheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your safety comes first', style: t.titleLarge),
        const SizedBox(height: 12),
        for (final (icon, text) in const [
          (Icons.badge_rounded, 'Cooks with the blue tick have completed ID and background verification.'),
          (Icons.star_rounded, 'Ratings come only from customers who completed a booking.'),
          (Icons.lock_rounded, 'Your address is shared with the cook only after they accept.'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: t.bodyMedium)),
            ]),
          ),
      ]),
    );
  }
}

/// Manage saved addresses.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _key = GlobalKey<AsyncListState<Address>>();

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddressFormScreen()),
          );
          if (added == true) _key.currentState?.reload();
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add address'),
      ),
      body: AsyncList<Address>(
        key: _key,
        load: api.addresses,
        empty: const EmptyState(emoji: '🏠', title: 'No addresses yet', message: 'Add where the cook should come.'),
        itemBuilder: (context, a, reload) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Card(
            child: ListTile(
              leading: const FoodTile(emoji: '🏠', size: 44, radius: 12),
              title: Text(a.label, style: Theme.of(context).textTheme.titleSmall),
              subtitle: Text('${a.line1}, ${a.area}, ${a.city} ${a.pincode}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  try {
                    await api.deleteAddress(a.id);
                    reload();
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
