import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../model/spy_models.dart';

/// بطاقة نتيجة الجاسوس المُعدّة للمشاركة كصورة.
///
/// مرسومة بمقاس ثابت لا بمقاس الشاشة: الصورة المشتركة يجب أن تخرج نفسها من
/// هاتف صغير ومن جهاز لوحي. ولها ألوانها الصريحة لأنها تُرسم خارج شجرة
/// الواجهة حيث لا يوجد Theme.
class SpyShareCard extends StatelessWidget {
  const SpyShareCard({
    super.key,
    required this.result,
    required this.palette,
    required this.channelName,
  });

  static const width = 900.0;

  final SpyResult result;
  final AppPalette palette;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: palette.background,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.headerGradient,
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Text(
                  result.spyWon ? '🕵️' : '🎉',
                  style: const TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لعبة الجاسوس',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  channelName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  result.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          Row(
            children: [
              Expanded(
                child: _Fact(
                  palette: palette,
                  label: 'الكلمة كانت',
                  value: result.word ?? '—',
                  emoji: result.categoryEmoji ?? '🗝️',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _Fact(
                  palette: palette,
                  label: 'الجاسوس كان',
                  value: result.spyUsername ?? '—',
                  emoji: '🕵️',
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            'اللاعبين',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (final player in result.players)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              decoration: BoxDecoration(
                color: player.wasSpy
                    ? palette.accent.withValues(alpha: 0.12)
                    : palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: player.wasSpy ? palette.accent : palette.outline,
                  width: player.wasSpy ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    player.won ? '🏆' : '·',
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      player.username,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    player.wasSpy ? 'الجاسوس' : 'لاعب',
                    style: TextStyle(
                      color: player.wasSpy ? palette.accent : palette.textMuted,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '${result.roundsPlayed} جولات · ${result.players.length} لاعبين',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.palette,
    required this.label,
    required this.value,
    required this.emoji,
  });

  final AppPalette palette;
  final String label;
  final String value;
  final String emoji;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
    decoration: BoxDecoration(
      color: palette.surfaceAlt,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 34)),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: palette.textMuted, fontSize: 19)),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
