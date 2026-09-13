import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/game_layout.dart';
import '../../../../../shared/widgets/responsive.dart';

/// جسم جلسة الحروف: [SessionBody] مع ضبط حشوة شريط التنقّل.
///
/// حين يوجد تذييل فهو من يحجز ارتفاع شريط النظام، فنخفي الحشوة عمّا فوقه —
/// وإلا أضافتها القوائم مرة ثانية وبقيت فجوة فارغة فوق التذييل. وبلا تذييل
/// تبقى الحشوة، فتتخطّى القوائم الشريط بنفسها.
class HarfSessionBody extends StatelessWidget {
  const HarfSessionBody({
    super.key,
    required this.main,
    this.side,
    this.footer,
  });

  final Widget main;
  final Widget? side;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    Widget guard(Widget child) => footer == null
        ? child
        : MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          );

    return SessionBody(
      main: guard(main),
      side: side == null ? null : guard(side!),
      footer: footer,
    );
  }
}

/// الهامش الجانبي من عرض الجزء نفسه لا من عرض الشاشة.
///
/// المحتوى الرئيسي بجانب عمود جانبي عرضه 360: حساب الهامش من الشاشة كلها
/// يوسّطه في مكان خاطئ ويضيّقه بلا داعٍ.
double _gutter(double width, double maxWidth) {
  final minimum = width < Breakpoints.tablet ? 16.0 : 24.0;
  final free = width - maxWidth;

  return free > minimum * 2 ? free / 2 : minimum;
}

/// قائمة قابلة للتمرير داخل جزء من جسم الجلسة، تتخطّى شريط التنقّل.
class HarfPaneList extends StatelessWidget {
  const HarfPaneList({
    super.key,
    required this.children,
    this.maxWidth = ContentWidth.standard,
    this.top = 20,
    this.bottom = 24,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = _gutter(constraints.maxWidth, maxWidth);

      return ListView(
        padding: EdgeInsets.fromLTRB(
          side,
          top,
          side,
          bottom + context.bottomInset,
        ),
        children: children,
      );
    },
  );
}

/// محتوى قصير في منتصف الجزء — ويُمرَّر إن ضاق الارتفاع.
///
/// جوال بالعرض أو لوحة مفاتيح مفتوحة تجعل عموداً «في المنتصف» أطول من
/// الشاشة؛ التمرير أفضل من خطوط الطفح الصفراء.
class HarfPaneCenter extends StatelessWidget {
  const HarfPaneCenter({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.form,
    this.vertical = 24,
  });

  final Widget child;
  final double maxWidth;
  final double vertical;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = _gutter(constraints.maxWidth, maxWidth);
      final bottom = vertical + context.bottomInset;

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(side, vertical, side, bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - vertical - bottom).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Center(child: child),
        ),
      );
    },
  );
}

/// سطر «اسم · قيمة» في بطاقات التفاصيل الجانبية — كجداول لوحة الإدارة.
class HarfDetailRow extends StatelessWidget {
  const HarfDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: palette.textMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.textMuted, fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
