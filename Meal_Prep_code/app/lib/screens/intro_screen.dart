import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_art.dart';

class _Slide {
  final String main;
  final List<String> extras;
  final Color color;
  final String title;
  final String body;
  const _Slide(this.main, this.extras, this.color, this.title, this.body);
}

const _slides = [
  _Slide('🧑‍🍳', ['🍛', '🫓', '🥗'], AppColors.saffron, 'A trusted cook,\nin your kitchen',
      'Verified home cooks who make fresh, home-style food the way your family likes it.'),
  _Slide('🍱', ['📅', '🥦', '🥚'], AppColors.curryLeaf, 'Diet charts that\nfit your week',
      'Ready-made weekly meal plans with nutrition charts and grocery lists, from South Indian to high-protein.'),
  _Slide('🤖', ['✨', '🍲', '🛒'], AppColors.aiViolet, 'AI that plans,\nshops & books',
      'Tell our AI agents what you need. They build a plan, list the groceries and line up the right cook.'),
];

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      context.read<Session>().markIntroSeen();
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final slide = _slides[_page];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () => context.read<Session>().markIntroSeen(),
              child: const Text('Skip'),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final s = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(children: [
                    Expanded(child: Center(child: _Art(slide: s))),
                    Text(s.title, textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(height: 1.2)),
                    const SizedBox(height: 12),
                    Text(
                      s.body,
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? slide.color : slide.color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: slide.color),
                onPressed: _next,
                child: Text(_page == _slides.length - 1 ? 'Get started' : 'Next'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = (c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth).clamp(200.0, 340.0);
      return SizedBox(
        width: s,
        height: s,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                slide.color.withValues(alpha: 0.22),
                slide.color.withValues(alpha: 0.04),
              ]),
            ),
          ),
          EmojiArt(slide.main, size: s * 0.52),
          Positioned(left: s * 0.02, top: s * 0.12, child: EmojiArt(slide.extras[0], size: s * 0.24)),
          Positioned(right: s * 0.0, top: s * 0.2, child: EmojiArt(slide.extras[1], size: s * 0.22)),
          Positioned(right: s * 0.1, bottom: s * 0.02, child: EmojiArt(slide.extras[2], size: s * 0.24)),
        ]),
      );
    });
  }
}
