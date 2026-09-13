import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../model/harf_models.dart';

/// بطاقة النتيجة المُعدّة للمشاركة كصورة.
///
/// مرسومة بمقاس ثابت لا بمقاس الشاشة: الصورة المشتركة يجب أن تخرج نفسها من
/// هاتف صغير ومن جهاز لوحي. ولها ألوانها الصريحة لأنها تُرسم خارج شجرة
/// الواجهة حيث لا يوجد Theme.
class ResultShareCard extends StatelessWidget {
  const ResultShareCard({
    super.key,
    required this.result,
    required this.palette,
    required this.channelName,
  });

  static const width = 900.0;

  final HarfResult result;
  final AppPalette palette;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    final scores = result.finalScores;

    return Container(
      width: width,
      color: palette.background,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس أبيض بعلامة متدرّجة صغيرة — نفس لغة شاشات التطبيق، فالصورة
          // المشتركة تشبه ما رآه اللاعبون.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 32),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.outline, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: palette.headerGradient,
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🔠', style: TextStyle(fontSize: 50)),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لعبة الحروف',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        channelName,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          for (var index = 0; index < scores.length; index++) ...[
            _row(index + 1, scores[index]),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          Text(
            '${result.roundsPlayed} جولات · ${scores.length} لاعبين'
            '${result.decidedByTiebreak ? ' · حُسمت بجولة الحسم' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _row(int rank, Standing standing) {
    final isWinner = standing.userId == result.winnerId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        color: isWinner
            ? palette.primary.withValues(alpha: 0.12)
            : palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isWinner ? palette.primary : palette.outline,
          width: isWinner ? 3 : 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(switch (rank) {
              1 => '🥇',
              2 => '🥈',
              3 => '🥉',
              _ => '$rank',
            }, style: TextStyle(fontSize: 30, color: palette.textMuted)),
          ),
          Expanded(
            child: Text(
              standing.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
          Text(
            '${standing.total}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isWinner ? palette.primary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// يرسم البطاقة خارج الشاشة ويعيدها PNG.
///
/// نرسمها بمعزل بدل التقاط الشاشة: لقطة الشاشة تحمل شريط الحالة وأزرار
/// النظام ومقاس الجهاز، والمطلوب صورة نظيفة تُرسل في واتساب. ونضعها في
/// طبقة Overlay خارج حدود الشاشة بدل بناء شجرة عرض يدوية — فتمر بنفس خط
/// الرسم الطبيعي وتظهر الخطوط والصور كما تظهر في التطبيق.
Future<Uint8List?> renderShareCard({
  required BuildContext context,
  required Widget card,
  double pixelRatio = 2,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) return null;

  final boundaryKey = GlobalKey();

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -(ResultShareCard.width + 200),
      top: 0,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(type: MaterialType.transparency, child: card),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  try {
    // إطاران: الأول يبني الشجرة، والثاني يضمن أن الرسم اكتمل قبل الالتقاط.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary = boundaryKey.currentContext?.findRenderObject();

    if (boundary is! RenderRepaintBoundary) return null;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();

    return bytes?.buffer.asUint8List();
  } catch (_) {
    // فشل الالتقاط لا يمنع المشاركة: المتصل يرجع للنص.
    return null;
  } finally {
    entry.remove();
  }
}
