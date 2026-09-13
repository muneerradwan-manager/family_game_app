import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/countdown.dart';
import '../../model/hadaf_models.dart';

/// لوحة الترتيب بين الجولات وفي النهاية.
class StandingsView extends StatelessWidget {
  const StandingsView({
    super.key,
    required this.standings,
    required this.viewerId,
    this.animate = true,
  });

  final List<Standing> standings;
  final String viewerId;

  /// الرقم يرتفع بحركة بدل أن يقفز — بين الجولات فقط، لا في شاشة النتيجة
  /// حيث يُعاد بناء القائمة مع كل تمرير.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < standings.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              color: standings[index].userId == viewerId
                  ? palette.primary.withValues(alpha: 0.08)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      switch (index) {
                        0 => '🥇',
                        1 => '🥈',
                        2 => '🥉',
                        _ => '${index + 1}',
                      },
                      style: TextStyle(
                        fontSize: index < 3 ? 19 : 15,
                        fontWeight: FontWeight.w900,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  PlayerAvatar(
                    username: standings[index].username,
                    photoUrl: standings[index].photoUrl,
                    avatarId: standings[index].avatarId,
                    size: 38,
                    dimmed: standings[index].hasLeft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          standings[index].username,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          [
                            '${standings[index].correctCount} صحيحة',
                            if (standings[index].bestStreak >= 3)
                              '🔥 ${standings[index].bestStreak}',
                            if (standings[index].hasLeft) 'طلع',
                          ].join(' · '),
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (animate)
                    AnimatedScore(
                      standings[index].total,
                      duration: const Duration(milliseconds: 900),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary,
                      ),
                    )
                  else
                    Text(
                      '${standings[index].total}',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFontFamily,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
