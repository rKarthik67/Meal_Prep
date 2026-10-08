import 'package:flutter/material.dart';

import 'emoji_assets.dart';

/// Asset path of the bundled 3D artwork for [emoji], or null if we don't ship one.
String? emojiAsset(String emoji) {
  final code = emoji.runes.where((r) => r != 0xFE0F).map((r) => r.toRadixString(16)).join('_');
  return kEmojiAssets.contains(code) ? 'assets/emoji/emoji_u$code.png' : null;
}

/// 3D food / object artwork (Noto 3D emoji), falling back to the system emoji glyph.
class EmojiArt extends StatelessWidget {
  const EmojiArt(this.emoji, {super.key, this.size = 48});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = emojiAsset(emoji);
    if (path != null) {
      return Image.asset(
        path,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _glyph(),
      );
    }
    return _glyph();
  }

  Widget _glyph() => SizedBox(
        width: size,
        height: size,
        child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.78, height: 1))),
      );
}

/// Rounded tile with a soft tint behind 3D artwork; used for dishes, plans and categories.
class FoodTile extends StatelessWidget {
  const FoodTile({super.key, required this.emoji, this.color, this.size = 56, this.radius = 16});

  final String emoji;
  final Color? color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: EmojiArt(emoji, size: size * 0.76),
    );
  }
}
