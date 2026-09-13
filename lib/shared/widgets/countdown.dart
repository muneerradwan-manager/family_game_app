import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// عدّاد مرحلة.
///
/// لا يعدّ من صفر عند البناء: يحسب المتبقي من ختم السيرفر مصحّحاً بفرق
/// الساعة. من يفتح الشاشة متأخراً بثانيتين يرى العدّاد نفسه الذي يراه
/// الآخرون، ومن أعاد الاتصال يلتقط اللحظة الصحيحة فوراً.
class PhaseCountdown extends StatefulWidget {
  const PhaseCountdown({
    super.key,
    required this.deadline,
    required this.clockSkewMs,
    this.totalSeconds,
    this.onSecondTick,
    this.onFinished,
    this.builder,
    this.size = 62,
    this.urgentBelow = 15,
  });

  /// موعد انتهاء المرحلة بتوقيت السيرفر (ميلي ثانية).
  final int deadline;

  /// فرق ساعة الجهاز عن السيرفر.
  final int clockSkewMs;

  /// مدة المرحلة كاملة — لرسم الحلقة. null يعني رقماً بلا حلقة.
  final int? totalSeconds;

  /// يُستدعى مرة عند كل ثانية تنقص — مصدر صوت التكّة.
  final void Function(int remainingSeconds)? onSecondTick;

  final VoidCallback? onFinished;

  final Widget Function(BuildContext context, int remainingSeconds)? builder;

  final double size;

  /// تحت هذا الحد يصير العدّاد أحمر (وتبدأ التكّة).
  final int urgentBelow;

  @override
  State<PhaseCountdown> createState() => _PhaseCountdownState();
}

class _PhaseCountdownState extends State<PhaseCountdown> {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _remainingMs = 0;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    _recompute();
    // نبض أسرع من ثانية حتى تتحرك الحلقة بسلاسة لا بقفزات.
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _recompute(),
    );
  }

  @override
  void didUpdateWidget(PhaseCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deadline != widget.deadline) {
      _finishedNotified = false;
      _recompute();
    }
  }

  void _recompute() {
    final now = DateTime.now().millisecondsSinceEpoch + widget.clockSkewMs;
    final remainingMs = (widget.deadline - now).clamp(0, 1 << 31);
    final seconds = (remainingMs / 1000).ceil();

    if (seconds != _remainingSeconds && seconds > 0) {
      widget.onSecondTick?.call(seconds);
    }

    if (remainingMs == 0 && !_finishedNotified) {
      _finishedNotified = true;
      widget.onFinished?.call();
    }

    if (!mounted) return;

    setState(() {
      _remainingMs = remainingMs;
      _remainingSeconds = seconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return widget.builder!(context, _remainingSeconds);
    }

    final palette = context.palette;
    final urgent = _remainingSeconds <= widget.urgentBelow;
    final color = urgent ? palette.accent : palette.primary;

    final total = widget.totalSeconds;
    final progress = total == null || total == 0
        ? null
        : (_remainingMs / (total * 1000)).clamp(0.0, 1.0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null)
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: palette.outline,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          AnimatedScale(
            scale: urgent && _remainingSeconds % 2 == 1 ? 1.14 : 1,
            duration: const Duration(milliseconds: 220),
            child: Text(
              '$_remainingSeconds',
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                fontSize: widget.size * 0.42,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عدّاد الـ10 ثواني بعد الستوب: كبير وأحمر في منتصف الشاشة.
class GraceCountdown extends StatelessWidget {
  const GraceCountdown({
    super.key,
    required this.deadline,
    required this.clockSkewMs,
    this.onSecondTick,
  });

  final int deadline;
  final int clockSkewMs;
  final void Function(int remainingSeconds)? onSecondTick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PhaseCountdown(
      deadline: deadline,
      clockSkewMs: clockSkewMs,
      onSecondTick: onSecondTick,
      builder: (context, remaining) => TweenAnimationKey(
        value: remaining,
        child: Container(
          width: 128,
          height: 128,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.45),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Text(
            '$remaining',
            style: const TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 60,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// نبضة عند كل تغيّر قيمة — تجعل الرقم يُحسّ لا يُقرأ فقط.
class TweenAnimationKey extends StatelessWidget {
  const TweenAnimationKey({
    super.key,
    required this.value,
    required this.child,
  });

  final int value;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(value),
    tween: Tween(begin: 1.25, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: child,
  );
}

/// رقم يرتفع بحركة بدل أن يقفز — للوحة النقاط.
class AnimatedScore extends StatelessWidget {
  const AnimatedScore(this.value, {super.key, this.style, this.duration});

  final int value;
  final TextStyle? style;
  final Duration? duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: duration ?? const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, animated, _) => Text(
      '${animated.round()}',
      style: (style ?? const TextStyle()).copyWith(
        fontFamily: AppTheme.displayFontFamily,
      ),
    ),
  );
}
