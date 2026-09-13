import 'package:flutter/material.dart';

import 'app_palette.dart';

/// بناء ThemeData من لوحة ألوان.
///
/// الواجهة كلها تقرأ ألوانها من الثيم لا من ثوابت مبعثرة، فتبديل الثيم
/// يغيّر التطبيق كله فوراً بلا لمس أي شاشة.
class AppTheme {
  const AppTheme._();

  static ThemeData from(AppPalette palette) {
    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.surfaceAlt,
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onPrimary,
      secondaryContainer: palette.surfaceAlt,
      onSecondaryContainer: palette.textPrimary,
      tertiary: palette.accent,
      onTertiary: Colors.white,
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceAlt,
      onSurfaceVariant: palette.textMuted,
      outline: palette.outline,
      outlineVariant: palette.outline,
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.surface,
      shadow: Colors.black.withValues(alpha: 0.15),
      scrim: Colors.black54,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      fontFamily: _arabicFontFamily,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, palette),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: palette.textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _arabicFontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
            fontFamily: _arabicFontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.outline, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: _arabicFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: const TextStyle(
            fontFamily: _arabicFontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.isDark ? palette.surfaceAlt : palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: palette.textMuted),
        labelStyle: TextStyle(color: palette.textMuted),
        border: _inputBorder(palette.outline),
        enabledBorder: _inputBorder(palette.outline),
        focusedBorder: _inputBorder(palette.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt,
        side: BorderSide(color: palette.outline),
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontFamily: _arabicFontFamily,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: palette.outline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.textPrimary,
        contentTextStyle: TextStyle(
          color: palette.surface,
          fontFamily: _arabicFontFamily,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      extensions: [AppThemeExtras(palette: palette)],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base, AppPalette palette) => base
      .apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
        fontFamily: _arabicFontFamily,
      )
      .copyWith(
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      );

  /// خط الواجهة كلها: عربي أولاً.
  static const String _arabicFontFamily = 'Tajawal';

  /// الأرقام الكبيرة (عدّادات المراحل ولوحة النقاط) بخط لاتيني ثابت العرض
  /// بصرياً: الرقم لا "يقفز" وهو ينزل من 10 إلى 9، وهذا فرق محسوس في عدّاد
  /// يتغيّر كل ثانية أمام العين.
  static const String displayFontFamily = 'Outfit';
}

/// ما لا تحمله ColorScheme: التدرّج، لون التنبيه، ومعرّف الثيم.
@immutable
class AppThemeExtras extends ThemeExtension<AppThemeExtras> {
  const AppThemeExtras({required this.palette});

  final AppPalette palette;

  @override
  AppThemeExtras copyWith({AppPalette? palette}) =>
      AppThemeExtras(palette: palette ?? this.palette);

  @override
  AppThemeExtras lerp(covariant AppThemeExtras? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppThemeExtras>()!.palette;

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;
}
