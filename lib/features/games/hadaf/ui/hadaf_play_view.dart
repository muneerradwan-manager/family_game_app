import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../cubit/hadaf_game_cubit.dart';
import '../model/hadaf_models.dart';
import 'widgets/hadaf_phase_header.dart';
import 'widgets/question_card.dart';
import 'widgets/ready_card.dart';
import 'widgets/reveal_card.dart';
import 'widgets/risk_button.dart';
import 'widgets/standings_view.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
class HadafPlayView extends StatelessWidget {
  const HadafPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const AppLoader(message: 'عم تجهّز الجولة...');

    return Column(
      children: [
        HadafPhaseHeader(state: state),
        Expanded(
          child: switch (round.phase) {
            HadafPhase.ready => ReadyCard(
              round: round,
              clockSkewMs: state.clockSkewMs,
            ),
            HadafPhase.question ||
            HadafPhase.tiebreak => _RaceStage(round: round),
            HadafPhase.reveal => _Stage(
              child: RevealCard(round: round, viewerId: cubit.viewerId),
            ),
            HadafPhase.scoreboard => _Stage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('الترتيب'),
                  StandingsView(
                    standings: snapshot.standings,
                    viewerId: cubit.viewerId,
                  ),
                ],
              ),
            ),
          },
        ),
        // SafeArea دائماً: هي التي تحجز ارتفاع شريط تنقّل النظام أسفل الشاشة.
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
    final cubit = context.read<HadafGameCubit>();

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
  const _Stage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: context.contentPadding(
      top: 22,
      bottom: 24,
      minHorizontal: 20,
      maxWidth: ContentWidth.form,
    ),
    child: child,
  );
}

/// مرحلة السباق: السؤال وخياراته، وزر ⚡ مثبّت أسفل الشاشة.
class _RaceStage extends StatelessWidget {
  const _RaceStage({required this.round});

  final HadafRound round;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final palette = context.palette;
    final tiebreak = round.phase == HadafPhase.tiebreak;
    final watching = !cubit.amRacing;

    return Column(
      children: [
        if (tiebreak)
          Container(
            width: double.infinity,
            color: palette.accent.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text(
              watching
                  ? '🔥 المتعادلين عم يتسابقوا — تفرّج!'
                  : '🔥 جولة حسم — أول إجابة صحيحة تفوز',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.accent,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: context.contentPadding(
              top: 20,
              bottom: 12,
              minHorizontal: 20,
              maxWidth: ContentWidth.form,
            ),
            child: QuestionCard(round: round),
          ),
        ),
        // ⚡ لا تُعرض للمتفرّج ولا في جولة حسم لا يشارك فيها.
        if (!watching)
          SafeArea(
            top: false,
            child: Padding(
              padding: context.contentPadding(
                top: 0,
                bottom: 10,
                maxWidth: ContentWidth.form,
              ),
              child: const Align(
                alignment: Alignment.center,
                child: RiskButton(),
              ),
            ),
          ),
      ],
    );
  }
}
