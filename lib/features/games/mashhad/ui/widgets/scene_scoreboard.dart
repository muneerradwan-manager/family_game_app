import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../model/mashhad_models.dart';

/// نقاط المشهد: من حقّق هدفه ومن لأ، وكم أخذ كلٌّ منهم.
class SceneScoreboard extends StatelessWidget {
  const SceneScoreboard({
    super.key,
    required this.scores,
    required this.standings,
    required this.viewerId,
  });

  final List<SceneScore> scores;
  final List<Standing> standings;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('نتيجة المشهد'),
        for (final score in scores)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              color: score.userId == viewerId
                  ? palette.primary.withValues(alpha: 0.07)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.mainAchieved ? '✅' : '❌',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                score.username,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '· ${score.roleName}',
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          score.goal,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        if (score.bonusAchieved ||
                            score.eventAchieved ||
                            score.penalties < 0) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (score.bonusAchieved)
                                const InfoChip('⭐ هدف إضافي'),
                              if (score.eventAchieved)
                                const InfoChip('⚡ استغل الحدث'),
                              if (score.penalties < 0)
                                InfoChip(
                                  'خصم ${score.penalties}',
                                  color: palette.accent,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    score.points >= 0 ? '+${score.points}' : '${score.points}',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: switch (true) {
                        _ when score.points > 0 => const Color(0xFF2E7D32),
                        _ when score.points < 0 => palette.accent,
                        _ => palette.textMuted,
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        const SectionTitle('الترتيب العام'),
        for (var index = 0; index < standings.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              color: standings[index].userId == viewerId
                  ? palette.primary.withValues(alpha: 0.07)
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      switch (index) {
                        0 => '🥇',
                        1 => '🥈',
                        2 => '🥉',
                        _ => '${index + 1}',
                      },
                      style: TextStyle(
                        fontSize: index < 3 ? 18 : 14,
                        fontWeight: FontWeight.w900,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  PlayerAvatar(
                    username: standings[index].username,
                    photoUrl: standings[index].photoUrl,
                    avatarId: standings[index].avatarId,
                    size: 34,
                    dimmed: standings[index].hasLeft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      standings[index].username,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedScore(
                    standings[index].total,
                    duration: const Duration(milliseconds: 900),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
