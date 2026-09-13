import 'package:flutter/material.dart';

/// أقصى عرض للمحتوى حسب نوعه.
///
/// الشاشة العريضة لا تعني محتوى أعرض بلا حد: سطر نص بعرض 1800 بكسل لا يُقرأ.
/// لكنها أيضاً لا تعني عموداً ضيقاً في الوسط — الصفحات على الشاشات الكبيرة
/// تُبنى بشبكات وأعمدة جانبية ([ResponsiveGrid] و[TwoPane]) ضمن [wide].
class ContentWidth {
  const ContentWidth._();

  /// النماذج وحقول الإدخال: أضيق شيء، فالعين تتبع عموداً واحداً.
  static const form = 460.0;

  /// القوائم البسيطة — عمود واحد مقروء.
  static const standard = 720.0;

  /// صفحات اللوحة (الرئيسية، القناة، الإعدادات): شبكات وأعمدة جانبية.
  static const wide = 1180.0;
}

/// نقاط الانكسار.
class Breakpoints {
  const Breakpoints._();

  /// فوقها تتّسع الشاشة لعمودين من حقول الإجابة.
  static const twoColumns = 700.0;

  /// من هنا تابلت: شريط تنقّل جانبي بالأيقونات بدل الشريط السفلي.
  static const tablet = 600.0;

  /// من هنا شاشة كبيرة: شريط جانبي كامل كلوحة الإدارة.
  static const desktop = 1024.0;
}

enum FormFactor { phone, tablet, desktop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// هل تتّسع الشاشة لعمودين جنباً إلى جنب؟
  bool get isWide => screenWidth >= Breakpoints.twoColumns;

  FormFactor get formFactor => screenWidth >= Breakpoints.desktop
      ? FormFactor.desktop
      : screenWidth >= Breakpoints.tablet
      ? FormFactor.tablet
      : FormFactor.phone;

  bool get isPhone => formFactor == FormFactor.phone;

  bool get isDesktop => formFactor == FormFactor.desktop;

  /// الحشوة الجانبية التي توسّط محتوى بعرض [maxWidth] داخل الشاشة.
  ///
  /// نحسبها حشوةً بدل لفّ القائمة بـ ConstrainedBox: هكذا يبقى شريط التمرير
  /// على حافة الشاشة وتُلتقط إيماءة التمرير من أي مكان، لا من العمود الأوسط
  /// وحده.
  double sideGutter({
    double maxWidth = ContentWidth.standard,
    double minimum = 20,
  }) {
    final free = screenWidth - maxWidth;

    return free > minimum * 2 ? free / 2 : minimum;
  }

  /// حشوة محتوى موسّطة بلا إضافة شريط التنقّل.
  ///
  /// لما يوجد تذييل ثابت أسفل الشاشة (زر ستوب، زر ابدأ) فهو من يحجز مساحة
  /// الشريط؛ إضافتها هنا أيضاً تترك فجوة فارغة فوق التذييل.
  EdgeInsets contentPadding({
    double top = 20,
    double bottom = 20,
    double minHorizontal = 20,
    double maxWidth = ContentWidth.standard,
  }) {
    final side = sideGutter(maxWidth: maxWidth, minimum: minHorizontal);

    return EdgeInsets.fromLTRB(side, top, side, bottom);
  }
}

/// يوسّط طفله ويحدّ عرضه — لما ليس قائمةً قابلة للتمرير.
class ContentShell extends StatelessWidget {
  const ContentShell({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.standard,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// شبكة بطاقات: عدد الأعمدة من العرض المتاح فعلاً لا من عرض الشاشة.
///
/// العرض المتاح هو ما يهم: الشبكة نفسها داخل عمود جانبي تصير عموداً واحداً،
/// وعلى شاشة كبيرة بلا شريط جانبي تصير ثلاثة. وبطاقات الصف الواحد بارتفاع
/// واحد ([equalHeight]) كجداول لوحة الإدارة — صف متعرّج يبدو خطأً.
///
/// تنبيه: مع [equalHeight] لا يصح أن تحتوي البطاقات على LayoutBuilder
/// (لا يدعم قياس الارتفاع الذاتي).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.maxColumns = 3,
    this.spacing = 16,
    this.equalHeight = true,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final bool equalHeight;

  static int columnsFor(
    double width, {
    double minItemWidth = 280,
    int maxColumns = 3,
    double spacing = 16,
  }) => ((width + spacing) / (minItemWidth + spacing)).floor().clamp(
    1,
    maxColumns,
  );

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minItemWidth: minItemWidth,
          maxColumns: maxColumns,
          spacing: spacing,
        );

        final rows = <Widget>[];

        for (var start = 0; start < children.length; start += columns) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));

          if (columns == 1) {
            rows.add(children[start]);

            continue;
          }

          final row = Row(
            crossAxisAlignment: equalHeight
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              for (var offset = 0; offset < columns; offset++) ...[
                if (offset > 0) SizedBox(width: spacing),
                // خانة فارغة تحفظ عرض الأعمدة حين لا يكتمل الصف الأخير.
                Expanded(
                  child: start + offset < children.length
                      ? children[start + offset]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          );

          rows.add(equalHeight ? IntrinsicHeight(child: row) : row);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// محتوى رئيسي وعمود جانبي — كصفحات لوحة الإدارة.
///
/// على العرض الضيق يتكدّسان عموداً واحداً، ولصاحب الصفحة أن يختار أيهما أولاً
/// ([sideFirstWhenStacked]): في الإعدادات مثلاً البروفايل قبل الثيمات.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 340,
    this.breakpoint = 860,
    this.spacing = 20,
    this.sideFirstWhenStacked = false,
  });

  final Widget main;
  final Widget side;
  final double sideWidth;
  final double breakpoint;
  final double spacing;
  final bool sideFirstWhenStacked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        final gap = SizedBox(height: spacing);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sideFirstWhenStacked
              ? [side, gap, main]
              : [main, gap, side],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: main),
          SizedBox(width: spacing),
          SizedBox(width: sideWidth, child: side),
        ],
      );
    },
  );
}

/// يرتّب العناصر في عمود واحد على الجوال وعمودين على الشاشة العريضة.
///
/// يُستخدم لحقول الإجابة: ستة حقول في عمود واحد على شاشة عريضة تعني تمريراً
/// أثناء سباق مع المؤقّت — وهذا يكلّف اللاعب جولة.
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.children,
    this.spacing = 12,
    this.forceSingle = false,
  });

  final List<Widget> children;
  final double spacing;
  final bool forceSingle;

  @override
  Widget build(BuildContext context) {
    if (forceSingle || !context.isWide || children.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children) ...[child, SizedBox(height: spacing)],
        ],
      );
    }

    final rows = <Widget>[];

    for (var index = 0; index < children.length; index += 2) {
      final second = index + 1 < children.length ? children[index + 1] : null;

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[index]),
            SizedBox(width: spacing),
            // فراغ مطابق حين يكون العدد فردياً: يبقى العمودان بعرض واحد
            // فلا يقفز آخر حقل ليملأ السطر.
            Expanded(child: second ?? const SizedBox.shrink()),
          ],
        ),
      );
      rows.add(SizedBox(height: spacing));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
