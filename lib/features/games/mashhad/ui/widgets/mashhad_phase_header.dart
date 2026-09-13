import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// ترويسة ثابتة أثناء اللعب: المشهد، نقاطي، وعدّاد المرحلة.
class MashhadPhaseHeader extends StatelessWidget {
  const MashhadPhaseHeader({super.key, required this.state});

  final MashhadGameState state;

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
                  round.phase == MashhadPhase.awards
                      ? 'جوائز السهرة'
                      : 'مشهد ${round.number} من ${snapshot.totalScenes}',
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
                    'نقطة',
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
                // التكّة في آخر عشر ثوانٍ من المشهد: لحظة «باقي شوي» التي
                // تدفع الجميع لإنهاء ما بدأوه.
                if (round.phase == MashhadPhase.scene && remaining <= 10) {
                  context.read<GameFeedback>().tick();
                }
              },
              builder: (context, remaining) => _WhiteCountdown(
                remaining: remaining,
                urgent: round.phase == MashhadPhase.scene && remaining <= 15,
              ),
            ),
        ],
      ),
    );
  }

  static int? _phaseSeconds(MashhadPhase phase, MashhadConfig config) =>
      switch (phase) {
        MashhadPhase.scene => config.sceneSeconds,
        MashhadPhase.roleReveal => 20,
        MashhadPhase.claims => 35,
        MashhadPhase.challenge => 30,
        MashhadPhase.verdict => 15,
        MashhadPhase.scoreboard => 10,
        MashhadPhase.awards => 35,
      };

  static String phaseLabel(MashhadPhase phase) => switch (phase) {
    MashhadPhase.roleReveal => 'اقرأ دورك',
    MashhadPhase.scene => 'المشهد شغّال!',
    MashhadPhase.claims => 'شو حقّقت؟',
    MashhadPhase.challenge => 'انكشف كل شي',
    MashhadPhase.verdict => 'تصويت على اعتراض',
    MashhadPhase.scoreboard => 'نقاط المشهد',
    MashhadPhase.awards => 'صوّتوا للجوائز',
  };
}

class _WhiteCountdown extends StatelessWidget {
  const _WhiteCountdown({required this.remaining, required this.urgent});

  final int remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    // المشهد ثلاث دقائق: الرقم وحده بالثواني يصير أربع خانات ولا يُقرأ.
    final label = remaining >= 60
        ? '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
        : '$remaining';

    return AnimatedScale(
      scale: urgent && remaining.isOdd ? 1.12 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 58,
        height: 54,
        decoration: BoxDecoration(
          color: urgent
              ? context.palette.accent
              : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.displayFontFamily,
            color: Colors.white,
            fontSize: label.length > 2 ? 18 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
