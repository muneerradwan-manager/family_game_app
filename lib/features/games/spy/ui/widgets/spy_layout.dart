import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/game_layout.dart';
import '../../../../../shared/widgets/responsive.dart';

/// جسم شاشات الجاسوس: [SessionBody] مع انتباه لشريط تنقّل النظام.
///
/// التذييل الثابت يحجز الشريط بنفسه، فما فوقه يجب ألا يحجزه مرة ثانية وإلا
/// ظهرت فجوة فارغة فوق الزر. وحين لا يوجد تذييل تبقى الحشوة لتصل القائمة
/// نفسها إلى ما فوق الشريط — لهذا نخفيها عمّا فوق التذييل وحده.
class SpyBody extends StatelessWidget {
  const SpyBody({super.key, required this.main, this.side, this.footer});

  final Widget main;
  final Widget? side;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    Widget above(Widget child) => footer == null
        ? child
        : MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          );

    return SessionBody(
      main: above(main),
      side: side == null ? null : above(side!),
      footer: footer,
    );
  }
}

/// مسرح المرحلة: قائمة قابلة للتمرير بمحتوى موسّط ومحدود العرض.
///
/// الهامش يُحسب من العرض المتاح فعلاً لا من عرض الشاشة: بجانب العمود
/// الجانبي يكون المسرح أضيق من الشاشة، وحساب الهامش من الشاشة يعصر المحتوى
/// في شريط نحيل وسط مساحة فارغة.
class SpyStage extends StatelessWidget {
  const SpyStage({
    super.key,
    required this.children,
    this.maxWidth = ContentWidth.form,
    this.top = 20,
    this.bottom = 24,
    this.centered = false,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;

  /// توسيط عمودي حين يكون المحتوى أقصر من الشاشة (بطاقة الدور).
  final bool centered;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gutter = context.isPhone ? 20.0 : 24.0;
      final free = constraints.maxWidth - maxWidth;
      final side = free > gutter * 2 ? free / 2 : gutter;
      final padding = EdgeInsets.fromLTRB(
        side,
        top,
        side,
        bottom + context.bottomInset,
      );

      if (!centered) {
        return ListView(padding: padding, children: children);
      }

      return SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
    },
  );
}
