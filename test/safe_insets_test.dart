import 'package:family_game_app/shared/widgets/common.dart';
import 'package:family_game_app/shared/widgets/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// شريط تنقّل نظام بارتفاع نموذجي على أندرويد.
const _navBar = EdgeInsets.only(bottom: 48);

const _phone = Size(390, 844);
const _tablet = Size(1280, 900);

/// يبني شجرة بمقاس وحشوة نظام محدّدين، ويعيد ما قرأته الواجهة منهما.
Future<T> _probe<T>(
  WidgetTester tester,
  T Function(BuildContext context) read, {
  Size size = _phone,
  EdgeInsets padding = _navBar,
  bool insideSafeArea = false,
}) async {
  late T value;

  final probe = Builder(
    builder: (context) {
      value = read(context);

      return const SizedBox.shrink();
    },
  );

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, padding: padding),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: insideSafeArea ? SafeArea(child: probe) : probe,
      ),
    ),
  );

  return value;
}

void main() {
  group('الحشوة أسفل الشاشة', () {
    testWidgets('تعكس ارتفاع شريط تنقّل النظام', (tester) async {
      final inset = await _probe(tester, (context) => context.bottomInset);

      expect(inset, 48);
    });

    testWidgets('listPadding تضيفه لحشوة القائمة', (tester) async {
      final padding = await _probe(
        tester,
        (context) => context.listPadding(bottom: 32),
      );

      expect(padding.bottom, 32 + 48, reason: 'آخر عنصر يجب أن يعلو الشريط');
      expect(padding.top, 20);
    });

    testWidgets('لا تُحسب مرتين داخل SafeArea', (tester) async {
      final inset = await _probe(
        tester,
        (context) => context.bottomInset,
        insideSafeArea: true,
      );

      // SafeArea استهلكها فعلاً؛ إضافتها ثانية تترك فراغاً مضاعفاً.
      expect(inset, 0);
    });

    testWidgets('بلا شريط تنقّل تبقى الحشوة كما هي', (tester) async {
      final padding = await _probe(
        tester,
        (context) => context.listPadding(bottom: 32),
        padding: EdgeInsets.zero,
      );

      expect(padding.bottom, 32);
    });

    testWidgets('contentPadding لا تضيف الشريط — التذييل يحجزه', (
      tester,
    ) async {
      final padding = await _probe(
        tester,
        (context) => context.contentPadding(bottom: 12),
      );

      expect(padding.bottom, 12);
    });
  });

  group('التكيّف مع الشاشات العريضة', () {
    testWidgets('على الجوال: حشوة جانبية ثابتة والمحتوى يملأ العرض', (
      tester,
    ) async {
      final padding = await _probe(
        tester,
        (context) => context.listPadding(),
        size: _phone,
      );

      expect(padding.left, 20);
      expect(padding.right, 20);
    });

    testWidgets('على شاشة عريضة: المحتوى يتوسّط ويُحدّ عرضه', (tester) async {
      final padding = await _probe(
        tester,
        (context) => context.listPadding(),
        size: _tablet,
      );

      expect(padding.left, padding.right, reason: 'موسّط');

      final contentWidth = _tablet.width - padding.left - padding.right;
      expect(contentWidth, ContentWidth.standard);
    });

    testWidgets('النماذج أضيق من القوائم', (tester) async {
      final form = await _probe(
        tester,
        (context) => context.listPadding(maxWidth: ContentWidth.form),
        size: _tablet,
      );

      final formWidth = _tablet.width - form.left - form.right;

      expect(formWidth, ContentWidth.form);
      expect(formWidth, lessThan(ContentWidth.standard));
    });

    testWidgets('عمودان على الشاشة العريضة وعمود واحد على الجوال', (
      tester,
    ) async {
      expect(
        await _probe(tester, (context) => context.isWide, size: _phone),
        isFalse,
      );
      expect(
        await _probe(tester, (context) => context.isWide, size: _tablet),
        isTrue,
      );
    });
  });

  group('AdaptiveColumns', () {
    Future<void> pump(WidgetTester tester, Size size, int count) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AdaptiveColumns(
              children: [
                for (var index = 0; index < count; index++)
                  SizedBox(height: 40, child: Text('حقل $index')),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('عمود واحد على الجوال', (tester) async {
      await pump(tester, _phone, 5);

      expect(find.byType(Row), findsNothing);
      expect(find.textContaining('حقل'), findsNWidgets(5));
    });

    testWidgets('عمودان على الشاشة العريضة', (tester) async {
      await pump(tester, _tablet, 6);

      expect(find.byType(Row), findsNWidgets(3));
      expect(find.textContaining('حقل'), findsNWidgets(6));
    });

    testWidgets('عدد فردي لا يُفقد آخر عنصر', (tester) async {
      await pump(tester, _tablet, 5);

      expect(find.textContaining('حقل'), findsNWidgets(5));
      expect(find.byType(Row), findsNWidgets(3), reason: 'الأخير وحده في سطره');
    });
  });
}
