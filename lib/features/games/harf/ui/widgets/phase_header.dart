import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../cubit/harf_game_cubit.dart';
import '../../model/harf_models.dart';

/// ترويسة ثابتة أثناء اللعب: رقم الجولة، الحرف، وعدّاد المرحلة.
///
/// العدّاد يُحسب من ختم السيرفر مصحّحاً بفرق الساعة، فيرى الجميع الرقم نفسه.
class PhaseHeader extends StatelessWidget {
  const PhaseHeader({super.key, required this.state});

  final HarfGameState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final showLetter =
        round.phase != HarfPhase.awaitingLetter && round.letter != null;

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جولة ${round.number} من ${snapshot.totalRounds}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _phaseLabel(round.phase),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (showLetter)
            Container(
              width: 52,
              height: 52,
              margin: const EdgeInsetsDirectional.only(end: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                round.letter!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (round.deadline > 0)
            PhaseCountdown(
              key: ValueKey('${round.number}-${round.phase}-${round.deadline}'),
              deadline: round.deadline,
              clockSkewMs: state.clockSkewMs,
              totalSeconds: _phaseSeconds(round, snapshot.config),
              size: 54,
              onSecondTick: (remaining) {
                // التكّة في آخر 15 ثانية من الكتابة فقط: المراحل القصيرة
                // كلها داخل هذا المدى وستصير ضجيجاً متواصلاً.
                if (round.phase == HarfPhase.writing && remaining <= 15) {
                  context.read<GameFeedback>().tick();
                }
              },
              builder: (context, remaining) => _WhiteCountdown(
                remaining: remaining,
                urgent: round.phase == HarfPhase.writing && remaining <= 15,
              ),
            ),
        ],
      ),
    );
  }

  static int? _phaseSeconds(HarfRound round, HarfConfig config) =>
      switch (round.phase) {
        HarfPhase.writing => config.writeSeconds,
        HarfPhase.awaitingLetter => 10,
        HarfPhase.revealLetter => 3,
        HarfPhase.grace => 10,
        HarfPhase.reveal => 10,
        HarfPhase.objection => 20,
        HarfPhase.voting => 15,
        HarfPhase.scoreboard => 8,
        HarfPhase.tiebreak => 30,
      };

  static String _phaseLabel(HarfPhase phase) => switch (phase) {
    HarfPhase.awaitingLetter => 'سحب الحرف',
    HarfPhase.revealLetter => 'استعدوا...',
    HarfPhase.writing => 'اكتبوا!',
    HarfPhase.grace => 'كمّلوا الفاضي',
    HarfPhase.reveal => 'شوفوا الإجابات',
    HarfPhase.objection => 'وقت الاعتراض',
    HarfPhase.voting => 'تصويت',
    HarfPhase.scoreboard => 'النقاط',
    HarfPhase.tiebreak => 'جولة الحسم',
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
