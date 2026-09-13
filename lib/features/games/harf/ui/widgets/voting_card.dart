import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/skeleton.dart';
import '../../cubit/harf_game_cubit.dart';
import 'harf_layout.dart';

/// التصويت على اعتراض واحد — واحد في كل مرة لا دفعة واحدة.
///
/// طرفا الاعتراض (والشركاء فيه) يريان الشاشة بلا أزرار: كلاهما صاحب مصلحة.
/// والتعادل أو صفر أصوات = قبول الإجابة، فالشك لمصلحة اللاعب.
class VotingCard extends StatelessWidget {
  const VotingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HarfGameCubit>();
    final state = context.watch<HarfGameCubit>().state;
    final objection = state.round?.objection;
    final palette = context.palette;

    if (objection == null) {
      // هيكل بطاقة التصويت نفسها: الاعتراض يصل خلال لحظة ويأخذ مكانها.
      return const HarfPaneCenter(child: FormCardSkeleton(fields: 2));
    }

    final canVote =
        !objection.isParty &&
        !objection.hasVoted &&
        state.snapshot!.me.isPlayer;

    return HarfPaneCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (objection.total > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InfoChip(
                'اعتراض ${objection.index} من ${objection.total}',
                color: palette.warning,
                icon: Icons.gavel_outlined,
              ),
            ),
          SectionCard(
            title: 'اعتراض من ${objection.byUsername}',
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: palette.textPrimary,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(text: '${objection.targetUsername} كتب بخانة '),
                      TextSpan(
                        text: objection.columnLabel,
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
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    objection.answer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'هي إجابة صحيحة؟',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (canVote)
                  Row(
                    children: [
                      Expanded(
                        child: _VoteButton(
                          label: 'صح',
                          emoji: '✅',
                          color: palette.success,
                          onTap: () => cubit.castVote(answerIsValid: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _VoteButton(
                          label: 'خطأ',
                          emoji: '❌',
                          color: palette.danger,
                          onTap: () => cubit.castVote(answerIsValid: false),
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
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Text(
                      objection.isParty
                          ? 'إنت طرف بهالاعتراض — عم ننطر تصويت الباقيين'
                          : objection.hasVoted
                          ? 'صوّتت — عم ننطر الباقيين'
                          : 'عم ننطر تصويت اللاعبين',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted, height: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
}
