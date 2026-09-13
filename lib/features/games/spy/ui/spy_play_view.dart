import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/spy_game_cubit.dart';
import '../model/spy_models.dart';
import 'widgets/answer_card.dart';
import 'widgets/ask_turn_card.dart';
import 'widgets/role_card.dart';
import 'widgets/spy_guess_card.dart';
import 'widgets/spy_phase_header.dart';
import 'widgets/transcript_view.dart';
import 'widgets/vote_card.dart';
import 'widgets/vote_result_card.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
class SpyPlayView extends StatelessWidget {
  const SpyPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const AppLoader(message: 'عم تجهّز الجولة...');

    return Column(
      children: [
        SpyPhaseHeader(state: state),
        Expanded(
          child: switch (round.phase) {
            SpyPhase.roleReveal => RoleCard(
              isSpy: snapshot.me.isSpy,
              word: snapshot.me.word,
              categoryLabel: snapshot.categoryLabel,
              categoryEmoji: snapshot.categoryEmoji,
              isSpectator: snapshot.me.isSpectator,
            ),
            SpyPhase.asking || SpyPhase.answering => const _TurnStage(),
            SpyPhase.voting => const _Stage(child: VoteCard()),
            SpyPhase.voteResult => _Stage(
              child: VoteResultCard(
                outcome: round.voteResult!,
                isMe: round.voteResult?.ejectedUserId == cubit.viewerId,
              ),
            ),
            SpyPhase.spyGuess => _Stage(
              child: SpyGuessCard(
                options: round.guessOptions,
                isMe: snapshot.me.isSpy,
                spyUsername: round.spyUsername,
              ),
            ),
          },
        ),
        // SafeArea دائماً لا عند وجود الزر فقط: هي التي تحجز ارتفاع شريط
        // تنقّل النظام أسفل الشاشة.
        SafeArea(
          top: false,
          child: snapshot.me.canEndEarly
              ? Padding(
                  padding: context.contentPadding(top: 0, bottom: 8),
                  child: TextButton.icon(
                    onPressed: () => _confirmEndEarly(context),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('إنهاء مبكّر وكشف الجاسوس'),
                  ),
                )
              : const SizedBox.shrink(),
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

/// إطار موحّد لمراحل البطاقة الواحدة: توسيط وحدّ عرض وتمرير.
class _Stage extends StatelessWidget {
  const _Stage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: context.contentPadding(
      top: 24,
      bottom: 24,
      minHorizontal: 20,
      maxWidth: ContentWidth.form,
    ),
    child: child,
  );
}

/// مرحلة السؤال والجواب — وتحتها السجل دائماً.
///
/// السجل لا يُخفى في أي لحظة: هو الدليل الوحيد لكل الأطراف، ومن يقرأه أثناء
/// انتظار دوره يلعب أفضل. الشاشة تعرض ما يخصّك أعلاها وما يخصّ الجميع تحتها.
class _TurnStage extends StatelessWidget {
  const _TurnStage();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final turns = snapshot.currentRoundTurns;

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

    return ListView(
      padding: context.contentPadding(
        top: 20,
        bottom: 24,
        minHorizontal: 20,
        maxWidth: ContentWidth.form,
      ),
      children: [
        action,
        const SizedBox(height: 26),
        SectionTitle('سجل الجولة ${round.number}'),
        TranscriptView(
          turns: turns,
          viewerId: cubit.viewerId,
          emptyHint: 'أول سؤال بهالجولة رح يظهر هون — اقرأه منيح.',
        ),
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

    return Column(
      children: [
        if (asker != null)
          PlayerAvatar(
            username: asker!.username,
            photoUrl: asker!.photoUrl,
            avatarId: asker!.avatarId,
            gender: Gender.parse(asker!.gender),
            size: 72,
          ),
        const SizedBox(height: 16),
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
          SectionCard(
            color: palette.primary.withValues(alpha: 0.07),
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
    );
  }
}
