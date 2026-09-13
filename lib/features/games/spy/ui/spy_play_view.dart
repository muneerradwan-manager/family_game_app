import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/spy_game_cubit.dart';
import '../model/spy_models.dart';
import 'widgets/answer_card.dart';
import 'widgets/ask_turn_card.dart';
import 'widgets/role_card.dart';
import 'widgets/spy_guess_card.dart';
import 'widgets/spy_layout.dart';
import 'widgets/spy_phase_header.dart';
import 'widgets/transcript_view.dart';
import 'widgets/vote_card.dart';
import 'widgets/vote_result_card.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
///
/// على الشاشة العريضة السجل واللاعبون في عمود جانبي ثابت: من يصوّت يقرأ
/// الأسئلة وهو يختار، بدل أن يتنقّل بين المرحلة والسجل.
class SpyPlayView extends StatelessWidget {
  const SpyPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const SessionSkeleton();

    return Column(
      children: [
        SpyPhaseHeader(state: state),
        Expanded(
          child: SpyBody(
            main: switch (round.phase) {
              SpyPhase.roleReveal => RoleCard(
                isSpy: snapshot.me.isSpy,
                word: snapshot.me.word,
                categoryLabel: snapshot.categoryLabel,
                categoryEmoji: snapshot.categoryEmoji,
                isSpectator: snapshot.me.isSpectator,
              ),
              SpyPhase.asking || SpyPhase.answering => const _TurnStage(),
              SpyPhase.voting => const SpyStage(
                maxWidth: ContentWidth.standard,
                children: [VoteCard()],
              ),
              SpyPhase.voteResult => SpyStage(
                maxWidth: 560,
                children: [
                  VoteResultCard(
                    outcome: round.voteResult!,
                    isMe: round.voteResult?.ejectedUserId == cubit.viewerId,
                  ),
                ],
              ),
              SpyPhase.spyGuess => SpyStage(
                maxWidth: 560,
                children: [
                  SpyGuessCard(
                    options: round.guessOptions,
                    isMe: snapshot.me.isSpy,
                    spyUsername: round.spyUsername,
                  ),
                ],
              ),
            },
            side: const _PlaySidePanel(),
            footer: snapshot.me.canEndEarly
                ? Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmEndEarly(context),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('إنهاء مبكّر وكشف الجاسوس'),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmEndEarly(BuildContext context) async {
    final cubit = context.read<SpyGameCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنهاء اللعبة؟'),
        content: const Text('رح تنكشف الكلمة والجاسوس، وما بيفوز ولا طرف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('كمّل'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('خلّصها'),
          ),
        ],
      ),
    );

    if (confirmed == true) await cubit.endEarly();
  }
}

/// مرحلة السؤال والجواب — وتحتها السجل دائماً.
///
/// السجل لا يُخفى في أي لحظة: هو الدليل الوحيد لكل الأطراف، ومن يقرأه أثناء
/// انتظار دوره يلعب أفضل. الشاشة تعرض ما يخصّك أعلاها وما يخصّ الجميع تحتها
/// — إلا على الشاشة العريضة، حيث السجل في العمود الجانبي فلا يُكرَّر هنا.
class _TurnStage extends StatelessWidget {
  const _TurnStage();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final turns = snapshot.currentRoundTurns;
    final split = SessionBody.isSplit(context);

    final Widget action;

    if (cubit.canAsk) {
      action = const AskTurnCard();
    } else if (cubit.canAnswer && round.currentTurn != null) {
      action = AnswerCard(turn: round.currentTurn!);
    } else {
      action = _WaitingCard(
        round: round,
        asker: snapshot.playerById(round.currentAskerId),
        isOut: snapshot.me.isOut,
        isSpectator: snapshot.me.isSpectator,
      );
    }

    return SpyStage(
      maxWidth: 600,
      children: [
        action,
        if (!split) ...[
          const SizedBox(height: 24),
          SectionTitle('سجل الجولة ${round.number}'),
          TranscriptView(
            turns: turns,
            viewerId: cubit.viewerId,
            emptyHint: 'أول سؤال بهالجولة رح يظهر هون — اقرأه منيح.',
          ),
        ],
      ],
    );
  }
}

