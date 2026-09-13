import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/feedback/game_feedback.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/spy_game_cubit.dart';
import '../../model/spy_models.dart';

/// ترويسة ثابتة أثناء اللعب: الجولة، المجموعة، وعدّاد المرحلة.
///
/// العدّاد يُحسب من ختم السيرفر مصحّحاً بفرق الساعة، فيرى الجميع الرقم نفسه.
/// شريط أبيض بحدّ سفلي كرأس لوحة الإدارة: العدّاد وحده يحمل اللون، فتقع
/// العين عليه لا على الترويسة.
class SpyPhaseHeader extends StatelessWidget {
  const SpyPhaseHeader({super.key, required this.state});

  final SpyGameState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = state.snapshot!;
    final round = state.round!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.outline)),
      ),
      // تحجز شريط الحالة هنا وحدها؛ شريط انقطاع الاتصال يزيلها عمّا تحته.
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
              // على الجوال المساحة للعنوان والعدّاد، والعلامة زينة تُترك.
              if (!context.isPhone) ...[
                const GradientMark(emoji: '🕵️', size: 42),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.number < 1
                          ? 'لعبة الجاسوس'
                          : 'جولة ${round.number} من ${snapshot.maxRounds}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      phaseLabel(round.phase),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // المجموعة معروفة للجميع — وهي أول ما يبني عليه الجاسوس تمثيله.
              if (snapshot.categoryLabel != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.isPhone ? 130 : 260,
                    ),
                    child: InfoChip(
                      '${snapshot.categoryEmoji ?? ''} ${snapshot.categoryLabel}',
                    ),
                  ),
                ),
              if (round.deadline > 0)
                PhaseCountdown(
                  key: ValueKey(
                    '${round.number}-${round.phase}-${round.deadline}',
                  ),
                  deadline: round.deadline,
                  clockSkewMs: state.clockSkewMs,
                  totalSeconds: _phaseSeconds(round.phase, snapshot.config),
                  size: 48,
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
                  builder: (context, remaining) => _CountdownBadge(
                    remaining: remaining,
                    urgent: remaining <= 10,
                  ),
                ),
            ],
          ),
        ),
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

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.remaining, required this.urgent});

  final int remaining;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedScale(
      scale: urgent && remaining.isOdd ? 1.12 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: urgent
              ? palette.accent
              : palette.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$remaining',
          style: TextStyle(
            fontFamily: AppTheme.displayFontFamily,
            color: urgent ? Colors.white : palette.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
