import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/harf_game_cubit.dart';
import '../../model/harf_models.dart';
import 'harf_layout.dart';

/// عرض الإجابات.
///
/// مرحلتان بشاشة واحدة: العرض (قراءة وضحك، بلا أزرار) ثم الاعتراض (يظهر ❌
/// بجانب إجابات غيرك). الفصل مقصود — لو ظهرت الأزرار من أول لحظة لانشغل
/// الناس بالحكم بدل القراءة، وهي أمتع ما في اللعبة.
///
/// على الشاشة العريضة بطاقات اللاعبين شبكة: مقارنة إجابات الجميع بلمحة هي
/// ما يولّد الضحك، والتمرير بين البطاقات يقتله.
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
        // الشريط ثابت فوق القائمة لا داخلها: عدد الاعتراضات الباقية يجب أن
        // يبقى ظاهراً مهما مرّر اللاعب.
        if (allowObjections)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.08),
              border: Border(bottom: BorderSide(color: palette.outline)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.wide),
                child: Row(
                  children: [
                    Icon(
                      Icons.gavel_outlined,
                      size: 18,
                      color: palette.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        objectionsLeft > 0
                            ? 'اضغط ❌ على أي إجابة مشكوك فيها — ضلّ إلك $objectionsLeft اعتراضات'
                            // عقوبة الاعتراض الفاشل −5 هي ما يمنع الاعتراض الكيدي.
                            : 'خلصت اعتراضاتك بهالجولة',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: HarfPaneList(
            maxWidth: ContentWidth.wide,
            top: 16,
            children: [
              ResponsiveGrid(
                minItemWidth: 300,
                maxColumns: 3,
                spacing: 12,
                // البطاقات بعدد الخانات نفسه فارتفاعها متقارب أصلاً، وقياس
                // الارتفاع الذاتي لا يُؤمن مع تلميحات أزرار الاعتراض.
                equalHeight: false,
                children: [
                  for (final row in round.rows)
                    _PlayerAnswers(
                      row: row,
                      config: config,
                      isMe: row.userId == cubit.viewerId,
                      isStopper: row.userId == round.stopBy,
                      allowObjections: allowObjections,
                      objectionsLeft: objectionsLeft,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerAnswers extends StatelessWidget {
  const _PlayerAnswers({
    required this.row,
    required this.config,
    required this.isMe,
    required this.isStopper,
    required this.allowObjections,
    required this.objectionsLeft,
  });

  final AnswerRow row;
  final HarfConfig config;
  final bool isMe;
  final bool isStopper;
  final bool allowObjections;
  final int objectionsLeft;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HarfGameCubit>();
    final palette = context.palette;

    return SectionCard(
      title: row.username,
      trailing: isMe || isStopper
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMe) const InfoChip('إنت'),
                if (isMe && isStopper) const SizedBox(width: 6),
                if (isStopper) InfoChip('ضغط ستوب', color: palette.accent),
              ],
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (var index = 0; index < config.columns.length; index++) ...[
            if (index > 0) Divider(height: 1, color: palette.outline),
            _AnswerLine(
              label: config.labelOf(config.columns[index]),
              value: row.answers[config.columns[index]] ?? '',
              // لا اعتراض على إجابتك، ولا على خانة فارغة (هي صفر أصلاً).
              canObject:
                  allowObjections &&
                  !isMe &&
                  objectionsLeft > 0 &&
                  (row.answers[config.columns[index]] ?? '').trim().isNotEmpty,
              objected: cubit.hasObjectedTo(row.userId, config.columns[index]),
              onObject: () => cubit.raiseObjection(
                targetUserId: row.userId,
                column: config.columns[index],
              ),
            ),
          ],
        ],
      ),
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

    return ConstrainedBox(
      // ارتفاع ثابت للسطر بزر أو بدونه: الأسطر لا تقفز حين تظهر أزرار
      // الاعتراض مع بداية مرحلته.
      constraints: const BoxConstraints(minHeight: 44),
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
                color: objected ? palette.danger : palette.textMuted,
              ),
              tooltip: objected ? 'اعترضت' : 'اعتراض',
            ),
        ],
      ),
    );
  }
}
