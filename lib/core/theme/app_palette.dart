import 'package:flutter/material.dart';

/// لوحة ألوان ثيم واحد.
///
/// كل الألوان معرّفة صراحة لا مشتقّة من لون بذرة واحد: الثيمات هنا شخصيات
/// بصرية مختلفة (بحر، صيف، جبال...) لا تدرّجات لنفس اللون، والاشتقاق
/// التلقائي يطمس هذا الفرق.
@immutable
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isDark,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textMuted,
    required this.outline,
    required this.headerGradient,
  });

  /// معرّف ثابت يُحفظ على الجهاز — لا يتغيّر مع تغيّر الاسم المعروض.
  final String id;
  final String name;
  final String tagline;
  final bool isDark;

  final Color primary;
  final Color onPrimary;
  final Color secondary;

  /// لون التنبيه واللحظات الحاسمة (الستوب، آخر الثواني).
  final Color accent;

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textMuted;
  final Color outline;

  /// تدرّج الترويسات والبطاقات البارزة — أوضح ما يميّز ثيماً عن آخر.
  final List<Color> headerGradient;

  Brightness get brightness => isDark ? Brightness.dark : Brightness.light;
}

/// كل الثيمات المتاحة. الأول هو الافتراضي.
const List<AppPalette> appPalettes = [
  AppPalette(
    id: 'sea_breeze',
    name: 'نسيم البحر',
    tagline: 'أزرق هادي وبارد',
    isDark: false,
    primary: Color(0xFF1B7FA8),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF4FC3C7),
    accent: Color(0xFFFF7043),
    background: Color(0xFFEFF7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFDCEEF5),
    textPrimary: Color(0xFF0D3B4C),
    textMuted: Color(0xFF5C8195),
    outline: Color(0xFFB6D8E5),
    headerGradient: [Color(0xFF1B7FA8), Color(0xFF4FC3C7)],
  ),
  AppPalette(
    id: 'summer_sunset',
    name: 'غروب الصيف',
    tagline: 'برتقالي دافي',
    isDark: false,
    primary: Color(0xFFE0603A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFF2A65A),
    accent: Color(0xFFD81B60),
    background: Color(0xFFFFF6EF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFE6D6),
    textPrimary: Color(0xFF52251A),
    textMuted: Color(0xFF9A6A56),
    outline: Color(0xFFF3CBB4),
    headerGradient: [Color(0xFFE0603A), Color(0xFFF2A65A)],
  ),
  AppPalette(
    id: 'mountains',
    name: 'الجبال',
    tagline: 'أخضر وحجري',
    isDark: false,
    primary: Color(0xFF2F6B4F),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF7FA88C),
    accent: Color(0xFFC7622F),
    background: Color(0xFFF1F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFDFE9DF),
    textPrimary: Color(0xFF1E3528),
    textMuted: Color(0xFF63796B),
    outline: Color(0xFFC3D5C7),
    headerGradient: [Color(0xFF2F6B4F), Color(0xFF7FA88C)],
  ),
  AppPalette(
    id: 'desert',
    name: 'الصحراء',
    tagline: 'رملي وذهبي',
    isDark: false,
    primary: Color(0xFFB07A2E),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFD9A441),
    accent: Color(0xFF8C4A2F),
    background: Color(0xFFFBF5E9),
    surface: Color(0xFFFFFDF8),
    surfaceAlt: Color(0xFFF2E4C9),
    textPrimary: Color(0xFF4A3517),
    textMuted: Color(0xFF8A7351),
    outline: Color(0xFFE2CFA8),
    headerGradient: [Color(0xFFB07A2E), Color(0xFFD9A441)],
  ),
  AppPalette(
    id: 'night',
    name: 'سهرة الليل',
    tagline: 'بنفسجي غامق',
    isDark: true,
    primary: Color(0xFF8B7CF6),
    onPrimary: Color(0xFF14102B),
    secondary: Color(0xFF52D1DC),
    accent: Color(0xFFFF6B8A),
    background: Color(0xFF14122A),
    surface: Color(0xFF1F1C3B),
    surfaceAlt: Color(0xFF2A2650),
    textPrimary: Color(0xFFEDEAFF),
    textMuted: Color(0xFF9A93C7),
    outline: Color(0xFF3A3568),
    headerGradient: [Color(0xFF6D5BD0), Color(0xFF52D1DC)],
  ),
  AppPalette(
    id: 'orchard',
    name: 'البستان',
    tagline: 'أخضر فاتح ومنعش',
    isDark: false,
    primary: Color(0xFF4C8C2B),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF9CCC65),
    accent: Color(0xFFE91E63),
    background: Color(0xFFF4FAEE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE3F2D9),
    textPrimary: Color(0xFF233B14),
    textMuted: Color(0xFF6B8258),
    outline: Color(0xFFCBE3B8),
    headerGradient: [Color(0xFF4C8C2B), Color(0xFF9CCC65)],
  ),
];

AppPalette paletteById(String? id) => appPalettes.firstWhere(
  (palette) => palette.id == id,
  orElse: () => appPalettes.first,
);
