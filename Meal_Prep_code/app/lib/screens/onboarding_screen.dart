import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/emoji_art.dart';

/// First-time setup: name + whether you're booking a cook or working as one.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  String _role = 'customer';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showError(context, 'Please enter your name');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<Session>().updateProfile(name: _name.text.trim(), role: _role);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const EmojiArt('👋', size: 64),
              const SizedBox(height: 12),
              Text('Welcome! Let\'s set you up', style: t.headlineSmall),
              const SizedBox(height: 4),
              Text('It takes 10 seconds.', style: t.bodyMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 28),
              Text('I want to…', style: t.titleMedium),
              const SizedBox(height: 12),
              _RoleCard(
                emoji: '🏠',
                title: 'Book a cook',
                subtitle: 'Fresh home-cooked meals, diet charts and AI meal planning.',
                color: AppColors.saffron,
                selected: _role == 'customer',
                onTap: () => setState(() => _role = 'customer'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                emoji: '🧑‍🍳',
                title: 'Work as a cook',
                subtitle: 'Get booked by families near you and grow your income.',
                color: AppColors.curryLeaf,
                selected: _role == 'cook',
                onTap: () => setState(() => _role = 'cook'),
              ),
              const SizedBox(height: 32),
              GradientButton(label: 'Get started', icon: Icons.arrow_forward_rounded, busy: _busy, onPressed: _save),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : Theme.of(context).dividerColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            FoodTile(emoji: emoji, color: color, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodySmall),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? color : Theme.of(context).disabledColor),
          ]),
        ),
      ),
    );
  }
}
