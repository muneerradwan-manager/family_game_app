import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';
import 'responsive.dart';

/// رقم في شريط أرقام الجلسة (لاعبين · جولات · دقائق).
class SessionStat {
  const SessionStat(this.value, this.label, {this.icon});

  final String value;
  final String label;
  final IconData? icon;
}

/// رأس شاشات الجلسة (اللوبي والنتيجة وما شابه) بأسلوب لوحة الإدارة:
/// سطح أبيض بحدّ سفلي، علامة اللعبة، عنوان، أزرار، وشريط أرقام اختياري.
///
/// يحجز حشوة شريط الحالة بنفسه؛ فما تحته لا يضيفها مرة ثانية.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.emoji,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.stats = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final String? emoji;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final List<SessionStat> stats;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.outline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: context.contentPadding(
            top: 10,
            bottom: 14,
            minHorizontal: 16,
            maxWidth: ContentWidth.wide,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (showBack) AppBackButton(onPressed: onBack),
                  if (emoji != null) ...[
                    GradientMark(emoji: emoji, size: 42),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 14),
                StatStrip(stats: stats),
              ],
              if (bottom != null) ...[const SizedBox(height: 12), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

/// أرقام متجاورة في مربّعات هادئة.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});

  final List<SessionStat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Column(
                children: [
                  Text(
                    stats[index].value,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    stats[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// جسم الجلسة: محتوى رئيسي، وعمود جانبي على الشاشة العريضة، وتذييل ثابت.
///
/// العمود الجانبي هو ما يجعل الشاشة الكبيرة تصميماً لا جوالاً مكبّراً: لوحة
/// النقاط أو اللاعبين أو المحادثة تبقى ظاهرة بجانب اللعب بدل أن تُخفى خلف
/// تمرير. على الجوال لا يُرسم العمود — والشاشة تقرّر أين تضع محتواه
/// ([isSplit]).
class SessionBody extends StatelessWidget {
  const SessionBody({
    super.key,
    required this.main,
    this.side,
    this.footer,
    this.sideWidth = 360,
    this.breakpoint = splitBreakpoint,
  });

  final Widget main;
  final Widget? side;
  final Widget? footer;
  final double sideWidth;
  final double breakpoint;

  static const splitBreakpoint = 900.0;

  static bool isSplit(
    BuildContext context, {
    double breakpoint = splitBreakpoint,
  }) => MediaQuery.sizeOf(context).width >= breakpoint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final split = side != null && isSplit(context, breakpoint: breakpoint);

    return Column(
      children: [
        Expanded(
          child: split
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: main),
                    Container(
                      width: sideWidth,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: BorderDirectional(
                          start: BorderSide(color: palette.outline),
                        ),
                      ),
                      child: side,
                    ),
                  ],
                )
              : main,
        ),
        if (footer != null) SessionFooter(child: footer!),
      ],
    );
  }
}

/// تذييل ثابت (زر ابدأ، ستوب، كمان لعبة) — يحجز شريط تنقّل النظام دائماً.
class SessionFooter extends StatelessWidget {
  const SessionFooter({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.form,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: context.contentPadding(
            top: 12,
            bottom: 12,
            minHorizontal: 16,
            maxWidth: maxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// محتوى العمود الجانبي: قائمة قابلة للتمرير بعنوان اختياري.
class SidePanel extends StatelessWidget {
  const SidePanel({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + context.bottomInset),
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.palette.textMuted,
            ),
          ),
        ),
      ...children,
    ],
  );
}
