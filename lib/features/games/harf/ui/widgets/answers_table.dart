import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/harf_game_cubit.dart';
import '../../model/harf_models.dart';

/// عرض الإجابات.
///
/// مرحلتان بشاشة واحدة: العرض (قراءة وضحك، بلا أزرار) ثم الاعتراض (يظهر ❌
/// بجانب إجابات غيرك). الفصل مقصود — لو ظهرت الأزرار من أول لحظة لانشغل
/// الناس بالحكم بدل القراءة، وهي أمتع ما في اللعبة.
class AnswersTable extends StatelessWidget {
  const AnswersTable({
    super.key,
    required this.config,
    required this.round,
    required this.allowObjections,
  });

  final HarfConfig config;
  final HarfRound round;
  final bool allowObjections;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HarfGameCubit>();
    final palette = context.palette;
    final objectionsLeft = round.objectionsLeft;

    return Column(
      children: [
        if (allowObjections)
          Container(
            width: double.infinity,
            color: palette.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.gavel_outlined, size: 18, color: palette.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    objectionsLeft > 0
                        ? 'اضغط ❌ على أي إجابة مشكوك فيها — ضلّ إلك $objectionsLeft اعتراضات'
                        // عقوبة الاعتراض الفاشل −5 هي ما يمنع الاعتراض الكيدي.
                        : 'خلصت اعتراضاتك بهالجولة',
                    style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: context.contentPadding(top: 16, bottom: 24),
            itemCount: round.rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = round.rows[index];
              final isMe = row.userId == cubit.viewerId;
              final isStopper = row.userId == round.stopBy;

              return SectionCard(
                color: isMe ? palette.primary.withValues(alpha: 0.06) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          row.username,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          const InfoChip('إنت'),
                        ],
                        if (isStopper) ...[
                          const SizedBox(width: 8),
                          InfoChip('ضغط ستوب', color: palette.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final column in config.columns)
                      _AnswerLine(
                        label: config.labelOf(column),
                        value: row.answers[column] ?? '',
                        // لا اعتراض على إجابتك، ولا على خانة فارغة (هي صفر أصلاً).
                        canObject:
                            allowObjections &&
                            !isMe &&
                            objectionsLeft > 0 &&
                            (row.answers[column] ?? '').trim().isNotEmpty,
                        objected: cubit.hasObjectedTo(row.userId, column),
                        onObject: () => cubit.raiseObjection(
                          targetUserId: row.userId,
                          column: column,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.canObject,
    required this.objected,
    required this.onObject,
  });

  final String label;
  final String value;
  final bool canObject;
  final bool objected;
  final VoidCallback onObject;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final empty = value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: palette.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              empty ? '—' : value,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                color: empty ? palette.textMuted : palette.textPrimary,
              ),
            ),
          ),
          if (canObject || objected)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: objected ? null : onObject,
              icon: Icon(
                objected ? Icons.cancel : Icons.cancel_outlined,
                size: 21,
                color: objected ? palette.accent : palette.textMuted,
              ),
              tooltip: objected ? 'اعترضت' : 'اعتراض',
            ),
        ],
      ),
    );
  }
}
