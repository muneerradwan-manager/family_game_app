import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../model/hadaf_models.dart';

/// كشف الجولة: من سبق، ومن أصاب، وكم أخذ كلٌّ منهم.
class RevealCard extends StatelessWidget {
  const RevealCard({super.key, required this.round, required this.viewerId});

  final HadafRound round;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mine = round.rows.where((row) => row.userId == viewerId);
    final myRow = mine.isEmpty ? null : mine.first;
    final answer = round.answerIndex != null && round.question != null
        ? round.question!.choices.elementAtOrNull(round.answerIndex!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (myRow != null) _MyVerdict(row: myRow),
        const SizedBox(height: 18),
        SectionCard(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
          child: Column(
            children: [
              Text(
                'الجواب الصحيح',
                style: TextStyle(color: palette.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                answer ?? '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              if (round.explanation != null) ...[
                const SizedBox(height: 10),
                Text(
                  round.explanation!,
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
        ),
        const SizedBox(height: 22),
        const SectionTitle('مين سبق'),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final row in round.rows)
                ListTile(
                  dense: true,
                  leading: _RankBadge(row: row),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.username,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: row.userId == viewerId
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (row.usedRisk) ...[
                        const SizedBox(width: 6),
                        const Text('⚡', style: TextStyle(fontSize: 14)),
                      ],
                      if (row.streak >= 3) ...[
                        const SizedBox(width: 4),
                        Text(
                          '🔥${row.streak}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    row.points > 0 ? '+${row.points}' : '${row.points}',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: switch (true) {
                        _ when row.points > 0 => const Color(0xFF2E7D32),
                        _ when row.points < 0 => palette.accent,
                        _ => palette.textMuted,
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyVerdict extends StatelessWidget {
  const _MyVerdict({required this.row});

  final RevealRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = row.correct ? const Color(0xFF2E7D32) : palette.accent;

    return Column(
      children: [
        Text(switch (true) {
          _ when row.correct && row.rank == 1 => '🥇',
          _ when row.correct => '✅',
          _ when row.choice == null => '⌛',
          _ => '❌',
        }, style: const TextStyle(fontSize: 48)),
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
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: tone,
          ),
        ),
        if (row.usedRisk) ...[
          const SizedBox(height: 6),
          InfoChip(
            row.correct ? '⚡ المراهنة ربحت — نقاط مضاعفة' : '⚡ المراهنة خسرت',
            color: tone,
          ),
        ],
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.row});

  final RevealRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (!row.correct) {
      return SizedBox(
        width: 30,
        child: Text(
          row.choice == null ? '⌛' : '❌',
          style: const TextStyle(fontSize: 17),
        ),
      );
    }

    return SizedBox(
      width: 30,
      child: Text(switch (row.rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '✅',
      }, style: TextStyle(fontSize: 18, color: palette.textMuted)),
    );
  }
}
