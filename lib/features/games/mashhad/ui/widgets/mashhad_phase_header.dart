import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// شريط علوي ثابت أثناء اللعب: المشهد، نقاطي، وعدّاد المرحلة.
///
/// سطح أبيض بحدّ سفلي لا كتلة ملوّنة: الشات تحته هو ما يجب أن يلفت النظر،
/// والعدّاد وحده يتلوّن حين تقترب النهاية.
class MashhadPhaseHeader extends StatelessWidget {
  const MashhadPhaseHeader({super.key, required this.state, this.onBack});

  final MashhadGameState state;

  /// الخروج يمرّ على تأكيد شاشة الجلسة — على الشاشة الكبيرة لا زر رجوع
  /// للنظام، فبدونه لا طريق للخروج من المشهد.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final me = snapshot.me;
    final phase = phaseLabel(round.phase);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.outline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: context.contentPadding(
            top: 10,
            bottom: 12,
            minHorizontal: 16,
            maxWidth: ContentWidth.wide,
          ),
          child: Row(
            children: [
              if (onBack != null) AppBackButton(onPressed: onBack),
              const GradientMark(emoji: '🎬', size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.phase == MashhadPhase.awards
                          ? 'جوائز السهرة'
                          : 'مشهد ${round.number} من ${snapshot.totalScenes}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      // الحبكة عامة للجميع، وعنوانها يذكّر بالمشهد أثناء الحوار.
                      round.title.isEmpty || round.phase == MashhadPhase.awards
                          ? phase
                          : '$phase · ${round.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (me.isPlayer) ...[
                const SizedBox(width: 8),
                _PointsPill(total: me.total),
              ],
              if (round.deadline > 0) ...[
                const SizedBox(width: 8),
                PhaseCountdown(
                  key: ValueKey(
                    '${round.number}-${round.phase}-${round.deadline}',
                  ),
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
                  builder: (context, remaining) => _TimerPill(
                    remaining: remaining,
                    urgent:
                        round.phase == MashhadPhase.scene && remaining <= 15,
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$total',
            style: TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              color: palette.primary,
              fontSize: 17,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'نقطة',
            style: TextStyle(color: palette.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.remaining, required this.urgent});

  final int remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // المشهد ثلاث دقائق: الرقم وحده بالثواني يصير أربع خانات ولا يُقرأ.
    final label = remaining >= 60
        ? '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
        : '$remaining';
    final foreground = urgent ? Colors.white : palette.textPrimary;

    return AnimatedScale(
      scale: urgent && remaining.isOdd ? 1.08 : 1,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 46,
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: urgent ? palette.accent : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 17,
              color: urgent ? foreground : palette.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                color: foreground,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
