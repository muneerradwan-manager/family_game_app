import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/game_layout.dart';
import '../../../../../shared/widgets/responsive.dart';

/// قائمة المحتوى الرئيسي في شاشات الهدف.
///
/// الحشوة الجانبية تُحسب من العرض المتاح فعلاً لا من عرض الشاشة: بجانب العمود
/// الجانبي يضيق المحتوى الرئيسي، و`listPadding` المبنية على عرض الشاشة كانت
/// ستوسّطه كأن العمود غير موجود فتنزاح البطاقات تحته.
class HadafScroll extends StatelessWidget {
  const HadafScroll({
    super.key,
    required this.children,
    this.maxWidth = ContentWidth.standard,
    this.top = 20,
    this.bottom = 24,
    this.reserveInset = true,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;

  /// false حين يوجد تذييل ثابت: هو من يحجز شريط التنقّل، وحجزه هنا أيضاً
  /// يترك فجوة فارغة فوقه.
  final bool reserveInset;

  @override
  Widget build(BuildContext context) {
    final gutter = context.isPhone ? 16.0 : 24.0;
    final inset = reserveInset ? context.bottomInset : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final free = constraints.maxWidth - maxWidth;
        final side = free > gutter * 2 ? free / 2 : gutter;

        return ListView(
          padding: EdgeInsets.fromLTRB(side, top, side, bottom + inset),
          children: children,
        );
      },
    );
  }
}

/// محتوى في منتصف المساحة عمودياً — ويتمرّر إن لم يتّسع (جوال بالعرض).
class HadafCentered extends StatelessWidget {
  const HadafCentered({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.form,
    this.reserveInset = true,
  });

  final Widget child;
  final double maxWidth;
  final bool reserveInset;

  @override
  Widget build(BuildContext context) {
    final inset = reserveInset ? context.bottomInset : 0.0;
    const vertical = 20.0;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, vertical, 16, vertical + inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(
              0,
              constraints.maxHeight - vertical * 2 - inset,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// العمود الجانبي فوق تذييل ثابت.
///
/// التذييل يمتد تحت العمودين ويحجز شريط التنقّل، فنخفي الحشوة السفلية عن
/// العمود وإلا حجزها `SidePanel` مرة ثانية.
class HadafSide extends StatelessWidget {
  const HadafSide({
    super.key,
    required this.children,
    this.aboveFooter = false,
  });

  final List<Widget> children;
  final bool aboveFooter;

  @override
  Widget build(BuildContext context) {
    final panel = SidePanel(children: children);

    if (!aboveFooter) return panel;

    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: panel,
    );
  }
}
