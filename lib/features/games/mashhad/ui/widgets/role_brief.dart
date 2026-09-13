import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../model/mashhad_models.dart';

/// بطاقة الدور السرّي — أول ما يراه اللاعب في كل مشهد.
///
/// مقلوبة حتى يلمسها صاحبها: هدفك وسرّك يصلان جهازك وحده من السيرفر، لكن
/// الجهاز قد يكون بيد طفل في حضن أمه. لمسة واحدة تفصل بين «وصل» و«انعرض».
///
/// لا تمرّر نفسها: شاشة اللعب تضعها في مسرحها القابل للتمرير.
class RoleBrief extends StatefulWidget {
  const RoleBrief({
    super.key,
    required this.title,
    required this.setup,
    required this.categoryLabel,
    required this.categoryEmoji,
    this.role,
    this.isSpectator = false,
  });

  final String title;
  final String setup;
  final String? categoryLabel;
  final String? categoryEmoji;
  final MyRole? role;
  final bool isSpectator;

  @override
  State<RoleBrief> createState() => _RoleBriefState();
}

class _RoleBriefState extends State<RoleBrief>
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
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الحبكة عامة للجميع — وهي أرضية المشهد المشتركة.
        SectionCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (widget.categoryLabel != null) ...[
                InfoChip(
                  '${widget.categoryEmoji ?? ''} ${widget.categoryLabel}',
                ),
                const SizedBox(height: 12),
              ],
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.setup,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textMuted,
                  height: 1.6,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (widget.isSpectator || widget.role == null)
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
                          child: _RoleFace(role: widget.role!),
                        ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: _revealed ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Text(
            'ما حدا بيعرف هدفك — ولا إنت بتعرف أهدافهم. '
            'خلّي الأحداث تمشي لصالحك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// ظهر البطاقة — اللحظة الوحيدة التي تبقى فيها ترويسة ملوّنة: هي «المفاجأة».
class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎭', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text(
            'اضغط لتشوف دورك',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
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

Color _difficultyTone(AppPalette palette, String difficulty) =>
    switch (difficulty) {
      'hard' => palette.danger,
      'easy' => palette.success,
      _ => palette.primary,
    };

class _RoleFace extends StatelessWidget {
  const _RoleFace({required this.role});

  final MyRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = _difficultyTone(palette, role.difficulty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: Border.all(color: tone, width: 2),
        boxShadow: AppShadows.card(palette),
      ),
      child: Column(
        children: [
          Text('إنت', style: TextStyle(color: palette.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            role.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          InfoChip(role.difficultyLabel, color: tone),
          const SizedBox(height: 18),
          ..._roleBlocks(palette, role),
        ],
      ),
    );
  }
}

List<Widget> _roleBlocks(AppPalette palette, MyRole role) => [
  _GoalBlock(
    emoji: '✅',
    label: 'هدفك الرئيسي',
    text: role.goal,
    tone: palette.primary,
  ),
  if (role.bonus != null) ...[
    const SizedBox(height: 10),
    _GoalBlock(
      emoji: '⭐',
      label: 'هدف إضافي',
      text: role.bonus!,
      tone: palette.secondary,
    ),
  ],
  if (role.secret != null) ...[
    const SizedBox(height: 10),
    _GoalBlock(
      emoji: '🤫',
      label: 'معلومتك السرّية',
      text: role.secret!,
      tone: palette.accent,
    ),
  ],
];

/// دوري أثناء المشهد في العمود الجانبي على الشاشة العريضة.
///
/// هو نفس ما قرأه اللاعب قبل المشهد على جهازه وحده — ولا يُعرض إلا لصاحبه
/// (يأتي من `myRole` في لقطته). الشاشة الكبيرة تتسع له كاملاً بدل سطر الهدف
/// المختصر فوق الشات على الجوال.
class RoleSideCard extends StatelessWidget {
  const RoleSideCard({super.key, required this.role});

  final MyRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = _difficultyTone(palette, role.difficulty);

    return SectionCard(
      title: '🎭 ${role.name}',
      trailing: InfoChip(role.difficultyLabel, color: tone),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _roleBlocks(palette, role),
      ),
    );
  }
}

class _GoalBlock extends StatelessWidget {
  const _GoalBlock({
    required this.emoji,
    required this.label,
    required this.text,
    required this.tone,
  });

  final String emoji;
  final String label;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpectatorCard extends StatelessWidget {
  const _SpectatorCard();

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      children: [
        const Text('👀', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(
          'ما إلك دور بهالمشهد — بتقدر تقرأ وتتفرّج.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textMuted, height: 1.5),
        ),
      ],
    ),
  );
}
