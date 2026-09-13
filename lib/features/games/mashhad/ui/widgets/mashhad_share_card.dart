import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../model/mashhad_models.dart';

/// بطاقة نتيجة المشهد المُعدّة للمشاركة كصورة.
///
/// مرسومة بمقاس ثابت لا بمقاس الشاشة، ولها ألوانها الصريحة لأنها تُرسم خارج
/// شجرة الواجهة حيث لا يوجد Theme.
class MashhadShareCard extends StatelessWidget {
  const MashhadShareCard({
    super.key,
    required this.result,
    required this.palette,
    required this.channelName,
  });

  static const width = 900.0;

  final MashhadResult result;
  final AppPalette palette;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    final scores = result.finalScores;

    return Container(
      width: width,
      color: palette.background,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.headerGradient,
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                const Text('🎬', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                const Text(
                  'لعبة المشهد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  channelName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 22,
                  ),
                ),
                if (result.winner != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'بطل السهرة: ${result.winner!.username}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (result.awards.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'جوائز السهرة',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            for (final award in result.awards)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(award.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        award.label,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Text(
                      award.winners.join(' · '),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 28),
          Text(
            'اللوحة النهائية',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < scores.length; index++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              decoration: BoxDecoration(
                color: index == 0
                    ? palette.primary.withValues(alpha: 0.10)
                    : palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: index == 0 ? palette.primary : palette.outline,
                  width: index == 0 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      switch (index) {
                        0 => '🥇',
                        1 => '🥈',
                        2 => '🥉',
                        _ => '${index + 1}',
                      },
                      style: TextStyle(
                        fontSize: index < 3 ? 32 : 24,
                        fontWeight: FontWeight.w900,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scores[index].username,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${scores[index].goalsAchieved} هدف · '
                          '${scores[index].messageCount} رسالة',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${scores[index].total}',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            '${result.scenesPlayed} مشاهد · ${scores.length} لاعبين',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
