import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// الكشف الكبير: كل الأدوار والأهداف والادّعاءات دفعةً واحدة.
///
/// هنا تُقرأ القصة من جديد بعيون مختلفة — «آه، لهيك كان مصرّ يطلع!» ومن
/// يشك في ادّعاء يعترض عليه، ويحسم الباقون.
class RevealBoard extends StatelessWidget {
  const RevealBoard({super.key, required this.round});

  final MashhadRound round;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '🎭 انكشفت الأدوار',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cubit.canChallenge
              ? 'شايف ادّعاء مو مظبوط؟ اعترض عليه — باقي لك ${round.challengesLeft}.'
              : 'ما ضل عندك اعتراضات.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.5),
        ),
        const SizedBox(height: 20),
        for (final row in round.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RevealRow(row: row, isMe: row.userId == cubit.viewerId),
          ),
        const SizedBox(height: 6),
        Text(
          'الاعتراض الفاشل بيكلّفك نقاط — اعترض لما تكون متأكد.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _RevealRow extends StatelessWidget {
  const _RevealRow({required this.row, required this.isMe});

  final ClaimRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      color: isMe ? palette.primary.withValues(alpha: 0.07) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  row.username,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InfoChip('🎭 ${row.roleName}'),
              const Spacer(),
              Text(
                '${row.messageCount} رسالة',
                style: TextStyle(color: palette.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GoalLine(
            emoji: '✅',
            label: 'الهدف الرئيسي',
            text: row.goal,
            claimed: row.claimedMain,
            kind: 'main',
            row: row,
            isMe: isMe,
          ),
          if (row.bonus != null) ...[
            const SizedBox(height: 8),
            _GoalLine(
              emoji: '⭐',
              label: 'هدف إضافي',
              text: row.bonus!,
              claimed: row.claimedBonus,
              kind: 'bonus',
              row: row,
              isMe: isMe,
            ),
          ],
          if (row.claimedEvent) ...[
            const SizedBox(height: 8),
            _GoalLine(
              emoji: '⚡',
              label: 'استغلال الحدث',
              text: 'وصله حدث خاص وقال إنه استفاد منه',
              claimed: true,
              kind: 'event',
              row: row,
              isMe: isMe,
            ),
          ],
          if (row.secret != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('🤫', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'كان يعرف: ${row.secret}',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({
    required this.emoji,
    required this.label,
    required this.text,
    required this.claimed,
    required this.kind,
    required this.row,
    required this.isMe,
  });

  final String emoji;
  final String label;
  final String text;
  final bool claimed;
  final String kind;
  final ClaimRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final state = context.watch<MashhadGameCubit>().state;
    final palette = context.palette;

    final challenged = state.challengedCells.contains('${row.userId}|$kind');
    final canChallenge = claimed && !isMe && cubit.canChallenge && !challenged;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  claimed ? 'ادّعى إنه حقّقه ✅' : 'قال إنه ما حقّقه ❌',
                  style: TextStyle(
                    color: claimed
                        ? const Color(0xFF2E7D32)
                        : palette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (challenged)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InfoChip('اعترضت', color: palette.accent),
            )
          else if (canChallenge)
            TextButton(
              onPressed: () =>
                  cubit.challenge(targetUserId: row.userId, kind: kind),
              style: TextButton.styleFrom(
                foregroundColor: palette.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
              ),
              child: const Text('بعترض!'),
            ),
        ],
      ),
    );
  }
}
