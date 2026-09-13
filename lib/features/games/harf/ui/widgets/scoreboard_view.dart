import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../model/harf_models.dart';

/// لوحة النقاط بعد كل جولة: الأرقام ترتفع بحركة، ثم الجولة التالية تلقائياً.
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

    return ListView(
      padding: context.contentPadding(top: 18, bottom: 24),
      children: [
        for (var index = 0; index < standings.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StandingRow(
              rank: index + 1,
              standing: standings[index],
              gained: round.roundScores[standings[index].userId],
              columns: snapshot.config.columns,
              labels: snapshot.config,
            ),
          ),
        const SizedBox(height: 10),
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
    required this.columns,
    required this.labels,
  });

  final int rank;
  final Standing standing;
  final RoundScore? gained;
  final List<String> columns;
  final HarfConfig labels;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final delta = gained?.total ?? 0;

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
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
                  child: Text(
                    delta > 0 ? '+$delta' : '$delta',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: delta > 0 ? palette.secondary : palette.accent,
                    ),
                  ),
                ),
              // الرقم يرتفع بحركة: النقاط تُحسّ لا تُقرأ فقط.
              AnimatedScore(
                standing.total,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          if (gained != null &&
              (gained!.stopBonus != 0 || gained!.penalties != 0)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 26),
                if (gained!.stopBonus > 0)
                  const InfoChip('بونص ستوب +10', color: Color(0xFF2E7D32)),
                if (gained!.stopBonus < 0)
                  InfoChip('عقوبة ستوب −10', color: palette.accent),
                if (gained!.penalties != 0) ...[
                  const SizedBox(width: 8),
                  InfoChip(
                    'اعتراض فاشل ${gained!.penalties}',
                    color: palette.accent,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
