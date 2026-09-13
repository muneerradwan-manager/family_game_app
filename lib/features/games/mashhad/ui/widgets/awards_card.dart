import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../auth/model/app_user.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';
import 'mashhad_layout.dart';

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
    final candidates = cubit.awardCandidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhaseIntro(
          title: '🏅 جوائز السهرة',
          subtitle: cubit.amPlaying
              ? 'صوّت لكل جائزة — وكل جائزة بتزيد نقاط صاحبها.'
              : 'اللاعبين عم يصوّتوا على الجوائز.',
        ),
        const SizedBox(height: 20),
        // عمودان من التابلت: كل الجوائز في نظرة واحدة والوقت 35 ثانية.
        ResponsiveGrid(
          minItemWidth: 320,
          maxColumns: 2,
          spacing: 14,
          equalHeight: false,
          children: [
            for (final award in round.awards)
              _AwardBlock(
                award: award,
                candidates: candidates,
                picked: round.myAwardVotes[award.key],
                locked: !cubit.amPlaying,
                onPick: (userId) =>
                    cubit.voteAward(awardKey: award.key, targetUserId: userId),
              ),
          ],
        ),
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
      title: '${award.emoji}  ${award.label}',
      trailing: picked != null
          ? Icon(Icons.check_circle, color: palette.success, size: 22)
          : null,
      padding: const EdgeInsets.all(14),
      child: Wrap(
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
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? palette.primary : palette.outline,
        width: selected ? 1.5 : 1,
      ),
    );

    return Opacity(
      opacity: locked && !selected ? 0.45 : 1,
      child: Material(
        color: selected
            ? palette.primary.withValues(alpha: 0.10)
            : palette.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: locked ? null : onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 12, 5),
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
                    fontWeight: FontWeight.w700,
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
