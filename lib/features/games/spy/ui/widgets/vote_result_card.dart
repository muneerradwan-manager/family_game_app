import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../model/spy_models.dart';

/// نتيجة تصويت الجولة: من خرج، وهل كان هو الجاسوس.
class VoteResultCard extends StatelessWidget {
  const VoteResultCard({super.key, required this.outcome, required this.isMe});

  final VoteOutcome outcome;

  /// هل أنا من خرج؟
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = outcome.tie
        ? palette.textMuted
        : (outcome.wasSpy ? palette.primary : palette.accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          outcome.tie ? '🤷' : (outcome.wasSpy ? '🎉' : '❌'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 52),
        ),
        const SizedBox(height: 12),
        Text(
          _title(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: tone,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _subtitle(),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SectionTitle('الأصوات'),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final row in outcome.counts)
                ListTile(
                  dense: true,
                  title: Text(
                    row.username,
                    style: TextStyle(
                      fontWeight: row.userId == outcome.ejectedUserId
                          ? FontWeight.w900
                          : FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  trailing: _VoteBadge(
                    votes: row.votes,
                    highlighted: row.userId == outcome.ejectedUserId,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _title() {
    if (outcome.tie) return 'ما في أغلبية!';

    return outcome.wasSpy
        ? 'مسكتوه! ${outcome.ejectedUsername} كان الجاسوس'
        : 'برّيء! ${outcome.ejectedUsername} ما كان الجاسوس';
  }

  String _subtitle() {
    if (outcome.tie) {
      return 'تعادلت الأصوات فما طلع حدا — الجاسوس ربح جولة كمان.';
    }

    if (outcome.wasSpy) return 'كشفتوه — بس لسا في خطوة أخيرة...';

    return isMe
        ? '🕵️ طلعت من اللعبة — بتقدر تتفرّج وتشوف مين بيمسكه.'
        : '🕵️ الجاسوس لسا بيناتكم — جولة جديدة.';
  }
}

class _VoteBadge extends StatelessWidget {
  const _VoteBadge({required this.votes, required this.highlighted});

  final int votes;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = highlighted ? palette.accent : palette.textMuted;

    return Container(
      width: 34,
      height: 30,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '$votes',
        style: TextStyle(
          fontFamily: AppTheme.displayFontFamily,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}
