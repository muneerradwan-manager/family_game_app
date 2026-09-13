import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../model/hadaf_models.dart';

/// لوحة الترتيب: بجانب السباق، بين الجولات، وفي النهاية.
///
/// بطاقة واحدة بصفوف مفصولة بخط كجداول لوحة الإدارة — بطاقة لكل لاعب في
/// عمود جانبي ضيّق تأكل المساحة وتدفع آخر اللاعبين خارج الشاشة.
class StandingsView extends StatelessWidget {
  const StandingsView({
    super.key,
    required this.standings,
    required this.viewerId,
    this.animate = true,
    this.title,
    this.myRisksLeft,
  });

  final List<Standing> standings;
  final String viewerId;

  /// الرقم يرتفع بحركة بدل أن يقفز — أثناء اللعب فقط، لا في شاشة النتيجة
  /// حيث يُعاد بناء القائمة مع كل تمرير.
  ///
  /// وهو أيضاً ما يفرّق اللوحة الحيّة عن النهائية: الحيّة تعرض السلسلة
  /// الجارية، والنهائية أفضل سلسلة في اللعبة.
  final bool animate;

  final String? title;

  /// ⚡ الباقية لي — السيرفر لا يكشف مراهنات غيري، فتظهر في سطري وحده.
  final int? myRisksLeft;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: title,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: standings.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'لسا ما في نقاط',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < standings.length; index++) ...[
                  if (index > 0) const Divider(indent: 14, endIndent: 14),
                  _StandingRow(
                    index: index,
                    standing: standings[index],
                    mine: standings[index].userId == viewerId,
                    animate: animate,
                    risksLeft: standings[index].userId == viewerId
                        ? myRisksLeft
                        : null,
                  ),
                ],
              ],
            ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.index,
    required this.standing,
    required this.mine,
    required this.animate,
    required this.risksLeft,
  });

  final int index;
  final Standing standing;
  final bool mine;
  final bool animate;
  final int? risksLeft;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final streak = animate ? standing.streak : standing.bestStreak;

    final scoreStyle = TextStyle(
      fontFamily: AppTheme.displayFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: palette.textPrimary,
    );

    return Container(
      color: mine ? palette.primary.withValues(alpha: 0.07) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 30, child: _RankMark(index: index)),
          const SizedBox(width: 8),
          PlayerAvatar(
            username: standing.username,
            photoUrl: standing.photoUrl,
            avatarId: standing.avatarId,
            size: 36,
            dimmed: standing.hasLeft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  [
                    '${standing.correctCount} صحيحة',
                    if (streak >= 3) '🔥 $streak',
                    if (risksLeft != null) '⚡ باقي $risksLeft',
                    if (standing.hasLeft) 'طلع',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (animate)
            AnimatedScore(
              standing.total,
              duration: const Duration(milliseconds: 900),
              style: scoreStyle,
            )
          else
            Text('${standing.total}', style: scoreStyle),
        ],
      ),
    );
  }
}

class _RankMark extends StatelessWidget {
  const _RankMark({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (index < 3) {
      return Text(
        const ['🥇', '🥈', '🥉'][index],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19),
      );
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontFamily: AppTheme.displayFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.textMuted,
        ),
      ),
    );
  }
}
