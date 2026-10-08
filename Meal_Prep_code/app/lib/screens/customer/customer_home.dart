import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import '../../widgets/skeleton.dart';
import '../ai/ai_hub_screen.dart';
import '../ai/chat_screen.dart';
import '../bookings_screen.dart';
import '../plans/plan_detail_screen.dart';
import '../plans/plans_tab.dart';
import '../profile_screen.dart';
import 'cook_detail_screen.dart';
import 'find_cooks_screen.dart';

/// Customer app shell: Home · Plans · AI · Bookings · Profile.
class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(onSwitchTab: _go),
      const PlansTab(),
      const AiHubScreen(),
      const BookingsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Plans'),
          NavigationDestination(icon: _AiNavIcon(), label: 'AI'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'Bookings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _AiNavIcon extends StatelessWidget {
  const _AiNavIcon();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(gradient: AppColors.aiGradient, shape: BoxShape.circle),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
      );
}

// =====================================================================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onSwitchTab});
  final ValueChanged<int> onSwitchTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<_HomeData> _future;
  late int _rev;

  @override
  void initState() {
    super.initState();
    _rev = context.read<Session>().revision;
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final api = context.read<Session>().api;
    final addresses = await api.addresses();
    final pin = addresses.isNotEmpty ? addresses.first.pincode : null;
    final results = await Future.wait([
      api.mealPlans(),
      api.searchCooks(pincode: pin),
      api.bookings(),
    ]);
    var cooks = results[1] as List<Cook>;
    if (cooks.isEmpty && pin != null) cooks = await api.searchCooks();
    final bookings = (results[2] as List<Booking>).where((b) => b.isActive).toList()
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    return _HomeData(
      address: addresses.isNotEmpty ? addresses.first : null,
      plans: results[0] as List<MealPlanSummary>,
      cooks: cooks,
      upcoming: bookings.isEmpty ? null : bookings.first,
    );
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  void _openCook(Cook c) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => CookDetailScreen(cookId: c.userId)));

  void _findCooks({String? cuisine, String? pincode, String? mealType}) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FindCooksScreen(cuisine: cuisine, pincode: pincode, mealType: mealType)),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user!;
    final rev = context.select<Session, int>((s) => s.revision);
    if (rev != _rev) {
      // bookings/plans changed elsewhere (e.g. confirmed from an AI chat) → reload
      _rev = rev;
      _future = _load();
    }
    final t = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snap) {
            final d = snap.data;
            return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
              // ---------------- header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${greeting()}, ${user.name.split(' ').first} 👋', style: t.titleLarge),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => widget.onSwitchTab(4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            d?.address == null ? 'Add your address' : '${d!.address!.area}, ${d.address!.pincode}',
                            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        ]),
                      ),
                    ]),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => showInfo(context, 'You\'re all caught up!', icon: Icons.notifications_none_rounded),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ]),
              ),
              // ---------------- search
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _findCooks(pincode: d?.address?.pincode),
                  child: InputDecorator(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded)),
                    child: Text('Search cooks, cuisines…',
                        style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
              ),
              // ---------------- AI hero
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _AiHero(onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen(agentKey: 'meal_planner')),
                    )),
              ),
              // ---------------- upcoming booking
              if (d?.upcoming != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _UpcomingCard(booking: d!.upcoming!, onTap: () => widget.onSwitchTab(3)),
                ),
              // ---------------- quick actions
              const SectionHeader('What do you need?'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _QuickAction(emoji: '🍛', label: 'Daily\nmeals', color: AppColors.saffron,
                      onTap: () => _findCooks(pincode: d?.address?.pincode, mealType: 'lunch')),
                  _QuickAction(emoji: '🍱', label: 'Weekly\nmeal prep', color: AppColors.curryLeaf,
                      onTap: () => _findCooks(pincode: d?.address?.pincode, mealType: 'meal_prep')),
                  _QuickAction(emoji: '🎉', label: 'Party\ncook', color: AppColors.aiViolet,
                      onTap: () => _findCooks(pincode: d?.address?.pincode, mealType: 'party')),
                  _QuickAction(emoji: '📅', label: 'Diet\ncharts', color: AppColors.turmeric,
                      onTap: () => widget.onSwitchTab(1)),
                ]),
              ),
              // ---------------- plans
              SectionHeader('Diet charts for you',
                  subtitle: 'Weekly plans with nutrition & grocery lists', action: 'See all',
                  onAction: () => widget.onSwitchTab(1)),
              SizedBox(
                height: 252,
                child: d == null
                    ? _skeletonRow(220, 240)
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: d.plans.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => PlanCard(
                          plan: d.plans[i],
                          width: 230,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: d.plans[i].id)),
                          ),
                        ),
                      ),
              ),
              // ---------------- cuisines
              const SectionHeader('Explore cuisines'),
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in const [
                      'South Indian', 'North Indian', 'Kerala', 'Karnataka', 'Chettinad', 'Mughlai', 'Jain', 'Bengali'
                    ])
                      _CuisineChip(cuisine: c, onTap: () => _findCooks(cuisine: c, pincode: d?.address?.pincode)),
                  ],
                ),
              ),
              // ---------------- cooks
              SectionHeader('Top cooks near you', action: 'See all',
                  onAction: () => _findCooks(pincode: d?.address?.pincode)),
              SizedBox(
                height: 190,
                child: d == null
                    ? _skeletonRow(168, 170)
                    : d.cooks.isEmpty
                        ? const Center(child: Text('No cooks in your area yet'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: d.cooks.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => CookMiniCard(cook: d.cooks[i], onTap: () => _openCook(d.cooks[i])),
                          ),
              ),
              // ---------------- how it works
              const SectionHeader('How it works'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _Step(n: 1, emoji: '🔍', title: 'Pick a cook or a diet chart',
                      body: 'Compare ratings, cuisines and price. Or let AI plan your week.'),
                  _Step(n: 2, emoji: '📅', title: 'Choose a time',
                      body: 'Daily, weekly meal prep or a one-off party. Get an instant price.'),
                  _Step(n: 3, emoji: '🍲', title: 'Enjoy fresh food',
                      body: 'Your cook arrives, cooks in your kitchen, and leaves it clean.'),
                ]),
              ),
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Couldn\'t load everything: ${snap.error}', style: t.bodySmall),
                ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _skeletonRow(double w, double h) => ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Skeleton(width: w, height: h),
      );
}

