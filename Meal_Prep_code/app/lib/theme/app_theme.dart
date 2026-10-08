import 'package:flutter/material.dart';

/// Brand palette: saffron + curry-leaf green + a violet accent for AI features.
class AppColors {
  static const saffron = Color(0xFFE5632B);
  static const saffronLight = Color(0xFFFF8A3D);
  static const turmeric = Color(0xFFF2A541);
  static const curryLeaf = Color(0xFF2E7D5B);
  static const aiViolet = Color(0xFF7C4DFF);
  static const aiBlue = Color(0xFF4F7CFF);
  static const cream = Color(0xFFFFF6EE);
  static const ink = Color(0xFF1F1A17);
  static const veg = Color(0xFF1B9E4B);
  static const nonVeg = Color(0xFFC62828);

  // macro colours used across charts
  static const protein = Color(0xFF2E7D5B);
  static const carbs = Color(0xFFF2A541);
  static const fat = Color(0xFFE5632B);
  static const fibre = Color(0xFF7C4DFF);

  static const brandGradient = LinearGradient(
    colors: [saffronLight, saffron],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const aiGradient = LinearGradient(
    colors: [aiViolet, aiBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color fromHex(String hex, {Color fallback = saffron}) {
    final h = hex.replaceAll('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? fallback : Color(v);
  }
}

class AppTheme {
  static const _font = 'Poppins';
  static const radius = 20.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.saffron,
      brightness: b,
      primary: dark ? AppColors.saffronLight : AppColors.saffron,
      secondary: AppColors.curryLeaf,
      tertiary: AppColors.aiViolet,
      surface: dark ? const Color(0xFF1C1512) : const Color(0xFFFFFBF7),
    );
    final base = ThemeData(useMaterial3: true, brightness: b, colorScheme: scheme, fontFamily: _font);
    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final cardColor = dark ? const Color(0xFF2A211D) : Colors.white;
    final outline = dark ? Colors.white12 : const Color(0xFFF0E6DD);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface, fontFamily: _font),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: outline, width: 1.5),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: dark ? const Color(0xFF2A211D) : const Color(0xFFFFF3E9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: outline),
        labelStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: _font,
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    );
  }
}

/// Spacing scale.
class Gap {
  static const xs = SizedBox(width: 4, height: 4);
  static const sm = SizedBox(width: 8, height: 8);
  static const md = SizedBox(width: 12, height: 12);
  static const lg = SizedBox(width: 16, height: 16);
  static const xl = SizedBox(width: 24, height: 24);
}
