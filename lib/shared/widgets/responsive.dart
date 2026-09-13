import 'package:flutter/material.dart';

/// أقصى عرض للمحتوى حسب نوعه.
///
/// الشاشة العريضة لا تعني محتوى أعرض: سطر نص بعرض 1800 بكسل لا يُقرأ، وحقل
/// إدخال بهذا العرض يبدو خطأً برمجياً. نحدّ العرض ونوسّط، فيبقى التصميم هو
/// نفسه على الجوال ويصير محتملاً على الشاشات الكبيرة.
class ContentWidth {
  const ContentWidth._();

  /// النماذج وحقول الإدخال: أضيق شيء، فالعين تتبع عموداً واحداً.
  static const form = 460.0;

  /// القوائم والبطاقات — العرض الافتراضي.
  ///
  /// 720 لا أكثر حتى للجداول: صفوف "التسمية · القيمة" تتحوّل عند عرض أكبر إلى
  /// فراغ بين العمودين لا إلى معلومة إضافية.
  static const standard = 720.0;
}

/// نقاط الانكسار.
class Breakpoints {
  const Breakpoints._();

  /// فوقها تتّسع الشاشة لعمودين من حقول الإجابة.
  static const twoColumns = 700.0;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// هل تتّسع الشاشة لعمودين جنباً إلى جنب؟
  bool get isWide => screenWidth >= Breakpoints.twoColumns;

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
