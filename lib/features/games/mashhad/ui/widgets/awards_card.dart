import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../auth/model/app_user.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// جوائز نهاية المباراة — تصويت حر على لحظات المباراة المميزة.
///
/// النقاط تقيس من حقّق أهدافه؛ هذه تقيس من صنع المتعة. وكثيراً ما يكونان
/// شخصين مختلفين — ومن حقّ الثاني أن يُذكر.
class AwardsCard extends StatelessWidget {
  const AwardsCard({super.key, required this.round});

  final MashhadRound round;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final palette = context.palette;
    final candidates = cubit.awardCandidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '🏅 جوائز السهرة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cubit.amPlaying
              ? 'صوّت لكل جائزة — وكل جائزة بتزيد نقاط صاحبها.'
              : 'اللاعبين عم يصوّتوا على الجوائز.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.5),
        ),
        const SizedBox(height: 22),
        for (final award in round.awards) ...[
          _AwardBlock(
            award: award,
            candidates: candidates,
            picked: round.myAwardVotes[award.key],
            locked: !cubit.amPlaying,
            onPick: (userId) =>
                cubit.voteAward(awardKey: award.key, targetUserId: userId),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _AwardBlock extends StatelessWidget {
  const _AwardBlock({
    required this.award,
    required this.candidates,
    required this.picked,
    required this.locked,
    required this.onPick,
  });

  final AwardKind award;
  final List<MashhadPlayer> candidates;
  final String? picked;
  final bool locked;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(award.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  award.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (picked != null)
                Icon(Icons.check_circle, color: palette.primary, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final player in candidates)
                _Candidate(
                  player: player,
                  selected: picked == player.id,
                  locked: locked || picked != null,
                  onTap: () => onPick(player.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.player,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final MashhadPlayer player;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: locked && !selected ? 0.45 : 1,
      child: Material(
        color: selected
            ? palette.primary.withValues(alpha: 0.16)
            : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? palette.primary : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerAvatar(
                  username: player.username,
                  photoUrl: player.photoUrl,
                  avatarId: player.avatarId,
                  gender: Gender.parse(player.gender),
                  size: 26,
                ),
                const SizedBox(width: 7),
                Text(
                  player.username,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected ? palette.primary : palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
