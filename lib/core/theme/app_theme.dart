import 'package:flutter/material.dart';

import 'app_palette.dart';

/// مقاسات الزوايا — نفسها في لوحة الإدارة، فالتطبيق واللوحة من عائلة واحدة.
class AppRadius {
  const AppRadius._();

  static const double card = 14;
  static const double control = 10;
  static const double sheet = 18;
}

/// ظل البطاقات: خفيف جداً. الحدّ الرفيع هو ما يفصل البطاقة عن الخلفية،
/// والظل يعطيها عمقاً لا أكثر.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card(AppPalette palette) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: palette.isDark ? 0.18 : 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

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
      error: palette.danger,
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

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, palette),
      // شريط علوي كشريط لوحة الإدارة: سطح أبيض بحدّ سفلي، والعنوان إلى البداية.
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        foregroundColor: palette.textPrimary,
        shape: Border(bottom: BorderSide(color: palette.outline)),
        titleTextStyle: TextStyle(
          fontFamily: _arabicFontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: palette.outline),
        ),
      ),
      // عرض كامل افتراضياً: شاشات اللعب كلها مبنية على زر يملأ سطره.
      // الأزرار داخل صف (رأس الصفحة) تمرّر AppButtonStyle.compact.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: _arabicFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.surface,
          side: BorderSide(color: palette.outline),
          textStyle: const TextStyle(
            fontFamily: _arabicFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: _arabicFontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textMuted,
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.isDark ? palette.surfaceAlt : palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: palette.textMuted),
        labelStyle: TextStyle(color: palette.textMuted),
        border: _inputBorder(palette.outline),
        enabledBorder: _inputBorder(palette.outline),
        focusedBorder: _inputBorder(palette.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt,
        side: BorderSide(color: palette.outline),
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontFamily: _arabicFontFamily,
        ),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: palette.outline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(iconColor: palette.textMuted),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.sidebar,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: _arabicFontFamily,
          fontWeight: FontWeight.w500,
        ),
        shape: controlShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        showDragHandle: true,
        dragHandleColor: palette.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: palette.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: palette.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _arabicFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.textMuted,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.sidebar,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontFamily: _arabicFontFamily,
          fontSize: 12.5,
        ),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        radius: Radius.circular(8),
        thickness: WidgetStatePropertyAll(6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.surfaceAlt,
      ),
      extensions: [AppThemeExtras(palette: palette)],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base, AppPalette palette) => base
      .apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
        fontFamily: _arabicFontFamily,
      )
      .copyWith(
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
