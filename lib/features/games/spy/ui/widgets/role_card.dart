import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';

/// بطاقة الدور السرّي — أول ما يراه اللاعب، ومنها تبدأ اللعبة كلها.
///
/// مقلوبة حتى يلمسها صاحبها: الكلمة تصل الجهاز وحده من السيرفر، لكن الجهاز
/// قد يكون بيد طفل في حضن أمه. لمسة واحدة تفصل بين "وصلت" و"انعرضت".
class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.isSpy,
    required this.word,
    required this.categoryLabel,
    required this.categoryEmoji,
    this.isSpectator = false,
  });

  final bool isSpy;

  /// الكلمة السرّية — null للجاسوس وللمتفرّج.
  final String? word;

  final String? categoryLabel;
  final String? categoryEmoji;
  final bool isSpectator;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  bool get _revealed => _flip.value > 0.5;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_flip.isAnimating || _revealed) return;

    _flip.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: context.contentPadding(
          top: 24,
          bottom: 24,
          minHorizontal: 24,
          maxWidth: ContentWidth.form,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isSpectator ? 'إنت عم تتفرج' : 'ورقتك السرّية',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isSpectator
                  ? 'اللعبة بلّشت — تابع الأسئلة وحاول تكتشفه إنت كمان.'
                  : 'المجموعة معروفة للكل. الكلمة لأ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (widget.isSpectator)
              const _SpectatorCard()
            else
              AnimatedBuilder(
                animation: _flip,
                builder: (context, _) {
                  final angle = _flip.value * math.pi;

                  return GestureDetector(
                    onTap: _reveal,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0014)
                        ..rotateY(angle),
                      child: angle < math.pi / 2
                          ? const _CardBack()
                          : Transform(
                              alignment: Alignment.center,
                              // الوجه الثاني يُرسم معكوساً بحكم الدوران؛
                              // نعكسه مرة ثانية ليُقرأ صحيحاً.
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _CardFace(
                                isSpy: widget.isSpy,
                                word: widget.word,
                                categoryLabel: widget.categoryLabel,
                                categoryEmoji: widget.categoryEmoji,
                              ),
                            ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _revealed ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                widget.isSpy
                    ? 'مهمتك: استنتج الكلمة من الأسئلة، ومثّل إنك بتعرفها.'
                    : 'لا تقول الكلمة! جاوب بطريقة تفهّم الباقيين إنك بتعرفها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.textMuted,
                  height: 1.6,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.32),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎴', style: TextStyle(fontSize: 58)),
          const SizedBox(height: 14),
          const Text(
            'اضغط لتشوف ورقتك',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'خبّي الشاشة عن اللي جنبك',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.isSpy,
    required this.word,
    required this.categoryLabel,
    required this.categoryEmoji,
  });

  final bool isSpy;
  final String? word;
  final String? categoryLabel;
  final String? categoryEmoji;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = isSpy ? palette.accent : palette.primary;

    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: tone, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isSpy ? '🕵️' : (categoryEmoji ?? '🗝️'),
            style: const TextStyle(fontSize: 46),
          ),
          const SizedBox(height: 12),
          if (isSpy) ...[
            Text(
              'إنت الجاسوس!',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ما بتعرف الكلمة — بس بتعرف إنها ${categoryLabel ?? 'من المجموعة'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            ),
          ] else ...[
            Text(
              'الكلمة',
              style: TextStyle(color: palette.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                word ?? '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            InfoChip(categoryLabel ?? '', icon: Icons.category_outlined),
          ],
        ],
      ),
    );
  }
}

class _SpectatorCard extends StatelessWidget {
  const _SpectatorCard();

  @override
  Widget build(BuildContext context) => SectionCard(
    color: context.palette.surfaceAlt,
    child: Column(
      children: [
        const Text('👀', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(
          'ما إلك ورقة — وصلت بعد ما بلّشوا.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textMuted, height: 1.5),
        ),
      ],
    ),
  );
}
