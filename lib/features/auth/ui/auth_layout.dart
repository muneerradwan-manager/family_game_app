import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/responsive.dart';
import '../../games/game_kind.dart';

/// هيكل شاشتي الدخول والتسجيل — كصفحة دخول لوحة الإدارة:
///
/// * **جوال:** النموذج على الخلفية.
/// * **تابلت:** النموذج في بطاقة موسّطة.
/// * **شاشة كبيرة:** نصفان — لوحة بتدرّج الثيم تعرّف بالتطبيق وألعابه،
///   والنموذج في بطاقة.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  static const _splitWidth = 900.0;

  static bool isSplit(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _splitWidth;

  @override
  Widget build(BuildContext context) {
    if (isSplit(context)) {
      return Row(
        children: [
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SectionCard(
                    padding: const EdgeInsets.all(32),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final card = !context.isPhone;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: context.listPadding(
            top: 24,
            bottom: 32,
            minHorizontal: card ? 32 : 24,
            maxWidth: card ? 520 : ContentWidth.form,
          ),
          child: card
              ? SectionCard(padding: const EdgeInsets.all(32), child: child)
              : child,
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: context.palette.headerGradient,
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎲', style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                const Text(
                  'ألعاب العيلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'العبوا سوا\nوانتو بعيدين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ألعاب لحظية للعيلة والشباب — كل واحد من جوّاله، وكلكم بنفس الغرفة.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final game in GameKind.all)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${game.icon}  ${game.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Text(
              'سهرة العيلة صارت أسهل',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
