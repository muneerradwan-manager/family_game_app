import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// التصويت على اعتراض واحد — واحد في كل مرة لا دفعة واحدة.
///
/// طرفا الاعتراض (والشركاء فيه) يريان الشاشة بلا أزرار: كلاهما صاحب مصلحة.
/// والتعادل أو صفر أصوات = الادّعاء يمرّ، فالشك لمصلحة المُدّعي.
class VerdictCard extends StatelessWidget {
  const VerdictCard({super.key, required this.challenge});

  final ChallengeView challenge;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '⚖️ اعتراض',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            children: [
              Text(
                '${challenge.byUsername} معترض على ادّعاء',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: palette.textPrimary,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(text: '${challenge.targetUsername} '),
                    TextSpan(
                      text: '(${challenge.roleName})',
                      style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: ' قال إنه حقّق '),
                    TextSpan(
                      text: challenge.kindLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const TextSpan(text: ':'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  challenge.goal,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'فعلاً حقّقه؟',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (cubit.canVote)
                Row(
                  children: [
                    Expanded(
                      child: _VoteButton(
                        label: 'حقّقه',
                        emoji: '✅',
                        color: const Color(0xFF2E7D32),
                        onTap: () => cubit.vote(achieved: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VoteButton(
                        label: 'لأ',
                        emoji: '❌',
                        color: palette.accent,
                        onTap: () => cubit.vote(achieved: false),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    challenge.isParty
                        ? 'إنت طرف بهالاعتراض — عم ننطر تصويت الباقيين'
                        : challenge.hasVoted
                        ? 'صوّتت — عم ننطر الباقيين'
                        : 'عم ننطر تصويت اللاعبين',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textMuted, height: 1.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'التعادل أو صفر أصوات = الادّعاء بيمرّ.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