class _HomeData {
  final Address? address;
  final List<MealPlanSummary> plans;
  final List<Cook> cooks;
  final Booking? upcoming;
  _HomeData({required this.address, required this.plans, required this.cooks, required this.upcoming});
}

class _AiHero extends StatelessWidget {
  const _AiHero({required this.onTap});
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
          decoration: const BoxDecoration(gradient: AppColors.aiGradient),
          child: Stack(children: [
            Positioned(
              right: -20,
              top: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            const Positioned(right: 8, bottom: 6, child: EmojiArt('🤖', size: 96)),
            const Positioned(right: 92, top: 12, child: EmojiArt('✨', size: 32)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 120, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Text('NEW · AI AGENTS',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                const SizedBox(height: 10),
                Text('Plan your week in one chat',
                    style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Meal plan → grocery list → cook booked.',
                    style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Try Meal Planner →',
                      style: TextStyle(color: AppColors.aiViolet, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            FoodTile(emoji: mealTypeIcons[booking.mealType] ?? '🍛', size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Upcoming · ${prettyDate(booking.date)}, ${prettyTime(booking.startTime)}',
                    style: t.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                Text('${booking.cookName} · ${mealTypes[booking.mealType] ?? booking.mealType}', style: t.titleSmall),
              ]),
            ),
            StatusChip(booking.status),
          ]),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.emoji, required this.label, required this.color, required this.onTap});
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(children: [
            FoodTile(emoji: emoji, color: color, size: 64, radius: 20),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      ),
    );
  }
}

class _CuisineChip extends StatelessWidget {
  const _CuisineChip({required this.cuisine, required this.onTap});
  final String cuisine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardTheme.color,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              padding: const EdgeInsets.all(12),
              child: EmojiArt(cuisineEmoji(cuisine), size: 52),
            ),
            const SizedBox(height: 6),
            Text(cuisine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.emoji, required this.title, required this.body});
  final int n;
  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FoodTile(emoji: emoji, size: 48, radius: 14),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n. $title', style: t.titleSmall),
            Text(body, style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
