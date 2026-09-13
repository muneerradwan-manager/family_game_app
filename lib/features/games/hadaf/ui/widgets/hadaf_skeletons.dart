import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/game_layout.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../../shared/widgets/skeleton.dart';

/// السؤال قبل وصول نصّه: بطاقة السؤال وأماكن الخيارات محجوزة بنفس ترتيبها،
/// فلا تقفز الخيارات تحت إصبع اللاعب لحظة وصولها.
class QuestionSkeleton extends StatelessWidget {
  const QuestionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = context.screenWidth >= Breakpoints.tablet;
    const option = SkeletonBox(height: 64, radius: AppRadius.card);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionCard(
          padding: EdgeInsets.all(24),
          child: Shimmer(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 90, height: 22, radius: 999),
                    SizedBox(width: 8),
                    SkeletonBox(width: 54, height: 22, radius: 999),
                  ],
                ),
                SizedBox(height: 22),
                SkeletonBox(width: double.infinity, height: 20),
                SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: SkeletonBox(width: double.infinity, height: 20),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Shimmer(
          child: grid
              ? const Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: option),
                        SizedBox(width: 12),
                        Expanded(child: option),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: option),
                        SizedBox(width: 12),
                        Expanded(child: option),
                      ],
                    ),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    option,
                    SizedBox(height: 10),
                    option,
                    SizedBox(height: 10),
                    option,
                    SizedBox(height: 10),
                    option,
                  ],
                ),
        ),
      ],
    );
  }
}

/// النتيجة لم تصل بعد: الرأس حقيقي، وبطاقة الفائز واللوحة هيكل.
class HadafResultSkeleton extends StatelessWidget {
  const HadafResultSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SessionHeader(
        title: 'لعبة الهدف',
        subtitle: 'عم نجهّز النتيجة...',
        emoji: '🎯',
      ),
      Expanded(
        child: ListView(
          padding: context.listPadding(minHorizontal: 16),
          children: const [
            SectionCard(
              padding: EdgeInsets.all(24),
              child: Shimmer(
                child: Column(
                  children: [
                    SkeletonBox(width: 64, height: 64, radius: 18),
                    SizedBox(height: 14),
                    FractionallySizedBox(
                      widthFactor: 0.5,
                      child: SkeletonBox(width: double.infinity, height: 22),
                    ),
                    SizedBox(height: 10),
                    FractionallySizedBox(
                      widthFactor: 0.35,
                      child: SkeletonBox(width: double.infinity, height: 13),
                    ),
                    SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: SkeletonBox(height: 68, radius: 10)),
                        SizedBox(width: 8),
                        Expanded(child: SkeletonBox(height: 96, radius: 10)),
                        SizedBox(width: 8),
                        Expanded(child: SkeletonBox(height: 52, radius: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ListCardSkeleton(rows: 4),
          ],
        ),
      ),
    ],
  );
}
