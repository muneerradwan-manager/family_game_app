import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../cubit/hadaf_game_cubit.dart';
import '../../model/hadaf_models.dart';

/// ترويسة ثابتة أثناء اللعب: الجولة، نقاطي، سلسلتي، وعدّاد المرحلة.
class HadafPhaseHeader extends StatelessWidget {
  const HadafPhaseHeader({super.key, required this.state});

  final HadafGameState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final me = snapshot.me;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  round.phase == HadafPhase.tiebreak
                      ? 'جولة الحسم 🔥'
                      : 'جولة ${round.number} من ${snapshot.totalRounds}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phaseLabel(round.phase),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (me.isPlayer)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${me.total}',
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFontFamily,
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    me.streak >= 3 ? '🔥 ${me.streak}' : 'نقطة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          if (round.deadline > 0)
            PhaseCountdown(
              key: ValueKey('${round.number}-${round.phase}-${round.deadline}'),
              deadline: round.deadline,
              clockSkewMs: state.clockSkewMs,
              totalSeconds: _phaseSeconds(round.phase, snapshot.config),
              size: 54,
              onSecondTick: (remaining) {
                // التكّة أثناء السباق وحده وفي آخر خمس ثوانٍ: المراحل التي
                // تتفرّج فيها لا تحتاج ضغطاً على أعصابك.
                if (round.phase.isRacing && remaining <= 5) {
                  context.read<GameFeedback>().tick();
                }
              },
              builder: (context, remaining) => _WhiteCountdown(
                remaining: remaining,
                urgent: round.phase.isRacing && remaining <= 5,
              ),
            ),
        ],
      ),
    );
  }

  static int? _phaseSeconds(HadafPhase phase, HadafConfig config) =>
      switch (phase) {
        HadafPhase.question => config.questionSeconds,
        HadafPhase.ready => 4,
        HadafPhase.reveal => 7,
        HadafPhase.scoreboard => 6,
        HadafPhase.tiebreak => 25,
      };

  static String phaseLabel(HadafPhase phase) => switch (phase) {
    HadafPhase.ready => 'استعدّوا...',
    HadafPhase.question => 'انطلقوا!',
    HadafPhase.reveal => 'الجواب',
    HadafPhase.scoreboard => 'الترتيب',
    HadafPhase.tiebreak => 'أول إجابة صحيحة تحسم',
  };
}

class _WhiteCountdown extends StatelessWidget {
  const _WhiteCountdown({required this.remaining, required this.urgent});

  final int remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: urgent && remaining.isOdd ? 1.15 : 1,
    duration: const Duration(milliseconds: 200),
    child: Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: urgent
            ? context.palette.accent
            : Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$remaining',
        style: const TextStyle(
          fontFamily: AppTheme.displayFontFamily,
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
