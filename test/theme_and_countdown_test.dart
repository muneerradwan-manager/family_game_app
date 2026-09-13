import 'package:family_game_app/core/theme/app_palette.dart';
import 'package:family_game_app/core/theme/app_theme.dart';
import 'package:family_game_app/core/theme/theme_cubit.dart';
import 'package:family_game_app/shared/widgets/countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {AppPalette? palette}) => MaterialApp(
  theme: AppTheme.from(palette ?? appPalettes.first),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('الثيمات', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('يبدأ بالثيم الافتراضي حين لا يوجد اختيار محفوظ', () async {
      final cubit = ThemeCubit(await SharedPreferences.getInstance());

      expect(cubit.state.id, appPalettes.first.id);
    });

    test('يحفظ الاختيار ويستعيده عند الإقلاع التالي', () async {
      final preferences = await SharedPreferences.getInstance();
      final night = appPalettes.firstWhere((palette) => palette.id == 'night');

      ThemeCubit(preferences).select(night);

      // نسخة جديدة تحاكي تشغيل التطبيق من جديد.
      expect(ThemeCubit(preferences).state.id, 'night');
    });

    test('كل ثيم يعرّف لوحته كاملة ومعرّفه فريد', () {
      final ids = appPalettes.map((palette) => palette.id).toSet();

      expect(ids.length, appPalettes.length, reason: 'معرّفات الثيمات فريدة');
      expect(appPalettes.length, greaterThanOrEqualTo(4));

      for (final palette in appPalettes) {
        expect(palette.name, isNotEmpty);
        expect(palette.headerGradient.length, greaterThanOrEqualTo(2));
      }
    });

    testWidgets('تبديل الثيم يغيّر ألوان الواجهة', (tester) async {
      final sea = appPalettes.firstWhere(
        (palette) => palette.id == 'sea_breeze',
      );
      final desert = appPalettes.firstWhere(
        (palette) => palette.id == 'desert',
      );

      await tester.pumpWidget(_wrap(const Text('مرحبا'), palette: sea));

      final first = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(first.theme!.colorScheme.primary, sea.primary);

      await tester.pumpWidget(_wrap(const Text('مرحبا'), palette: desert));

      final second = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(second.theme!.colorScheme.primary, desert.primary);
    });

    testWidgets('كل الواجهة تقرأ اللوحة من الثيم لا من ثوابت', (tester) async {
      final mountains = appPalettes.firstWhere(
        (palette) => palette.id == 'mountains',
      );

      late AppPalette resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.from(mountains),
          home: Builder(
            builder: (context) {
              resolved = context.palette;

              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.id, 'mountains');
    });
  });

  group('عدّاد المرحلة', () {
    testWidgets('يحسب المتبقي من موعد السيرفر لا من لحظة البناء', (
      tester,
    ) async {
      final serverDeadline = DateTime.now().millisecondsSinceEpoch + 7400;

      await tester.pumpWidget(
        _wrap(
          PhaseCountdown(
            deadline: serverDeadline,
            clockSkewMs: 0,
            totalSeconds: 20,
          ),
        ),
      );

      // من يفتح الشاشة متأخراً يرى ما تبقّى فعلاً، لا المدة كاملة.
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('يصحّح انحراف ساعة الجهاز عن السيرفر', (tester) async {
      // جهاز متأخر 30 ثانية: بلا تصحيح سيعرض 40 بدل 10.
      const skew = 30000;
      final serverDeadline =
          DateTime.now().millisecondsSinceEpoch + skew + 9600;

      await tester.pumpWidget(
        _wrap(
          PhaseCountdown(
            deadline: serverDeadline,
            clockSkewMs: skew,
            totalSeconds: 20,
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('يقف عند الصفر ولا ينزل تحته', (tester) async {
      final past = DateTime.now().millisecondsSinceEpoch - 5000;

      await tester.pumpWidget(
        _wrap(PhaseCountdown(deadline: past, clockSkewMs: 0)),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('ينادي onFinished مرة واحدة لا مرة كل نبضة', (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        _wrap(
          PhaseCountdown(
            deadline: DateTime.now().millisecondsSinceEpoch - 1000,
            clockSkewMs: 0,
            onFinished: () => calls++,
          ),
        ),
      );

      // العدّاد ينبض كل 100 ملّي؛ لو لم يُختم الإبلاغ لتكرّر النداء عشرات المرات.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(calls, 1);
    });

    testWidgets('الرقم يرتفع بحركة بدل أن يقفز', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedScore(100)));

      expect(find.text('0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));

      expect(find.text('100'), findsOneWidget);
    });
  });
}
