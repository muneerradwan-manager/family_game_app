import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../model/hadaf_models.dart';

/// بطاقة نتيجة الهدف المُعدّة للمشاركة كصورة.
///
/// مرسومة بمقاس ثابت لا بمقاس الشاشة، ولها ألوانها الصريحة لأنها تُرسم خارج
/// شجرة الواجهة حيث لا يوجد Theme — لذلك لا تستعمل أي عنصر مشترك يقرأ
/// `context.palette` (كـ GradientMark أو SectionCard)، بل ترسم مثيله بنفسها.
class HadafShareCard extends StatelessWidget {
  const HadafShareCard({
    super.key,
    required this.result,
    required this.palette,
    required this.channelName,
  });

  static const width = 900.0;

  final HadafResult result;
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
              color: palette.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.outline, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: palette.headerGradient,
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎯', style: TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 16),
                Text(
                  'لعبة الهدف',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  channelName,
                  style: TextStyle(color: palette.textMuted, fontSize: 22),
                ),
                if (result.winner != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'الفائز: ${result.winner!.username}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                if (result.decidedByTiebreak) ...[
                  const SizedBox(height: 12),
                  Text(
                    'حُسمت بجولة الحسم 🔥',
                    style: TextStyle(color: palette.accent, fontSize: 20),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < scores.length; index++)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: index == 0
                    ? Color.alphaBlend(
                        palette.primary.withValues(alpha: 0.08),
                        palette.surface,
                      )
                    : palette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: index == 0 ? palette.primary : palette.outline,
                  width: 2,
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
                        fontFamily: index < 3
                            ? null
                            : AppTheme.displayFontFamily,
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
                          [
                            '${scores[index].correctCount} صحيحة',
                            if (scores[index].bestStreak >= 3)
                              '🔥 ${scores[index].bestStreak}',
                          ].join(' · '),
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
                      fontFamily: AppTheme.displayFontFamily,
                      color: palette.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            '${result.roundsPlayed} تحدّيات · ${scores.length} لاعبين',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
