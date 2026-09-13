import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/hadaf_game_cubit.dart';
import '../../model/hadaf_models.dart';

/// شريط ثابت أثناء اللعب: الجولة، نقاطي، سلسلتي، وعدّاد المرحلة.
///
/// سطح أبيض بحدّ سفلي كرأس لوحة الإدارة: العدّاد هو الشيء الملوّن الوحيد فيه،
/// فتلتقطه العين فوراً بدل أن يذوب في ترويسة ملوّنة كلها.
class HadafPhaseHeader extends StatelessWidget {
  const HadafPhaseHeader({super.key, required this.state});

  final HadafGameState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final me = snapshot.me;
    final phone = context.isPhone;
    final question = round.question;

    final subtitle = [
      phaseLabel(round.phase),
      // على الجوال الشريط ضيّق، والمجموعة ظاهرة أصلاً فوق السؤال.
      if (!phone && question?.categoryLabel != null)
        '${question!.categoryEmoji ?? ''} ${question.categoryLabel}'.trim(),
    ].join(' · ');

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
              // الرجوع يمرّ على PopScope في شاشة الجلسة: تأكيد ثم مغادرة.
              const AppBackButton(),
              if (!phone) ...[
                const GradientMark(emoji: '🎯', size: 42),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.phase == HadafPhase.tiebreak
                          ? 'جولة الحسم 🔥'
                          : 'جولة ${round.number} من ${snapshot.totalRounds}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (me.isPlayer) ...[
                const SizedBox(width: 10),
                _ScoreBox(total: me.total, streak: me.streak),
              ],
              if (round.deadline > 0) ...[
                const SizedBox(width: 10),
                PhaseCountdown(
                  key: ValueKey(
                    '${round.number}-${round.phase}-${round.deadline}',
                  ),
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
                  builder: (context, remaining) => _TimerBadge(
                    remaining: remaining,
                    total: _phaseSeconds(round.phase, snapshot.config),
                    urgent: round.phase.isRacing && remaining <= 5,
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.total, required this.streak});

  final int total;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$total',
            style: TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            streak >= 3 ? '🔥 $streak' : 'نقطة',
            style: TextStyle(color: palette.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// حلقة تنقص مع الوقت ورقم في وسطها؛ في آخر الثواني تصير بلون التنبيه وتنبض.
class _TimerBadge extends StatelessWidget {
  const _TimerBadge({
    required this.remaining,
    required this.total,
    required this.urgent,
  });

  final int remaining;
  final int? total;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = urgent ? palette.accent : palette.primary;
    final progress = total == null || total == 0
        ? 1.0
        : (remaining / total!).clamp(0.0, 1.0);

    return AnimatedScale(
      scale: urgent && remaining.isOdd ? 1.12 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: urgent ? 0.14 : 0.06),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              // الرقم يتغيّر كل ثانية؛ الحلقة تنزلق بينها بدل أن تقفز.
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 900),
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 4,
                  backgroundColor: palette.outline,
                  valueColor: AlwaysStoppedAnimation(tone),
                ),
              ),
            ),
            Text(
              '$remaining',
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                color: tone,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
