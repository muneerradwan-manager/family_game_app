import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';
import 'responsive.dart';

/// لمعة تمرّ على هيكل المحتوى أثناء التحميل.
///
/// الهيكل بشكل الصفحة الحقيقية أفضل من دائرة تدور في الوسط: المستخدم يعرف
/// ماذا ينتظر، والصفحة لا «تقفز» حين يصل المحتوى لأن مكانه محجوز مسبقاً.
///
/// كل لمعة تبدأ من ساعة مشتركة، فعدة بطاقات على الشاشة تلمع معاً كموجة
/// واحدة لا كأضواء متفرّقة. ومن طلب تقليل الحركة في نظامه يرى الهيكل ثابتاً.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller
        ..value =
            (DateTime.now().millisecondsSinceEpoch % _period.inMilliseconds) /
            _period.inMilliseconds
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final base = palette.isDark
        ? Color.lerp(palette.surfaceAlt, palette.surface, 0.2)!
        : Color.lerp(palette.outline, palette.surfaceAlt, 0.45)!;
    final highlight = palette.isDark
        ? Color.lerp(palette.surfaceAlt, Colors.white, 0.12)!
        : Color.lerp(palette.surface, Colors.white, 0.6)!;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.3, 0.5, 0.7],
          transform: _SlidingGradient(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// قطعة من الهيكل. لونها لا يهم: اللمعة ترسم فوقها بلونها.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Colors.black,
      shape: BoxShape.circle,
    ),
  );
}

/// سطر بنسبة من العرض المتاح — لا يطفح في عمود ضيق كما يطفح عرض ثابت.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: widthFactor,
    child: SkeletonBox(width: double.infinity, height: height),
  );
}

/// رأس صفحة قيد التحميل.
class PageHeaderSkeleton extends StatelessWidget {
  const PageHeaderSkeleton({super.key, this.avatar = false});

  final bool avatar;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Row(
      children: [
        if (avatar) ...[
          const SkeletonBox(width: 52, height: 52, radius: 14),
          const SizedBox(width: 14),
        ],
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(widthFactor: 0.45, height: 24),
              SizedBox(height: 10),
              SkeletonLine(widthFactor: 0.3, height: 13),
            ],
          ),
        ),
      ],
    ),
  );
}

class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: EdgeInsets.all(compact ? 12 : 18),
    child: const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(widthFactor: 0.55),
          SizedBox(height: 10),
          SkeletonBox(width: 44, height: 24),
        ],
      ),
    ),
  );
}

class ChannelCardSkeleton extends StatelessWidget {
  const ChannelCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SkeletonBox(width: 48, height: 48, radius: 14),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(widthFactor: 0.6, height: 16),
                    SizedBox(height: 8),
                    SkeletonLine(widthFactor: 0.35),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 28),
          Row(
            children: [
              SkeletonBox(width: 96, height: 22, radius: 999),
              Spacer(),
              SkeletonBox(width: 44, height: 22, radius: 999),
            ],
          ),
        ],
      ),
    ),
  );
}

class GameCardSkeleton extends StatelessWidget {
  const GameCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 56, height: 56, radius: 16),
              Spacer(),
              SkeletonBox(width: 110, height: 22, radius: 999),
            ],
          ),
          SizedBox(height: 18),
          SkeletonLine(widthFactor: 0.4, height: 18),
          SizedBox(height: 12),
          SkeletonLine(widthFactor: 0.95),
          SizedBox(height: 7),
          SkeletonLine(widthFactor: 0.7),
          SizedBox(height: 20),
          SkeletonLine(widthFactor: 0.2),
        ],
      ),
    ),
  );
}

/// بطاقة قائمة (أعضاء، سجل، لاعبين) قيد التحميل.
class ListCardSkeleton extends StatelessWidget {
  const ListCardSkeleton({super.key, this.rows = 4, this.avatar = true});

  final int rows;
  final bool avatar;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Shimmer(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: SkeletonLine(widthFactor: 0.3, height: 16),
          ),
          for (var index = 0; index < rows; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  if (avatar) ...[
                    const SkeletonCircle(size: 40),
                    const SizedBox(width: 12),
                  ] else ...[
                    const SkeletonBox(width: 40, height: 40, radius: 10),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(widthFactor: index.isEven ? 0.5 : 0.4),
                        const SizedBox(height: 7),
                        SkeletonLine(
                          widthFactor: index.isEven ? 0.7 : 0.55,
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 44, height: 12),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// بطاقة حقول (شروط، نموذج) قيد التحميل.
class FormCardSkeleton extends StatelessWidget {
  const FormCardSkeleton({super.key, this.fields = 2});

  final int fields;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < fields; index++) ...[
            if (index > 0) const SizedBox(height: 20),
            const SkeletonLine(widthFactor: 0.35, height: 14),
            const SizedBox(height: 12),
            const SkeletonBox(width: double.infinity, height: 46, radius: 10),
          ],
        ],
      ),
    ),
  );
}

/// جلسة لعبة قيد الدخول: رأس بأرقام، ومحتوى — وعمود جانبي على الشاشة العريضة.
class SessionSkeleton extends StatelessWidget {
  const SessionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final split = MediaQuery.sizeOf(context).width >= 900;

    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.outline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: context.contentPadding(
            top: 12,
            bottom: 16,
            minHorizontal: 16,
            maxWidth: ContentWidth.wide,
          ),
          child: const Shimmer(
            child: Column(
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 42, height: 42, radius: 10),
                    SizedBox(width: 12),
                    SkeletonBox(width: 42, height: 42, radius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(widthFactor: 0.4, height: 18),
                          SizedBox(height: 8),
                          SkeletonLine(widthFactor: 0.25),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 58, radius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 58, radius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 58, radius: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final main = ListView(
      padding: context.listPadding(
        top: 20,
        minHorizontal: 16,
        maxWidth: split ? ContentWidth.wide : ContentWidth.standard,
      ),
      children: const [
        ListCardSkeleton(rows: 5),
        SizedBox(height: 16),
        FormCardSkeleton(fields: 1),
      ],
    );

    return Column(
      children: [
        header,
        Expanded(
          child: split
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: main),
                    Container(
                      width: 360,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: BorderDirectional(
                          start: BorderSide(color: palette.outline),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: const [ListCardSkeleton(rows: 4)],
                      ),
                    ),
                  ],
                )
              : main,
        ),
      ],
    );
  }
}
