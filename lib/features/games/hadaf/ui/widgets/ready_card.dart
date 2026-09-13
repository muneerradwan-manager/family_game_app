import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../model/hadaf_models.dart';
import 'question_card.dart' show hadafDifficultyColor;

/// العدّ التنازلي قبل السؤال.
///
/// ليست زينة: بدونها يرى من فتح الشاشة أولاً السؤالَ قبل غيره بجزء من
/// الثانية، وفي سباق يُحسم بالمللي ثانية هذا فارق حاسم. السيرفر لا يرسل نصّ
/// السؤال أصلاً في هذه المرحلة — المجموعة والصعوبة فقط.
///
/// الدائرة المتدرّجة هي اللحظة الوحيدة الملوّنة بالكامل في اللعبة: هي «صفّارة
/// الانطلاق»، والباقي بطاقات هادئة.
class ReadyCard extends StatelessWidget {
  const ReadyCard({super.key, required this.round, required this.clockSkewMs});

  final HadafRound round;
  final int clockSkewMs;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final question = round.question;

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'جولة ${round.number}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 22),
          PhaseCountdown(
            key: ValueKey('ready-${round.number}-${round.deadline}'),
            deadline: round.deadline,
            clockSkewMs: clockSkewMs,
            totalSeconds: 4,
            builder: (context, remaining) => Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: palette.headerGradient,
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.30),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                remaining <= 0 ? '🎯' : '$remaining',
                style: const TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  color: Colors.white,
                  fontSize: 62,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'استعدّوا!',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (question != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                InfoChip(
                  '${question.categoryEmoji ?? ''} ${question.categoryLabel ?? ''}',
                ),
                InfoChip(
                  question.difficultyLabel,
                  color: hadafDifficultyColor(palette, question.difficulty),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            'الكل بينطلق بنفس اللحظة',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
