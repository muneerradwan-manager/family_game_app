import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/harf_game_cubit.dart';
import '../../model/harf_models.dart';
import 'harf_layout.dart';

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
              // شريط الستوب تحت القائمة يحجز شريط النظام، فلا تضيفه القائمة.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: HarfPaneList(
                  maxWidth: ContentWidth.wide,
                  top: 18,
                  children: [
                    SectionCard(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      // الأعمدة من العرض المتاح فعلاً: عمود على الجوال، اثنان
                      // على التابلت، وثلاثة بجانب العمود الجانبي على الشاشة
                      // الكبيرة — ستة حقول في عمود واحد تعني تمريراً أثناء سباق
                      // مع المؤقّت، والتمرير هنا يكلّف جولة.
                      child: ResponsiveGrid(
                        minItemWidth: 240,
                        maxColumns: 3,
                        spacing: 12,
                        equalHeight: false,
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
                              onChanged: (value) =>
                                  cubit.setAnswer(column, value),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // SafeArea دائماً: هي التي تحجز ارتفاع شريط تنقّل النظام حين لا
            // يوجد تذييل تحت اللعب (وتصير صفراً حين يوجد).
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.outline)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ContentWidth.form,
                      ),
                      child: _StopButton(
                        enabled: cubit.canPressStop,
                        onPressed: cubit.pressStop,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // عدّاد الـ10 ثواني: كبير أحمر في المنتصف — أعلى لحظة توتّر في الجولة.
        if (isGrace)
          Positioned.fill(
            child: Container(
              color: palette.background.withValues(alpha: 0.6),
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
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: palette.outline),
                        boxShadow: AppShadows.card(palette),
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
                  : Icon(Icons.check_circle, size: 20, color: palette.success)),
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
    final radius = BorderRadius.circular(AppRadius.card);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 56,
      decoration: BoxDecoration(
        color: enabled ? palette.accent : palette.surfaceAlt,
        borderRadius: radius,
        border: enabled ? null : Border.all(color: palette.outline),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Text(
              enabled ? 'ستوب!' : 'كمّل كل الخانات',
              style: TextStyle(
                color: enabled ? Colors.white : palette.textMuted,
                fontSize: enabled ? 20 : 17,
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
  Widget build(BuildContext context) => HarfPaneCenter(
    child: SectionCard(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: context.palette.primary,
            ),
          ),
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
