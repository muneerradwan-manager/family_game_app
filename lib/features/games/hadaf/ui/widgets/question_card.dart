import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/hadaf_game_cubit.dart';
import '../../model/hadaf_models.dart';
import 'hadaf_skeletons.dart';

/// لون شارة الصعوبة — ألوان الحالة الثابتة، فالصعب أحمر في كل ثيم.
Color hadafDifficultyColor(AppPalette palette, String difficulty) =>
    switch (difficulty) {
      'easy' => palette.success,
      'hard' => palette.danger,
      _ => palette.warning,
    };

/// السؤال وخياراته الأربعة — قلب السباق.
///
/// الخيارات بطاقات كبيرة متساوية: في لعبة تُحسم بالمللي ثانية، زرٌّ صغير أو
/// غير متساوٍ مع أخيه يُعطي ميزةً لا علاقة لها بالذكاء.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.round});

  final HadafRound round;

  static const _letters = ['أ', 'ب', 'ج', 'د'];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
    final palette = context.palette;
    final question = round.question;

    if (question == null || question.isTeaser) return const QuestionSkeleton();

    final revealed = round.phase.isRevealed;
    final locked = round.hasAnswered || !cubit.amRacing;
    // من التابلت وأعلى: شبكة 2×2 فتبقى الخيارات كلها تحت السؤال بلا تمرير؛
    // على الجوال عمود واحد فيتّسع السطر لخيار طويل بخط كبير.
    final grid = context.screenWidth >= Breakpoints.tablet;

    Widget choice(int index) => _ChoiceOption(
      label: question.choices[index],
      letter: index < _letters.length ? _letters[index] : '${index + 1}',
      index: index,
      myChoice: round.myChoice,
      answerIndex: revealed ? round.answerIndex : null,
      armed: state.riskArmed,
      onTap: locked ? null : () => cubit.answer(index),
    );

    final count = question.choices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: [
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
              const SizedBox(height: 18),
              Text(
                question.prompt!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: grid ? 25 : 22,
                  height: 1.5,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (grid)
          for (var index = 0; index < count; index += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // ارتفاع واحد للخيارين في الصف: خيار أطول من أخيه يبدو هدفاً أكبر.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: choice(index)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: index + 1 < count
                          ? choice(index + 1)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            )
        else
          for (var index = 0; index < count; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: choice(index),
            ),
        const SizedBox(height: 8),
        if (!revealed) _RaceStatus(round: round, locked: locked),
      ],
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    required this.label,
    required this.letter,
    required this.index,
    required this.myChoice,
    required this.answerIndex,
    required this.armed,
    required this.onTap,
  });

  final String label;
  final String letter;
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
    final strong = isAnswer || wrongPick || mine;
    final radius = BorderRadius.circular(AppRadius.card);

    final (Color tone, Color fill) = switch (true) {
      _ when isAnswer => (
        palette.success,
        palette.success.withValues(alpha: 0.10),
      ),
      _ when wrongPick => (
        palette.danger,
        palette.danger.withValues(alpha: 0.08),
      ),
      _ when mine => (palette.primary, palette.primary.withValues(alpha: 0.08)),
      // ⚡ مفعّلة: كل الخيارات تلبس لون المخاطرة، فتُرى قبل الضغط لا بعده.
      _ when armed && onTap != null => (
        palette.accent,
        palette.accent.withValues(alpha: 0.05),
      ),
      _ => (palette.outline, palette.surface),
    };

    final trailing = switch (true) {
      _ when isAnswer => Icon(Icons.check_circle_rounded, color: tone),
      _ when wrongPick => Icon(Icons.cancel_rounded, color: tone),
      _ when mine => Icon(Icons.radio_button_checked_rounded, color: tone),
      _ => null,
    };

    return Opacity(
      // بعد الكشف تبهت الخيارات التي لا تعني أحداً.
      opacity: revealed && !isAnswer && !mine ? 0.45 : 1,
      child: Material(
        color: fill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tone, width: strong ? 2 : 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: strong ? tone : palette.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: strong ? Colors.white : palette.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
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
    final progress = round.activeCount == 0
        ? 0.0
        : (round.answeredCount / round.activeCount).clamp(0.0, 1.0);

    return Column(
      children: [
        InfoChip(
          'جاوب ${round.answeredCount} من ${round.activeCount}',
          icon: Icons.people_outline,
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 5),
          ),
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
