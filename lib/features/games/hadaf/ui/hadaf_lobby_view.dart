import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/hadaf_game_cubit.dart';
import '../model/hadaf_models.dart';
import 'widgets/hadaf_layout.dart';

/// اللوبي: الأسماء تظهر لحظياً، والمدة المتوقعة تتحدّث مع كل انضمام.
///
/// على الشاشة العريضة: اللاعبون شبكة في العمود الرئيسي، والشروط في العمود
/// الجانبي. على الجوال والتابلت عمود واحد بنفس ترتيب الجوال القديم.
class HadafLobbyView extends StatelessWidget {
  const HadafLobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
    final snapshot = state.snapshot!;
    final seated = snapshot.seatedPlayers;
    final split = SessionBody.isSplit(context);
    final minutes = (snapshot.estimatedSeconds / 60).round();

    final players = _PlayersCard(
      players: seated,
      hostId: snapshot.hostId,
      viewerId: cubit.viewerId,
    );
    final notEnough = seated.length < 2;
    const gap = SizedBox(height: 16);

    return Column(
      children: [
        SessionHeader(
          title: 'لعبة الهدف',
          subtitle: 'عم ننطر الباقيين...',
          emoji: '🎯',
          stats: [
            SessionStat('${seated.length}', 'لاعبين'),
            SessionStat('${snapshot.config.rounds}', 'تحدّي'),
            SessionStat('~$minutes', 'دقيقة'),
          ],
        ),
        Expanded(
          child: SessionBody(
            main: HadafScroll(
              maxWidth: split ? ContentWidth.wide : ContentWidth.standard,
              // التذييل (زر ابدأ) هو من يحجز شريط التنقّل.
              reserveInset: false,
              children: split
                  ? [
                      players,
                      if (notEnough) ...[gap, const _NotEnoughNotice()],
                      gap,
                      const _HowItWorks(),
                    ]
                  : [
                      const _HowItWorks(),
                      gap,
                      _ConfigSummary(config: snapshot.config),
                      gap,
                      players,
                      if (notEnough) ...[gap, const _NotEnoughNotice()],
                    ],
            ),
            side: split
                ? HadafSide(
                    aboveFooter: true,
                    children: [_ConfigSummary(config: snapshot.config)],
                  )
                : null,
            footer: snapshot.me.isHost
                ? FilledButton.icon(
                    onPressed: snapshot.canStart
                        ? () => context.read<HadafGameCubit>().startGame()
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      snapshot.canStart ? 'ابدأ اللعبة' : 'ناقص لاعبين',
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.hourglass_top, size: 18),
                    label: const Text('عم ننطر صاحب الغرفة يبلّش'),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PlayersCard extends StatelessWidget {
  const _PlayersCard({
    required this.players,
    required this.hostId,
    required this.viewerId,
  });

  final List<HadafPlayer> players;
  final String hostId;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: 'اللاعبين',
      trailing: InfoChip('${players.length}', color: palette.textMuted),
      padding: const EdgeInsets.all(14),
      child: ResponsiveGrid(
        minItemWidth: 210,
        maxColumns: 4,
        spacing: 10,
        children: [
          for (final player in players)
            _PlayerTile(
              player: player,
              isHost: player.id == hostId,
              isMe: player.id == viewerId,
            ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.isHost,
    required this.isMe,
  });

  final HadafPlayer player;
  final bool isHost;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? palette.primary.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: isMe
              ? palette.primary.withValues(alpha: 0.4)
              : palette.outline,
        ),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            username: player.username,
            photoUrl: player.photoUrl,
            avatarId: player.avatarId,
            gender: Gender.parse(player.gender),
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (isHost || isMe) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (isHost) const InfoChip('صاحب الغرفة'),
                      if (isMe) InfoChip('إنت', color: palette.textMuted),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEnoughNotice extends StatelessWidget {
  const _NotEnoughNotice();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      color: palette.warning.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: palette.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'بدنا لاعبين على الأقل — السباق ما بينلعب لحالك.',
              style: TextStyle(color: palette.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    const steps = [
      ('🎯', 'تحدّي واحد يظهر للكل بنفس اللحظة — أربع خيارات.'),
      ('⚡', 'الأسرع بياخد بونص أكبر، والصح لحاله بياخد نقاط.'),
      ('🔥', 'ثلاث إجابات صحيحة ورا بعض = مكافأة سلسلة.'),
      ('🏆', 'بآخر جولة بينحسب المجموع — وأعلى نقاط بيفوز.'),
    ];

    return SectionCard(
      title: 'كيف بتنلعب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, (emoji, text)) in steps.indexed)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
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

/// الشروط كجدول مفتاح/قيمة — كبطاقات التفاصيل في لوحة الإدارة.
class _ConfigSummary extends StatelessWidget {
  const _ConfigSummary({required this.config});

  final HadafConfig config;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final rows = <(IconData, String, Widget)>[
      (
        Icons.category_outlined,
        'المجموعة',
        InfoChip(
          config.categoryLabel == null
              ? '🎲 مزيج'
              : '${config.categoryEmoji ?? ''} ${config.categoryLabel}',
        ),
      ),
      (
        Icons.repeat,
        'التحدّيات',
        InfoChip('${config.rounds} تحدّي', color: palette.textMuted),
      ),
      (
        Icons.timer_outlined,
        'وقت السؤال',
        InfoChip('${config.questionSeconds} ثانية', color: palette.textMuted),
      ),
      (
        Icons.bolt_rounded,
        'المراهنات',
        InfoChip('⚡ ${config.risksPerGame} مراهنات', color: palette.accent),
      ),
      (
        Icons.child_care,
        'الوضع المرن',
        config.flexibleMode
            ? InfoChip('الوضع المرن', color: palette.success)
            : InfoChip('لأ', color: palette.textMuted),
      ),
    ];

    return SectionCard(
      title: 'شروط اللعبة',
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (index, (icon, label, value)) in rows.indexed) ...[
            if (index > 0) const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: palette.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: value),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
