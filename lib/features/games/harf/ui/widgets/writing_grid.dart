import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../cubit/harf_game_cubit.dart';
import '../../model/harf_models.dart';

/// مرحلة الكتابة — ومعها مهلة الـ10 ثواني بعد الستوب.
///
/// الإجابات تُرسَل مع كل تغيير: انقطاع النت في منتصف الجولة لا يضيّع ما كُتب،
/// ولا يمكن إرسال شيء بعد الإقفال. واللصق معطّل حتى لا يُنسخ جواب جاهز.
class WritingGrid extends StatefulWidget {
  const WritingGrid({super.key});

  @override
  State<WritingGrid> createState() => _WritingGridState();
}

class _WritingGridState extends State<WritingGrid> {
  final _controllers = <String, TextEditingController>{};
  int? _boundRound;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  /// الحقول تُبنى مرة لكل جولة: إعادة بنائها مع كل حرف تُفقد مؤشّر الكتابة.
  void _syncControllers(HarfGameState state) {
    final round = state.round!;

    if (_boundRound == round.number) return;

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers
      ..clear()
      ..addEntries(
        state.snapshot!.config.columns.map(
          (column) => MapEntry(
            column,
            TextEditingController(text: state.draft[column] ?? ''),
          ),
        ),
      );

    _boundRound = round.number;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HarfGameCubit>();
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final palette = context.palette;
    final isGrace = round.phase == HarfPhase.grace;

    _syncControllers(state);

    if (snapshot.me.isSpectator) {
      return _SpectatorNotice(letter: round.letter ?? '');
    }

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView(
                padding: context.contentPadding(top: 18, bottom: 12),
                children: [
                  // عمودان على الشاشة العريضة: ستة حقول في عمود واحد تعني
                  // تمريراً أثناء سباق مع المؤقّت، والتمرير هنا يكلّف جولة.
                  AdaptiveColumns(
                    children: [
                      for (final column in snapshot.config.columns)
                        _AnswerField(
                          label: snapshot.config.labelOf(column),
                          controller: _controllers[column]!,
                          // في مهلة الـ10 ثواني: إكمال الفارغ فقط، لا تعديل
                          // على المكتوب.
                          locked:
                              isGrace &&
                              (state.draft[column] ?? '').trim().isNotEmpty,
                          onChanged: (value) => cubit.setAnswer(column, value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: context.contentPadding(top: 0, bottom: 12),
                child: _StopButton(
                  enabled: cubit.canPressStop,
                  onPressed: cubit.pressStop,
                ),
              ),
            ),
          ],
        ),
        // عدّاد الـ10 ثواني: كبير أحمر في المنتصف — أعلى لحظة توتّر في الجولة.
        if (isGrace)
          Positioned.fill(
            child: Container(
              color: palette.background.withValues(alpha: 0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GraceCountdown(
                      deadline: round.deadline,
                      clockSkewMs: state.clockSkewMs,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        round.stopBy == null
                            ? 'خلص الوقت!'
                            : '${snapshot.playerById(round.stopBy!)?.username ?? 'حدا'} ضغط ستوب!',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'كمّل الفاضي بس — ما بتقدر تعدّل المكتوب',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.label,
    required this.controller,
    required this.locked,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool locked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TextField(
      controller: controller,
      enabled: !locked,
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      maxLength: 40,
      // منع اللصق: قائمة السياق مطفأة والتحديد التفاعلي معها.
      enableInteractiveSelection: false,
      contextMenuBuilder: null,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: locked
            ? Icon(Icons.lock_outline, size: 18, color: palette.textMuted)
            : (controller.text.trim().isEmpty
                  ? null
                  : Icon(
                      Icons.check_circle,
                      size: 20,
                      color: palette.secondary,
                    )),
      ),
    );
  }
}

/// الزر رمادي مقفول حتى تمتلئ كل الخانات — الستوب قرار لا سباق أعمى.
class _StopButton extends StatelessWidget {
  const _StopButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 62,
      decoration: BoxDecoration(
        color: enabled ? palette.accent : palette.outline,
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Text(
              enabled ? 'ستوب!' : 'كمّل كل الخانات',
              style: TextStyle(
                color: enabled ? Colors.white : context.palette.textMuted,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpectatorNotice extends StatelessWidget {
  const _SpectatorNotice({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 90,
              fontWeight: FontWeight.w900,
              color: context.palette.primary,
            ),
          ),
          const SizedBox(height: 12),
          const EmptyState(
            emoji: '👀',
            title: 'اللعبة بلّشت',
            subtitle: 'تقدر تتفرج، ورح تنضم باللعبة الجاية.',
          ),
        ],
      ),
    ),
  );
}
