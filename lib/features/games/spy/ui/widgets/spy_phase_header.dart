import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../cubit/spy_game_cubit.dart';
import '../../model/spy_models.dart';

/// ترويسة ثابتة أثناء اللعب: الجولة، المجموعة، وعدّاد المرحلة.
///
/// العدّاد يُحسب من ختم السيرفر مصحّحاً بفرق الساعة، فيرى الجميع الرقم نفسه.
class SpyPhaseHeader extends StatelessWidget {
  const SpyPhaseHeader({super.key, required this.state});

  final SpyGameState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = state.snapshot!;
    final round = state.round!;

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
                  round.number < 1
                      ? 'لعبة الجاسوس'
                      : 'جولة ${round.number} من ${snapshot.maxRounds}',
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
          // المجموعة معروفة للجميع — وهي أول ما يبني عليه الجاسوس تمثيله.
          if (snapshot.categoryLabel != null)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${snapshot.categoryEmoji ?? ''} ${snapshot.categoryLabel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
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
                // التكّة في آخر عشر ثوانٍ من دورك أنت فقط: المراحل التي
                // تتفرّج فيها لا تحتاج ضغطاً على أعصابك.
                final mine =
                    context.read<SpyGameCubit>().canAsk ||
                    context.read<SpyGameCubit>().canAnswer;

                if (mine && remaining <= 10) {
                  context.read<GameFeedback>().tick();
                }
              },
              builder: (context, remaining) => _WhiteCountdown(
                remaining: remaining,
                urgent: remaining <= 10,
              ),
            ),
        ],
      ),
    );
  }

  static int? _phaseSeconds(SpyPhase phase, SpyConfig config) =>
      switch (phase) {
        SpyPhase.asking || SpyPhase.answering => config.turnSeconds,
        SpyPhase.roleReveal => 12,
        SpyPhase.voting => 40,
        SpyPhase.voteResult => 10,
        SpyPhase.spyGuess => 25,
      };

  static String phaseLabel(SpyPhase phase) => switch (phase) {
    SpyPhase.roleReveal => 'شوف ورقتك',
    SpyPhase.asking => 'وقت السؤال',
    SpyPhase.answering => 'وقت الجواب',
    SpyPhase.voting => 'مين الجاسوس؟',
    SpyPhase.voteResult => 'نتيجة التصويت',
    SpyPhase.spyGuess => 'فرصة الجاسوس الأخيرة',
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
