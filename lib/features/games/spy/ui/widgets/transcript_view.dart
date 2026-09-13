import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../model/spy_models.dart';

/// سجل الأسئلة والأجوبة — قلب اللعبة.
///
/// هذا ما يقرأه الجاسوس ليستنتج الكلمة، وما يقرأه الباقون ليكتشفوا من يتهرّب.
/// ولهذا يبقى ظاهراً في كل المراحل ولا يُطوى: إخفاؤه يساوي مسح أدلّة الجميع.
class TranscriptView extends StatelessWidget {
  const TranscriptView({
    super.key,
    required this.turns,
    required this.viewerId,
    this.compact = false,
    this.emptyHint,
  });

  final List<SpyTurn> turns;
  final String viewerId;

  /// نسخة مختصرة تُعرض تحت بطاقة الدور أو التصويت.
  final bool compact;

  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (turns.isEmpty) {
      return EmptyState(
        emoji: '💬',
        title: 'لسا ما في أسئلة',
        subtitle: emptyHint ?? 'أول سؤال رح يظهر هون.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final turn in turns)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 12),
            child: _TurnCard(turn: turn, viewerId: viewerId, compact: compact),
          ),
      ],
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.viewerId,
    required this.compact,
  });

  final SpyTurn turn;
  final String viewerId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (turn.skipped) {
      return SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: palette.surfaceAlt,
        child: Row(
          children: [
            Icon(Icons.timer_off_outlined, size: 17, color: palette.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${turn.askerUsername} خلص وقته بلا ما يسأل',
                style: TextStyle(color: palette.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final mine = turn.askerId == viewerId || turn.targetId == viewerId;

    return SectionCard(
      padding: EdgeInsets.all(compact ? 14 : 16),
      color: mine ? palette.primary.withValues(alpha: 0.07) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  turn.askerUsername,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: palette.primary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_back,
                  size: 14,
                  color: palette.textMuted,
                ),
              ),
              Flexible(
                child: Text(
                  turn.targetUsername ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: palette.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Line(
            marker: 'س',
            markerColor: palette.primary,
            text: turn.question ?? '',
          ),
          const SizedBox(height: 6),
          if (turn.unanswered)
            _Line(
              marker: 'ج',
              markerColor: palette.textMuted,
              text: 'ما جاوب — خلص وقته 🤐',
              muted: true,
            )
          else if (turn.answer != null)
            _Line(
              marker: 'ج',
              markerColor: palette.secondary,
              text: turn.answer!,
            )
          else
            _Line(
              marker: 'ج',
              markerColor: palette.textMuted,
              text: 'عم يكتب جوابه...',
              muted: true,
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.marker,
    required this.markerColor,
    required this.text,
    this.muted = false,
  });

  final String marker;
  final Color markerColor;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsetsDirectional.only(end: 8, top: 1),
          decoration: BoxDecoration(
            color: markerColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            marker,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: markerColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: muted ? palette.textMuted : palette.textPrimary,
              fontSize: 14.5,
              height: 1.5,
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