/// ما تراه وأنت تنتظر دورك: من يسأل الآن، وأين وصلت الجولة.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.round,
    required this.asker,
    required this.isOut,
    required this.isSpectator,
  });

  final SpyRound round;
  final SpyPlayer? asker;
  final bool isOut;
  final bool isSpectator;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final answering = round.phase == SpyPhase.answering;
    final turn = round.currentTurn;

    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (asker != null)
            PlayerAvatar(
              username: asker!.username,
              photoUrl: asker!.photoUrl,
              avatarId: asker!.avatarId,
              gender: Gender.parse(asker!.gender),
              size: 64,
            ),
          const SizedBox(height: 14),
          Text(
            answering
                ? 'دور ${turn?.targetUsername ?? 'اللاعب'} يجاوب'
                : 'دور ${asker?.username ?? 'اللاعب'} يسأل',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          if (answering && turn?.question != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                turn!.question!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isOut)
            const InfoChip('طلعت من اللعبة — عم تتفرج', icon: Icons.visibility)
          else if (isSpectator)
            const InfoChip('إنت متفرّج', icon: Icons.visibility)
          else
            InfoChip(
              'باقي ${round.askQueue.length} دور بهالجولة',
              icon: Icons.people_outline,
            ),
        ],
      ),
    );
  }
}

/// العمود الجانبي على الشاشة العريضة: من في اللعبة ودور مَن، ثم سجل الجولة.
///
/// لا يعرض إلا ما هو معلن للجميع أصلاً (الدور، من طُرد، من غادر) — هوية
/// الجاسوس لا تمرّ من هنا بأي شكل.
class _PlaySidePanel extends StatelessWidget {
  const _PlaySidePanel();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round!;

    return SidePanel(
      children: [
        _PlayersCard(
          players: snapshot.players,
          round: round,
          viewerId: cubit.viewerId,
        ),
        const SizedBox(height: 20),
        SectionTitle('سجل الجولة ${round.number}'),
        TranscriptView(
          turns: snapshot.currentRoundTurns,
          viewerId: cubit.viewerId,
          compact: true,
          emptyHint: 'أول سؤال بهالجولة رح يظهر هون — اقرأه منيح.',
        ),
      ],
    );
  }
}

class _PlayersCard extends StatelessWidget {
  const _PlayersCard({
    required this.players,
    required this.round,
    required this.viewerId,
  });

  final List<SpyPlayer> players;
  final SpyRound round;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: 'اللاعبين',
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final player in players)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  PlayerAvatar(
                    username: player.username,
                    photoUrl: player.photoUrl,
                    avatarId: player.avatarId,
                    gender: Gender.parse(player.gender),
                    size: 34,
                    dimmed: player.isOut || player.hasLeft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      player.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: player.id == viewerId
                            ? palette.primary
                            : player.isActive
                            ? palette.textPrimary
                            : palette.textMuted,
                      ),
                    ),
                  ),
                  ?_status(context, player),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _status(BuildContext context, SpyPlayer player) {
    final palette = context.palette;

    if (player.hasLeft) {
      return InfoChip('طلع من اللعبة', color: palette.textMuted);
    }

    if (player.isOut) {
      return InfoChip(
        'انطرد بجولة ${player.outAtRound}',
        color: palette.danger,
      );
    }

    if (player.isSpectator) {
      return InfoChip(
        'متفرّج',
        color: palette.textMuted,
        icon: Icons.visibility,
      );
    }

    if (round.phase == SpyPhase.asking && player.id == round.currentAskerId) {
      return const InfoChip('دوره يسأل', icon: Icons.help_outline);
    }

    if (round.phase == SpyPhase.answering &&
        player.id == round.currentTurn?.targetId) {
      return InfoChip(
        'عم يجاوب',
        color: palette.secondary,
        icon: Icons.edit_outlined,
      );
    }

    return null;
  }
}
