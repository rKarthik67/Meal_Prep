import 'package:flutter/material.dart';

/// Shimmering placeholder block shown while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width = double.infinity, this.height = 16, this.radius = 16});

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2E2622) : const Color(0xFFF3EAE2);
    final hi = dark ? const Color(0xFF3B312C) : const Color(0xFFFFF8F2);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = _c.value * 3 - 1.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [base, hi, base],
            ),
          ),
        );
      },
    );
  }
}
