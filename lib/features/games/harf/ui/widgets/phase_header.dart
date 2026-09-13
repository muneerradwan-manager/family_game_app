import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/harf_game_cubit.dart';
import '../../model/harf_models.dart';

/// شريط ثابت أثناء اللعب: رقم الجولة، الحرف، المرحلة، وعدّادها.
///
/// سطح أبيض بحدّ سفلي كرأس لوحة الإدارة — المرحلة نفسها هي ما يجب أن يلفت
/// النظر، لا الترويسة. والعدّاد يُحسب من ختم السيرفر مصحّحاً بفرق الساعة،
/// فيرى الجميع الرقم نفسه.
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
              if (showLetter)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.control + 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    round.letter!,
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                )
              else
                const GradientMark(emoji: '🔠', size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جولة ${round.number} من ${snapshot.totalRounds}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InfoChip(
                      phaseLabel(round.phase),
                      color: _phaseTone(round.phase, context),
                    ),
                  ],
                ),
              ),
              if (round.deadline > 0)
                PhaseCountdown(
                  key: ValueKey(
                    '${round.number}-${round.phase}-${round.deadline}',
                  ),
                  deadline: round.deadline,
                  clockSkewMs: state.clockSkewMs,
                  totalSeconds: _phaseSeconds(round, snapshot.config),
                  size: 52,
                  onSecondTick: (remaining) {
                    // التكّة في آخر 15 ثانية من الكتابة فقط: المراحل القصيرة
                    // كلها داخل هذا المدى وستصير ضجيجاً متواصلاً.
                    if (round.phase == HarfPhase.writing && remaining <= 15) {
                      context.read<GameFeedback>().tick();
                    }
                  },
                  builder: (context, remaining) => _RingCountdown(
                    remaining: remaining,
                    total: _phaseSeconds(round, snapshot.config),
                    urgent: round.phase == HarfPhase.writing && remaining <= 15,
                  ),
                ),
            ],
          ),
        ),
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

  /// لون شارة المرحلة: لحظات الضغط (المهلة والحسم) بلون التنبيه، والحكم
  /// (اعتراض وتصويت) بلون التحذير، والباقي بلون الثيم.
  static Color _phaseTone(HarfPhase phase, BuildContext context) {
    final palette = context.palette;

    return switch (phase) {
      HarfPhase.grace || HarfPhase.tiebreak => palette.accent,
      HarfPhase.objection || HarfPhase.voting => palette.warning,
      _ => palette.primary,
    };
  }

  static String phaseLabel(HarfPhase phase) => switch (phase) {
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

/// حلقة تنقص مع الثواني ورقم في وسطها.
///
/// الحلقة تتقدّم بخطوة كل ثانية لا بسلاسة: الـbuilder يعطينا الثواني فقط،
/// وخطوة بالثانية كافية لعين تتابع الرقم أصلاً.
class _RingCountdown extends StatelessWidget {
  const _RingCountdown({
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
    final color = urgent ? palette.accent : palette.primary;
    final progress = total == null || total == 0
        ? null
        : (remaining / total!).clamp(0.0, 1.0);

    return AnimatedScale(
      scale: urgent && remaining.isOdd ? 1.12 : 1,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: urgent ? 0.16 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
            if (progress != null)
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    backgroundColor: palette.outline,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            Text(
              '$remaining',
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
