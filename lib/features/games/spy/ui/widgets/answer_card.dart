import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../cubit/spy_game_cubit.dart';
import '../../model/spy_models.dart';

/// سُئلت — والكل ناطر جوابك.
///
/// أصعب لحظة في اللعبة لمن يعرف الكلمة: جواب واضح جداً يهديها للجاسوس،
/// وجواب غامض جداً يجعلك أنت المشتبه به.
class AnswerCard extends StatefulWidget {
  const AnswerCard({super.key, required this.turn});

  final SpyTurn turn;

  @override
  State<AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<AnswerCard> {
  final _controller = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_sent || _controller.text.trim().isEmpty) return;

    setState(() => _sent = true);
    context.read<SpyGameCubit>().answerQuestion(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isSpy = context.read<SpyGameCubit>().state.snapshot?.me.isSpy == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '🙋 سألوك!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          color: palette.primary.withValues(alpha: 0.08),
          child: Column(
            children: [
              Text(
                '${widget.turn.askerUsername} بيسأل',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.turn.question ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          enabled: !_sent,
          autofocus: true,
          maxLength: 140,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: const InputDecoration(
            hintText: 'جاوب بطريقة ذكية...',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _sent ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(_sent ? 'انبعت' : 'ابعت الجواب'),
        ),
        const SizedBox(height: 12),
        Text(
          isSpy
              ? 'إنت الجاسوس — جاوب شي عام يمشي الحال، وراقب ردّات الفعل.'
              : 'لا تكشف الكلمة، بس خلّي جوابك يثبت إنك بتعرفها.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
