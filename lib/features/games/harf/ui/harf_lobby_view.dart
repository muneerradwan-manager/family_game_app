import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/harf_game_cubit.dart';
import '../model/harf_models.dart';
import 'widgets/harf_layout.dart';

/// اللوبي: الأسماء تظهر لحظياً، والمدة المتوقعة تتحدّث مع كل انضمام.
///
/// على الشاشة العريضة الشروط في العمود الجانبي والشبكة للاعبين وحدهم؛ على
/// الأضيق تنزل الشروط فوق اللاعبين في العمود نفسه.
class HarfLobbyView extends StatelessWidget {
  const HarfLobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<HarfGameCubit>();
    final snapshot = cubit.state.snapshot!;
    final palette = context.palette;
    final seated = snapshot.seatedPlayers;
    final rounds = snapshot.totalRounds;
    final split = SessionBody.isSplit(context);
    final minutes = (snapshot.estimatedSeconds / 60).round();

    final main = HarfPaneList(
      maxWidth: split ? ContentWidth.wide : ContentWidth.standard,
      children: [
        if (!split) ...[
          _ConfigSummary(config: snapshot.config),
          const SizedBox(height: 20),
        ],
        // فوق 12 جولة: اقتراح تلقائي بتخفيض الجولات حمايةً من لعبة تُهجر.
        if (rounds > 12) ...[
          _TooLongWarning(rounds: rounds),
          const SizedBox(height: 20),
        ],
        SectionTitle('اللاعبين (${seated.length})'),
        ResponsiveGrid(
          minItemWidth: 200,
          maxColumns: 4,
          spacing: 12,
          children: [
            for (final player in seated)
              _PlayerTile(
                player: player,
                isHost: player.id == snapshot.hostId,
                isMe: player.id == cubit.viewerId,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (seated.length < 3)
          SectionCard(
            color: palette.surfaceAlt,
            child: Row(
              children: [
                Icon(Icons.group_add_outlined, color: palette.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'بدنا 3 لاعبين على الأقل حتى نبلّش — ابعت رمز القناة لحدا كمان.',
                    style: TextStyle(color: palette.textMuted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Column(
      children: [
        SessionHeader(
          title: 'لعبة الحروف',
          subtitle: 'عم ننطر الباقيين...',
          emoji: '🔠',
          // الرجوع يمرّ على PopScope في شاشة الجلسة: تأكيد ثم إبلاغ السيرفر.
          onBack: () => Navigator.of(context).maybePop(),
          stats: [
            SessionStat('${seated.length}', 'لاعبين'),
            SessionStat('$rounds', 'جولة'),
            SessionStat('~$minutes', 'دقيقة'),
          ],
        ),
        Expanded(
          child: HarfSessionBody(
            main: main,
            side: SidePanel(
              title: 'شروط اللعبة',
              children: [
                _ConfigSummary(config: snapshot.config, showTitle: false),
                const SizedBox(height: 16),
                _LobbyDetails(snapshot: snapshot, minutes: minutes),
              ],
            ),
            footer: snapshot.me.isHost
                ? FilledButton.icon(
                    onPressed: snapshot.canStart
                        ? () => context.read<HarfGameCubit>().startGame()
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    // لحظة "ابدأ" تقفل القائمة نهائياً وتثبّت ترتيب الأدوار.
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

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.isHost,
    required this.isMe,
  });

  final HarfPlayer player;
  final bool isHost;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          PlayerAvatar(
            username: player.username,
            photoUrl: player.photoUrl,
            avatarId: player.avatarId,
            gender: Gender.parse(player.gender),
            size: 42,
          ),
          const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
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

class _ConfigSummary extends StatelessWidget {
  const _ConfigSummary({required this.config, this.showTitle = true});

  final HarfConfig config;

  /// في العمود الجانبي العنوان فوق البطاقة أصلاً.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final column in config.columns) InfoChip(config.labelOf(column)),
        InfoChip('${config.writeSeconds} ثانية', icon: Icons.timer_outlined),
        InfoChip('${config.roundsPerPlayer} جولة/شخص', icon: Icons.repeat),
        if (config.flexibleMode)
          InfoChip(
            'الوضع المرن',
            color: palette.accent,
            icon: Icons.child_care,
          ),
      ],
    );

    return showTitle
        ? SectionCard(title: 'شروط اللعبة', child: chips)
        : SectionCard(child: chips);
  }
}

/// تفاصيل الغرفة بجانب اللاعبين — للشاشة العريضة وحدها، فالأرقام نفسها في
/// شريط الرأس على الجوال.
class _LobbyDetails extends StatelessWidget {
  const _LobbyDetails({required this.snapshot, required this.minutes});

  final HarfSnapshot snapshot;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final config = snapshot.config;

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        children: [
          HarfDetailRow(
            icon: Icons.view_column_outlined,
            label: 'الخانات',
            value: '${config.columns.length}',
          ),
          HarfDetailRow(
            icon: Icons.timer_outlined,
            label: 'وقت الكتابة',
            value: '${config.writeSeconds} ثانية',
          ),
          HarfDetailRow(
            icon: Icons.repeat,
            label: 'الجولات',
            value: '${snapshot.totalRounds} جولة',
          ),
          HarfDetailRow(
            icon: Icons.schedule,
            label: 'المدة المتوقعة',
            value: '~$minutes دقيقة',
          ),
        ],
      ),
    );
  }
}

class _TooLongWarning extends StatelessWidget {
  const _TooLongWarning({required this.rounds});

  final int rounds;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isHost =
        context.read<HarfGameCubit>().state.snapshot?.me.isHost ?? false;

    return SectionCard(
      color: palette.warning.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: palette.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHost
                  ? '$rounds جولة كتير — فكّر تنزّل الجولات لكل شخص حتى ما تطوّل اللعبة.'
                  : '$rounds جولة — اللعبة رح تكون طويلة شوي.',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          if (isHost)
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('عدّل'),
            ),
        ],
      ),
    );
  }
}
