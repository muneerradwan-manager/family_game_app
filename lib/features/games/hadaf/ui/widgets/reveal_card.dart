import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../model/hadaf_models.dart';

/// كشف الجولة: من سبق، ومن أصاب، وكم أخذ كلٌّ منهم.
class RevealCard extends StatelessWidget {
  const RevealCard({super.key, required this.round, required this.viewerId});

  final HadafRound round;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final mine = round.rows.where((row) => row.userId == viewerId);
    final myRow = mine.isEmpty ? null : mine.first;
    final answer = round.answerIndex != null && round.question != null
        ? round.question!.choices.elementAtOrNull(round.answerIndex!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // حكمي والجواب الصحيح متجاوران حين يتّسع العرض: هما ما يُقرأ أولاً.
        ResponsiveGrid(
          minItemWidth: 260,
          maxColumns: 2,
          spacing: 14,
          children: [
            if (myRow != null) _MyVerdict(row: myRow),
            _AnswerCard(answer: answer, explanation: round.explanation),
          ],
        ),
        if (round.rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'مين سبق',
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < round.rows.length; index++) ...[
                  if (index > 0) const Divider(indent: 14, endIndent: 14),
                  _RevealRowTile(
                    row: round.rows[index],
                    mine: round.rows[index].userId == viewerId,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.explanation});

  final String? answer;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      color: palette.success.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InfoChip(
            'الجواب الصحيح',
            color: palette.success,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 10),
          Text(
            answer ?? '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
          ),
          if (explanation != null) ...[
            const SizedBox(height: 10),
            Text(
              explanation!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MyVerdict extends StatelessWidget {
  const _MyVerdict({required this.row});

  final RevealRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = row.correct ? palette.success : palette.danger;

    return SectionCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(switch (true) {
            _ when row.correct && row.rank == 1 => '🥇',
            _ when row.correct => '✅',
            _ when row.choice == null => '⌛',
            _ => '❌',
          }, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            switch (true) {
              _ when row.correct && row.rank == 1 => 'الأسرع! سبقت الكل',
              _ when row.correct => 'صح — المركز ${row.rank}',
              _ when row.choice == null => 'خلص الوقت',
              _ => 'غلط',
            },
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: row.choice == null && !row.correct
                  ? palette.textPrimary
                  : tone,
            ),
          ),
          if (row.usedRisk) ...[
            const SizedBox(height: 8),
            InfoChip(
              row.correct ? '⚡ المراهنة ربحت — نقاط مضاعفة' : '⚡ المراهنة خسرت',
              color: tone,
            ),
          ],
        ],
      ),
    );
  }
}

class _RevealRowTile extends StatelessWidget {
  const _RevealRowTile({required this.row, required this.mine});

  final RevealRow row;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      color: mine ? palette.primary.withValues(alpha: 0.07) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              row.correct
                  ? switch (row.rank) {
                      1 => '🥇',
                      2 => '🥈',
                      3 => '🥉',
                      _ => '✅',
                    }
                  : (row.choice == null ? '⌛' : '❌'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    row.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: mine ? FontWeight.w900 : FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (row.usedRisk) ...[
                  const SizedBox(width: 6),
                  InfoChip('⚡', color: palette.accent),
                ],
                if (row.streak >= 3) ...[
                  const SizedBox(width: 4),
                  InfoChip('🔥${row.streak}', color: palette.warning),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.points > 0 ? '+${row.points}' : '${row.points}',
            style: TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: switch (true) {
                _ when row.points > 0 => palette.success,
                _ when row.points < 0 => palette.danger,
                _ => palette.textMuted,
              },
            ),
          ),
        ],
      ),
    );
  }
}
