import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../auth/model/app_user.dart';
import '../../cubit/spy_game_cubit.dart';
import '../../model/spy_models.dart';

/// مرحلة التصويت: كل لاعب يختار من يشتبه به.
///
/// صوتك لا يراه أحد قبل إعلان النتيجة — لا في حدث ولا في لقطة غيرك. الرقم
/// وحده يُبَث ("صوّت 3 من 5") حتى يعرف الجميع أن الانتظار له سبب.
class VoteCard extends StatelessWidget {
  const VoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final round = state.round!;
    final palette = context.palette;
    final myVote = round.myVote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '🗳️ مين الجاسوس؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cubit.amActive
              ? 'صوّت على اللي بتشك فيه. أعلى أصوات بيطلع.'
              : 'إنت خارج التصويت — تفرّج بس.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        Center(
          child: InfoChip(
            'صوّت ${round.votedCount} من ${round.eligibleCount}',
            icon: Icons.how_to_vote_outlined,
          ),
        ),
        const SizedBox(height: 18),
        for (final player in cubit.suspects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuspectTile(
              player: player,
              selected: player.id == myVote,
              locked: myVote != null || !cubit.amActive,
              onTap: () => cubit.vote(player.id),
            ),
          ),
        if (myVote != null) ...[
          const SizedBox(height: 6),
          Text(
            'صوّتت — عم ننطر الباقيين.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'إذا تعادلوا الأصوات، ما بيطلع حدا وبتبلّش جولة جديدة.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _SuspectTile extends StatelessWidget {
  const _SuspectTile({
    required this.player,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final SpyPlayer player;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      padding: EdgeInsets.zero,
      color: selected ? palette.accent.withValues(alpha: 0.12) : null,
      onTap: locked ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            PlayerAvatar(
              username: player.username,
              photoUrl: player.photoUrl,
              avatarId: player.avatarId,
              gender: Gender.parse(player.gender),
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player.username,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: palette.accent, size: 24)
            else if (!locked)
              Icon(
                Icons.radio_button_unchecked,
                color: palette.textMuted,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
