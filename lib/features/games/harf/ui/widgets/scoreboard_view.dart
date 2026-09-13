import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../model/harf_models.dart';
import 'harf_layout.dart';

/// لوحة النقاط بعد كل جولة: الأرقام ترتفع بحركة، ثم الجولة التالية تلقائياً.
///
/// جدول واحد بأسطر مفصولة لا بطاقة لكل لاعب — الترتيب يُقرأ من أعلى لأسفل
/// بلمحة، كجداول لوحة الإدارة.
class ScoreboardView extends StatelessWidget {
  const ScoreboardView({
    super.key,
    required this.snapshot,
    required this.round,
  });

  final HarfSnapshot snapshot;
  final HarfRound round;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final standings = snapshot.standings;

    return HarfPaneList(
      top: 18,
      children: [
        SectionCard(
          title: 'النقاط',
          subtitle: 'جولة ${round.number} من ${snapshot.totalRounds}',
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var index = 0; index < standings.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _StandingRow(
                  rank: index + 1,
                  standing: standings[index],
                  gained: round.roundScores[standings[index].userId],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            round.number >= snapshot.totalRounds
                ? 'آخر جولة — النتيجة النهائية جاي'
                : 'الجولة الجاية رح تبلّش لحالها...',
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.standing,
    required this.gained,
  });

  final int rank;
  final Standing standing;
  final RoundScore? gained;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final delta = gained?.total ?? 0;
    final hasNotes =
        gained != null && (gained!.stopBonus != 0 || gained!.penalties != 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: rank == 1 ? palette.primary : palette.textMuted,
                  ),
                ),
              ),
              PlayerAvatar(
                username: standing.username,
                photoUrl: standing.photoUrl,
                avatarId: standing.avatarId,
                size: 38,
                dimmed: standing.hasLeft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  standing.username,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (delta != 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: InfoChip(
                    delta > 0 ? '+$delta' : '$delta',
                    color: delta > 0 ? palette.success : palette.danger,
                  ),
                ),
              // الرقم يرتفع بحركة: النقاط تُحسّ لا تُقرأ فقط.
              AnimatedScore(
                standing.total,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          if (hasNotes) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 76),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (gained!.stopBonus > 0)
                    InfoChip('بونص ستوب +10', color: palette.success),
                  if (gained!.stopBonus < 0)
                    InfoChip('عقوبة ستوب −10', color: palette.accent),
                  if (gained!.penalties != 0)
                    InfoChip(
                      'اعتراض فاشل ${gained!.penalties}',
                      color: palette.accent,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
