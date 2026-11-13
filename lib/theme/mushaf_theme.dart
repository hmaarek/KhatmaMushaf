import 'package:flutter/material.dart';

enum MushafThemeType {
  warmPaper,
  crispWhite,
  amoledDark,
}

class MushafThemeData {
  final MushafThemeType type;
  final String name;
  final String arabicLabel;
  final IconData icon;
  final Brightness brightness;
  final Color scaffoldBackground;
  final Color pageBackground;
  final Color pageOuterBorder;
  final Color pageInnerBorder;
  final Color glyphColor;
  final Color secondaryTextColor;
  final Color ornamentPrimary;
  final Color ornamentSecondary;
  final Color ornamentFill;
  final Color ayahHighlightFill;
  final Color ayahHighlightBorder;
  final Color hudBackground;
  final Color hudSurface;
  final Color hudText;
  final Color bookmarkRibbon;

  const MushafThemeData({
    required this.type,
    required this.name,
    required this.arabicLabel,
    required this.icon,
    required this.brightness,
    required this.scaffoldBackground,
    required this.pageBackground,
    required this.pageOuterBorder,
    required this.pageInnerBorder,
    required this.glyphColor,
    required this.secondaryTextColor,
    required this.ornamentPrimary,
    required this.ornamentSecondary,
    required this.ornamentFill,
    required this.ayahHighlightFill,
    required this.ayahHighlightBorder,
    required this.hudBackground,
    required this.hudSurface,
    required this.hudText,
    required this.bookmarkRibbon,
  });

  bool get isDark => brightness == Brightness.dark;

  /// 1. Warm Mushaf Paper (Cream / Sepia) — authentic printed Madinah Mushaf feel
  static const MushafThemeData warmPaper = MushafThemeData(
    type: MushafThemeType.warmPaper,
    name: 'Warm Paper',
    arabicLabel: 'ورق المصحف',
    icon: Icons.auto_stories_rounded,
    brightness: Brightness.light,
    scaffoldBackground: Color(0xFFF1E5CD),
    pageBackground: Color(0xFFFAF2E1),
    pageOuterBorder: Color(0xFFB5945B),
    pageInnerBorder: Color(0xFFD6BE8F),
    glyphColor: Color(0xFF1B140C),
    secondaryTextColor: Color(0xFF6B532C),
    ornamentPrimary: Color(0xFF8C672A),
    ornamentSecondary: Color(0xFFC8A464),
    ornamentFill: Color(0xFFF3E4C6),
    ayahHighlightFill: Color(0x40D49B35),
    ayahHighlightBorder: Color(0xFFB58025),
    hudBackground: Color(0xEB241B10),
    hudSurface: Color(0xFF352818),
    hudText: Color(0xFFF8EFE0),
    bookmarkRibbon: Color(0xFFB8292F),
  );

  /// 2. Crisp White — clean daylight reading
  static const MushafThemeData crispWhite = MushafThemeData(
    type: MushafThemeType.crispWhite,
    name: 'Crisp White',
    arabicLabel: 'أبيض ناصع',
    icon: Icons.wb_sunny_outlined,
    brightness: Brightness.light,
    scaffoldBackground: Color(0xFFECEFF3),
    pageBackground: Color(0xFFFFFFFF),
    pageOuterBorder: Color(0xFF2B6E5E),
    pageInnerBorder: Color(0xFFA9C7BF),
    glyphColor: Color(0xFF0F1419),
    secondaryTextColor: Color(0xFF3B5A52),
    ornamentPrimary: Color(0xFF1E6353),
    ornamentSecondary: Color(0xFF7FA99E),
    ornamentFill: Color(0xFFEEF6F4),
    ayahHighlightFill: Color(0x332A9D8F),
    ayahHighlightBorder: Color(0xFF1E6353),
    hudBackground: Color(0xEB102420),
    hudSurface: Color(0xFF1B3832),
    hudText: Color(0xFFF4F9F8),
    bookmarkRibbon: Color(0xFFC02935),
  );

  /// 3. True AMOLED Dark Mode — pure #000000 background with cleanly recolored glyphs
  static const MushafThemeData amoledDark = MushafThemeData(
    type: MushafThemeType.amoledDark,
    name: 'AMOLED Dark',
    arabicLabel: 'داكن AMOLED',
    icon: Icons.dark_mode_outlined,
    brightness: Brightness.dark,
    scaffoldBackground: Color(0xFF000000),
    pageBackground: Color(0xFF000000),
    pageOuterBorder: Color(0xFF4A3C24),
    pageInnerBorder: Color(0xFF2C2315),
    glyphColor: Color(0xFFEDE6D8),
    secondaryTextColor: Color(0xFFB39B6E),
    ornamentPrimary: Color(0xFFCBA660),
    ornamentSecondary: Color(0xFF6B5530),
    ornamentFill: Color(0xFF110E09),
    ayahHighlightFill: Color(0x38D4AF37),
    ayahHighlightBorder: Color(0xFFCBA660),
    hudBackground: Color(0xEE121212),
    hudSurface: Color(0xFF1E1E1E),
    hudText: Color(0xFFEDE6D8),
    bookmarkRibbon: Color(0xFFE0484E),
  );

  static MushafThemeData fromType(MushafThemeType type) {
    switch (type) {
      case MushafThemeType.warmPaper:
        return warmPaper;
      case MushafThemeType.crispWhite:
        return crispWhite;
      case MushafThemeType.amoledDark:
        return amoledDark;
    }
  }

  static const List<MushafThemeData> all = [
    warmPaper,
    crispWhite,
    amoledDark,
  ];
}
