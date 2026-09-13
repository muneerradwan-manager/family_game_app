import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../auth/model/app_user.dart';
import '../../model/mashhad_models.dart';

/// عرض العمود الجانبي في كل شاشات المشهد — نفس قيمة SessionBody الافتراضية.
const mashhadSideWidth = 360.0;

/// حشوة العمود الرئيسي داخل SessionBody.
///
/// `contentPadding` توسّط المحتوى على عرض الشاشة كلها، لكن العمود الرئيسي
/// على الشاشة العريضة ينقص منه العمود الجانبي — فالتوسيط بها يزيح المحتوى
/// نحو العمود الجانبي ويقصّه.
///
/// [reserveInset] لما لا يوجد تحت القائمة تذييل ثابت يحجز شريط التنقّل.
EdgeInsets mashhadMainPadding(
  BuildContext context, {
  required bool split,
  double top = 20,
  double bottom = 24,
  double maxWidth = ContentWidth.standard,
  bool reserveInset = true,
}) {
  final available = context.screenWidth - (split ? mashhadSideWidth : 0);
  final gutter = switch (context.formFactor) {
    FormFactor.desktop => 28.0,
    FormFactor.tablet => 24.0,
    FormFactor.phone => 16.0,
  };
  final free = available - maxWidth;
  final side = free > gutter * 2 ? free / 2 : gutter;

  return EdgeInsets.fromLTRB(
    side,
    top,
    side,
    bottom + (reserveInset ? context.bottomInset : 0),
  );
}

/// عنوان مرحلة في وسط الشاشة (انكشفت الأدوار، جوائز السهرة).
class PhaseIntro extends StatelessWidget {
  const PhaseIntro({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, height: 1.5),
          ),
        ],
      ],
    );
  }
}

/// سطر لاعب في قائمة الممثّلين.
class CastRow extends StatelessWidget {
  const CastRow({
    super.key,
    required this.player,
    this.caption,
    this.trailing,
  });

  final MashhadPlayer player;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        PlayerAvatar(
          username: player.username,
          photoUrl: player.photoUrl,
          avatarId: player.avatarId,
          gender: Gender.parse(player.gender),
          size: 36,
          dimmed: player.hasLeft,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
