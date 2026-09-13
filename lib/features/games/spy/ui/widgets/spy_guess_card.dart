import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../cubit/spy_game_cubit.dart';

/// فرصة الجاسوس الأخيرة.
///
/// انكشف بالتصويت، وبقيت له رمية واحدة: لو خمّن الكلمة صح فاز رغم انكشافه.
/// الخيارات كلها من المجموعة نفسها — فالتخمين اجتهاد لا حظّ محض، وهو أيضاً
/// ما يحسم مشكلة مطابقة النص العربي (الـ التعريف، الهمزات، الجمع).
class SpyGuessCard extends StatefulWidget {
  const SpyGuessCard({
    super.key,
    required this.options,
    required this.isMe,
    required this.spyUsername,
  });

  final List<String> options;
  final bool isMe;
  final String? spyUsername;

  @override
  State<SpyGuessCard> createState() => _SpyGuessCardState();
}

class _SpyGuessCardState extends State<SpyGuessCard> {
  String? _picked;

  void _pick(String word) {
    if (_picked != null) return;

    setState(() => _picked = word);
    context.read<SpyGameCubit>().submitGuess(word);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🕵️',
          style: TextStyle(fontSize: 52),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          widget.isMe ? 'انكشفت! آخر فرصة' : 'فرصة الجاسوس الأخيرة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isMe
              ? 'خمّن الكلمة الصحيحة وبتفوز رغم إنهم مسكوك.'
              : '${widget.spyUsername ?? 'الجاسوس'} عم يخمّن الكلمة — إذا صحّت بيفوز عليكم!',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.6),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final word in widget.options)
              _WordOption(
                word: word,
                selected: word == _picked,
                dimmed: _picked != null && word != _picked,
                onTap: widget.isMe && _picked == null
                    ? () => _pick(word)
                    : null,
              ),
          ],
        ),
        if (!widget.isMe) ...[
          const SizedBox(height: 22),
          SectionCard(
            color: palette.surfaceAlt,
            child: Text(
              'ما بتقدر تتدخل — تفرّج وشوف إذا رح يصيبها 🤞',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, height: 1.5),
            ),
          ),
        ] else if (_picked != null) ...[
          const SizedBox(height: 22),
          Text(
            'اخترت "$_picked" — عم ننطر الحكم...',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

class _WordOption extends StatelessWidget {
  const _WordOption({
    required this.word,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final String word;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.18)
            : palette.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minWidth: 118),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? palette.accent : palette.outline,
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              word,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: selected ? palette.accent : palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
