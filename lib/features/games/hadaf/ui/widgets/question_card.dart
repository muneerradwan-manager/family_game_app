import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../cubit/hadaf_game_cubit.dart';
import '../../model/hadaf_models.dart';

/// السؤال وخياراته الأربعة — قلب السباق.
///
/// الخيارات أزرار كبيرة متساوية: في لعبة تُحسم بالمللي ثانية، زرٌّ صغير أو
/// غير متساوٍ مع أخيه يُعطي ميزةً لا علاقة لها بالذكاء.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.round});

  final HadafRound round;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
    final palette = context.palette;
    final question = round.question;

    if (question == null || question.isTeaser) {
      return const AppLoader(message: 'عم يجهّز السؤال...');
    }

    final revealed = round.phase.isRevealed;
    final locked = round.hasAnswered || !cubit.amRacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InfoChip(
              '${question.categoryEmoji ?? ''} ${question.categoryLabel ?? ''}',
            ),
            const SizedBox(width: 8),
            InfoChip(
              question.difficultyLabel,
              color: switch (question.difficulty) {
                'easy' => const Color(0xFF2E7D32),
                'hard' => palette.accent,
                _ => palette.secondary,
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Text(
            question.prompt!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              height: 1.5,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // شبكة 2×2: كل الخيارات في مرمى الإبهام بلا تمرير.
        for (var row = 0; row < (question.choices.length / 2).ceil(); row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (var column = 0; column < 2; column++)
                  if (row * 2 + column < question.choices.length) ...[
                    if (column == 1) const SizedBox(width: 12),
                    Expanded(
                      child: _ChoiceButton(
                        label: question.choices[row * 2 + column],
                        index: row * 2 + column,
                        myChoice: round.myChoice,
                        answerIndex: revealed ? round.answerIndex : null,
                        armed: state.riskArmed,
                        onTap: locked
                            ? null
                            : () => cubit.answer(row * 2 + column),
                      ),
                    ),
                  ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        if (!revealed) _RaceStatus(round: round, locked: locked),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.index,
    required this.myChoice,
    required this.answerIndex,
    required this.armed,
    required this.onTap,
  });

  final String label;
  final int index;
  final int? myChoice;

  /// غير null بعد الكشف فقط.
  final int? answerIndex;

  final bool armed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mine = myChoice == index;
    final revealed = answerIndex != null;
    final isAnswer = revealed && answerIndex == index;
    final wrongPick = revealed && mine && !isAnswer;

    final (Color border, Color fill) = switch (true) {
      _ when isAnswer => (
        const Color(0xFF2E7D32),
        const Color(0xFF2E7D32).withValues(alpha: 0.16),
      ),
      _ when wrongPick => (
        palette.accent,
        palette.accent.withValues(alpha: 0.14),
      ),
      _ when mine => (palette.primary, palette.primary.withValues(alpha: 0.14)),
      _ when armed && onTap != null => (
        palette.accent,
        palette.accent.withValues(alpha: 0.06),
      ),
      _ => (palette.outline, palette.surface),
    };

    return Opacity(
      // بعد الكشف تبهت الخيارات التي لا تعني أحداً.
      opacity: revealed && !isAnswer && !mine ? 0.45 : 1,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 74),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: border,
                width: isAnswer || wrongPick || mine ? 2.2 : 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (isAnswer) ...[
                  const SizedBox(width: 8),
                  const Text('✅', style: TextStyle(fontSize: 17)),
                ] else if (wrongPick) ...[
                  const SizedBox(width: 8),
                  const Text('❌', style: TextStyle(fontSize: 17)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// من أجاب — لا من أصاب. الثاني يكشف الجواب لمن ما زال يفكّر.
class _RaceStatus extends StatelessWidget {
  const _RaceStatus({required this.round, required this.locked});

  final HadafRound round;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        InfoChip(
          'جاوب ${round.answeredCount} من ${round.activeCount}',
          icon: Icons.people_outline,
        ),
        if (locked && round.hasAnswered) ...[
          const SizedBox(height: 10),
          Text(
            round.myRisk
                ? '⚡ راهنت! عم ننطر الباقيين...'
                : 'أرسلت إجابتك — عم ننطر الباقيين',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
