import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../model/harf_models.dart';

/// كشف الحرف: دوران سريع ثم ثبات، وعدّ تنازلي 3·2·1 موحّد للجميع.
///
/// الأنيميشن محلي لكن الحرف والتوقيت من السيرفر، فالجميع يرى الحرف نفسه في
/// اللحظة نفسها — لا يسبق جهاز جهازاً.
class LetterStage extends StatefulWidget {
  const LetterStage({super.key, required this.letter, required this.round});

  final String letter;
  final HarfRound round;

  @override
  State<LetterStage> createState() => _LetterStageState();
}

class _LetterStageState extends State<LetterStage>
    with SingleTickerProviderStateMixin {
  static const _spinLetters = [
    'ا',
    'ب',
    'ت',
    'س',
    'ع',
    'ف',
    'ق',
    'ك',
    'ل',
    'م',
    'ن',
    'ه',
    'و',
    'ي',
  ];

  late final AnimationController _controller;
  Timer? _spinTimer;
  String _shown = 'ا';
  bool _settled = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final random = math.Random();
    var ticks = 0;

    // دوران قصير: ~1.1 ثانية من أصل الثلاث، ثم يثبت الحرف ويبدأ العدّ.
    _spinTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      ticks++;

      if (ticks >= 16) {
        timer.cancel();

        if (!mounted) return;

        setState(() {
          _shown = widget.letter;
          _settled = true;
        });

        _controller.forward();

        return;
      }

      if (!mounted) return;

      setState(
        () => _shown = _spinLetters[random.nextInt(_spinLetters.length)],
      );
    });
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _settled ? 1 : 0.86,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: palette.headerGradient),
                borderRadius: BorderRadius.circular(44),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(
                      alpha: _settled ? 0.4 : 0.15,
                    ),
                    blurRadius: 34,
                    spreadRadius: 3,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _shown,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 108,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _settled ? 'استعدوا!' : 'عم نسحب...',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
