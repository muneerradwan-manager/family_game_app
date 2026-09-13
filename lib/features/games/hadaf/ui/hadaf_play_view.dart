import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../cubit/hadaf_game_cubit.dart';
import '../model/hadaf_models.dart';
import 'widgets/hadaf_layout.dart';
import 'widgets/hadaf_phase_header.dart';
import 'widgets/question_card.dart';
import 'widgets/ready_card.dart';
import 'widgets/reveal_card.dart';
import 'widgets/risk_button.dart';
import 'widgets/standings_view.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
///
/// على الشاشة العريضة الترتيب الحيّ ظاهر بجانب السؤال طوال السباق — تعرف
/// كم تحتاج لتسبق من أمامك قبل أن تقرّر ⚡، لا بعد انتهاء الجولة.
class HadafPlayView extends StatelessWidget {
  const HadafPlayView({super.key});

  /// أقصى عرض للسؤال بجانب العمود الجانبي: خيارات بعرض 1000 بكسل تبعد
  /// الخيار الأول عن الأخير مسافة تكلّف اللاعب جزءاً من الثانية.
  static const _raceWidth = 860.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const SessionSkeleton();

    final split = SessionBody.isSplit(context);
    // ⚡ لا تُعرض للمتفرّج ولا في جولة حسم لا يشارك فيها.
    final showRisk = round.phase.isRacing && cubit.amRacing;
    final canEndEarly = snapshot.me.canEndEarly;
    final hasFooter = showRisk || canEndEarly;
    final reserveInset = !hasFooter;
    final myRisksLeft = snapshot.me.isPlayer ? snapshot.me.risksLeft : null;

    // في مرحلة الترتيب اللوحة نفسها هي المحتوى الرئيسي؛ تكرارها في العمود
    // الجانبي يعرض الشيء نفسه مرتين جنباً إلى جنب.
    final showSide = split && round.phase != HadafPhase.scoreboard;

    final main = switch (round.phase) {
      HadafPhase.ready => HadafCentered(
        reserveInset: reserveInset,
        child: ReadyCard(round: round, clockSkewMs: state.clockSkewMs),
      ),
      HadafPhase.question || HadafPhase.tiebreak => _RaceStage(
        round: round,
        reserveInset: reserveInset,
        maxWidth: split ? _raceWidth : ContentWidth.standard,
      ),
      HadafPhase.reveal => HadafScroll(
        maxWidth: split ? _raceWidth : ContentWidth.standard,
        reserveInset: reserveInset,
        children: [RevealCard(round: round, viewerId: cubit.viewerId)],
      ),
      HadafPhase.scoreboard => HadafScroll(
        reserveInset: reserveInset,
        children: [
          StandingsView(
            title: 'الترتيب',
            standings: snapshot.standings,
            viewerId: cubit.viewerId,
            myRisksLeft: myRisksLeft,
          ),
        ],
      ),
    };

    return Column(
      children: [
        HadafPhaseHeader(state: state),
        Expanded(
          child: SessionBody(
            main: main,
            side: showSide
                ? HadafSide(
                    aboveFooter: hasFooter,
                    children: [
                      StandingsView(
                        title: 'الترتيب',
                        standings: snapshot.standings,
                        viewerId: cubit.viewerId,
                        myRisksLeft: myRisksLeft,
                      ),
                    ],
                  )
                : null,
            // بلا تذييل حين لا شيء فيه: القوائم تحجز شريط التنقّل بنفسها
            // ([reserveInset])، فلا يُفقد الحجز في أي حالة.
            footer: hasFooter
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showRisk) const RiskButton(),
                      if (showRisk && canEndEarly) const SizedBox(height: 4),
                      if (canEndEarly)
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _confirmEndEarly(context),
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 18,
                            ),
                            label: const Text('إنهاء مبكّر وعرض الترتيب'),
                          ),
                        ),
                    ],
                  )
                : null,
          ),
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
            style: AppButtonStyle.compact,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('خلّصها'),
          ),
        ],
      ),
    );

    if (confirmed == true) await cubit.endEarly();
  }
}

/// مرحلة السباق: السؤال وخياراته، وزر ⚡ في التذييل الثابت.
class _RaceStage extends StatelessWidget {
  const _RaceStage({
    required this.round,
    required this.reserveInset,
    required this.maxWidth,
  });

  final HadafRound round;
  final bool reserveInset;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final palette = context.palette;
    final tiebreak = round.phase == HadafPhase.tiebreak;
    final watching = !cubit.amRacing;

    return HadafScroll(
      maxWidth: maxWidth,
      reserveInset: reserveInset,
      bottom: 16,
      children: [
        if (tiebreak) ...[
          SectionCard(
            color: palette.accent.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              watching
                  ? '🔥 المتعادلين عم يتسابقوا — تفرّج!'
                  : '🔥 جولة حسم — أول إجابة صحيحة تفوز',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.accent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        QuestionCard(round: round),
      ],
    );
  }
}
