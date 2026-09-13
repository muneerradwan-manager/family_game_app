import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../cubit/mashhad_game_cubit.dart';
import '../model/mashhad_models.dart';
import 'widgets/awards_card.dart';
import 'widgets/claims_card.dart';
import 'widgets/mashhad_phase_header.dart';
import 'widgets/reveal_board.dart';
import 'widgets/role_brief.dart';
import 'widgets/scene_chat.dart';
import 'widgets/scene_scoreboard.dart';
import 'widgets/verdict_card.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
class MashhadPlayView extends StatelessWidget {
  const MashhadPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final state = context.watch<MashhadGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const AppLoader(message: 'عم يجهّز المشهد...');

    return Column(
      children: [
        MashhadPhaseHeader(state: state),
        Expanded(
          child: switch (round.phase) {
            MashhadPhase.roleReveal => RoleBrief(
              title: round.title,
              setup: round.setup,
              categoryLabel: round.categoryLabel,
              categoryEmoji: round.categoryEmoji,
              role: round.myRole,
              isSpectator: snapshot.me.isSpectator,
            ),
            // الشات يملأ الشاشة بنفسه: له حقل إدخال وتمرير خاصّان به.
            MashhadPhase.scene => SceneChat(round: round),
            MashhadPhase.claims => _Stage(child: ClaimsCard(round: round)),
            MashhadPhase.challenge => _Stage(
              maxWidth: ContentWidth.standard,
              child: RevealBoard(round: round),
            ),
            MashhadPhase.verdict => _Stage(
              child: round.challenge == null
                  ? const AppLoader(message: 'عم نجهّز الاعتراض...')
                  : VerdictCard(challenge: round.challenge!),
            ),
            MashhadPhase.scoreboard => _Stage(
              maxWidth: ContentWidth.standard,
              child: SceneScoreboard(
                scores: round.sceneScores,
                standings: snapshot.standings,
                viewerId: cubit.viewerId,
              ),
            ),
            MashhadPhase.awards => _Stage(child: AwardsCard(round: round)),
          },
        ),
        // SafeArea دائماً: هي التي تحجز ارتفاع شريط تنقّل النظام أسفل الشاشة.
        // والشات يحجزها بنفسه، فنتخطاها هنا كي لا تُحسب مرتين.
        if (round.phase != MashhadPhase.scene)
          SafeArea(
            top: false,
            child: snapshot.me.canEndEarly
                ? Padding(
                    padding: context.contentPadding(top: 0, bottom: 8),
                    child: TextButton.icon(
                      onPressed: () => _confirmEndEarly(context),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('إنهاء مبكّر وعرض الترتيب'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Future<void> _confirmEndEarly(BuildContext context) async {
    final cubit = context.read<MashhadGameCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنهاء اللعبة؟'),
        content: const Text('رح تنعرض النتيجة النهائية بالنقاط الحالية.'),
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

class _Stage extends StatelessWidget {
  const _Stage({required this.child, this.maxWidth = ContentWidth.form});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: context.contentPadding(
      top: 22,
      bottom: 24,
      minHorizontal: 20,
      maxWidth: maxWidth,
    ),
    child: child,
  );
}
