import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import '../ai/ai_hub_screen.dart';
import '../ai/chat_screen.dart';
import '../bookings_screen.dart';
import '../profile_screen.dart';
import 'cook_profile_editor.dart';

/// Cook app shell: Dashboard · Jobs · AI · My profile · Account.
class CookHome extends StatefulWidget {
  const CookHome({super.key});

  @override
  State<CookHome> createState() => _CookHomeState();
}

class _CookHomeState extends State<CookHome> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      CookDashboard(onSwitchTab: _go),
      const BookingsScreen(),
      const AiHubScreen(),
      const CookProfileEditor(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.work_outline_rounded), selectedIcon: Icon(Icons.work_rounded), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Profile'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }
}

class CookDashboard extends StatefulWidget {
  const CookDashboard({super.key, required this.onSwitchTab});
  final ValueChanged<int> onSwitchTab;

  @override
  State<CookDashboard> createState() => _CookDashboardState();
}

class _CookDashboardState extends State<CookDashboard> {
  late Future<(Stats, Cook?, List<Booking>)> _future;
  late int _rev;

  @override
  void initState() {
    super.initState();
    _rev = context.read<Session>().revision;
    _future = _load();
  }

  Future<(Stats, Cook?, List<Booking>)> _load() async {
    final api = context.read<Session>().api;
    final stats = await api.stats();
    final profile = await api.myCookProfile();
    final jobs = await api.bookings();
    return (stats, profile, jobs);
  }

  Future<void> _toggleActive(Cook p, bool active) async {
    final session = context.read<Session>();
    try {
      await session.api.saveCookProfile({
        'bio': p.bio,
        'cuisines': p.cuisines,
        'languages': p.languages,
        'service_pincodes': p.servicePincodes,
        'veg_only': p.vegOnly,
        'experience_years': p.experienceYears,
        'hourly_rate': p.hourlyRate,
        'is_active': active,
      });
      session.bump();
      if (mounted) showInfo(context, active ? 'You\'re accepting bookings' : 'You\'re on a break');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.revision != _rev) {
      _rev = session.revision;
      _future = _load();
    }
    final user = session.user!;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          final f = _load();
          setState(() => _future = f);
          await f;
        },
        child: FutureBuilder<(Stats, Cook?, List<Booking>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(emoji: '😕', title: 'Couldn\'t load your dashboard', message: '${snap.error}');
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (stats, profile, jobs) = snap.data!;
            final pending = jobs.where((b) => b.status == 'requested').toList();
            final next = jobs.where((b) => b.status == 'accepted' || b.status == 'in_progress').toList()
              ..sort((a, b) => '${a.serviceDate}${a.startTime}'.compareTo('${b.serviceDate}${b.startTime}'));
            final completeness = _completeness(profile);
            return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${greeting()}, ${user.name.split(' ').first}', style: t.titleLarge),
                      Text(
                        profile == null
                            ? 'Set up your profile to get bookings'
                            : (profile.isActive ? 'You\'re visible to customers' : 'You\'re on a break'),
                        style: t.bodySmall,
                      ),
                    ]),
                  ),
                  if (profile != null)
                    Switch(value: profile.isActive, onChanged: (v) => _toggleActive(profile, v)),
                ]),
              ),
              if (completeness < 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => widget.onSwitchTab(3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(alignment: Alignment.center, children: [
                              CircularProgressIndicator(
                                value: completeness,
                                strokeWidth: 6,
                                backgroundColor: AppColors.saffron.withValues(alpha: 0.15),
                              ),
                              Text('${(completeness * 100).round()}%', style: t.labelLarge),
                            ]),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Complete your profile', style: t.titleSmall),
                              Text('Profiles with a bio, cuisines and 3+ dishes get far more requests.', style: t.bodySmall),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ]),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: StatTile(
                      emoji: '💰',
                      value: compactRupees(stats.monthly.isEmpty ? 0 : stats.monthly.last.$2.toDouble()),
                      label: 'this month',
                      color: AppColors.curryLeaf,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(emoji: '🔔', value: '${pending.length}', label: 'new requests')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      emoji: '⭐',
                      value: (stats.ratingCount ?? 0) == 0 ? 'New' : stats.ratingAvg!.toStringAsFixed(1),
                      label: '${stats.ratingCount ?? 0} reviews',
                      color: AppColors.turmeric,
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _AssistantBanner(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen(agentKey: 'cook_assistant')),
                  ),
                ),
              ),
              if (pending.isNotEmpty) ...[
                SectionHeader('New requests', action: 'All jobs', onAction: () => widget.onSwitchTab(1)),
                for (final b in pending.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: BookingCard(booking: b, isCook: true, onChanged: session.bump),
                  ),
              ],
              SectionHeader('Next up', action: next.isEmpty ? null : 'All jobs', onAction: () => widget.onSwitchTab(1)),
              if (next.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('No confirmed jobs yet.'),
                )
              else
                for (final b in next.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: ListTile(
                        leading: FoodTile(emoji: mealTypeIcons[b.mealType] ?? '🍛', size: 44, radius: 12),
                        title: Text('${b.customerName} · ${mealTypes[b.mealType] ?? b.mealType}', style: t.titleSmall),
                        subtitle: Text('${prettyDate(b.date)}, ${prettyTime(b.startTime)} · ${b.address.area}'),
                        trailing: StatusChip(b.status),
                      ),
                    ),
                  ),
              const SectionHeader('Earnings · last 6 months'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                    child: SimpleBarChart(
                      values: [for (final m in stats.monthly) (m.$1, m.$2.toDouble())],
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5FB98E), AppColors.curryLeaf],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      valueFormatter: (v) => rupees(v),
                    ),
                  ),
                ),
              ),
              if (profile != null) ...[
                const SectionHeader('Your public card'),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: CookCard(cook: profile)),
              ],
            ]);
          },
        ),
      ),
    );
  }

  double _completeness(Cook? p) {
    if (p == null) return 0;
    var score = 0;
    if (p.bio.length > 40) score++;
    if (p.cuisines.isNotEmpty) score++;
    if (p.languages.isNotEmpty) score++;
    if (p.servicePincodes.isNotEmpty) score++;
    if (p.dishes.length >= 3) score++;
    return score / 5;
  }
}

class _AssistantBanner extends StatelessWidget {
  const _AssistantBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(gradient: AppColors.aiGradient),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cook Assistant',
                    style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Better bio, smart pricing and job prep in one chat.',
                    style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
            const EmojiArt('🤖', size: 64),
          ]),
        ),
      ),
    );
  }
}
