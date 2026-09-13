import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../auth/model/app_user.dart';
import '../../cubit/spy_game_cubit.dart';
import '../../model/spy_models.dart';

/// مرحلة التصويت: كل لاعب يختار من يشتبه به.
///
/// صوتك لا يراه أحد قبل إعلان النتيجة — لا في حدث ولا في لقطة غيرك. الرقم
/// وحده يُبَث ("صوّت 3 من 5") حتى يعرف الجميع أن الانتظار له سبب.
///
/// المشتبه بهم شبكة لا عمود: على التابلت يُرى الجميع دفعة واحدة، والمؤقّت
/// لا ينتظر من يمرّر ليصل إلى آخر اسم.
class VoteCard extends StatelessWidget {
  const VoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final round = state.round!;
    final palette = context.palette;
    final myVote = round.myVote;

    return SectionCard(
      title: '🗳️ مين الجاسوس؟',
      subtitle: cubit.amActive
          ? 'صوّت على اللي بتشك فيه. أعلى أصوات بيطلع.'
          : 'إنت خارج التصويت — تفرّج بس.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: InfoChip(
              'صوّت ${round.votedCount} من ${round.eligibleCount}',
              icon: Icons.how_to_vote_outlined,
            ),
          ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            minItemWidth: 210,
            spacing: 10,
            children: [
              for (final player in cubit.suspects)
                _SuspectTile(
                  player: player,
                  selected: player.id == myVote,
                  locked: myVote != null || !cubit.amActive,
                  onTap: () => cubit.vote(player.id),
                ),
            ],
          ),
          if (myVote != null) ...[
            const SizedBox(height: 14),
            Text(
              'صوّتت — عم ننطر الباقيين.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'إذا تعادلوا الأصوات، ما بيطلع حدا وبتبلّش جولة جديدة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5),
          ),
        ],
      ),
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
    final radius = BorderRadius.circular(AppRadius.control);

    return Material(
      color: selected
          ? palette.accent.withValues(alpha: 0.10)
          : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? palette.accent : palette.outline,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  maxLines: 1,
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
      ),
    );
  }
}
