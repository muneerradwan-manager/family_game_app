import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/spy_game_cubit.dart';
import '../model/spy_models.dart';
import 'widgets/spy_layout.dart';

/// اللوبي: الأسماء تظهر لحظياً، والمدة المتوقعة تتحدّث مع كل انضمام.
///
/// على الشاشة العريضة اللاعبون يملؤون الوسط شبكةً والشروط في العمود الجانبي:
/// من ينتظر يراقب من دخل، والشروط مرجع يُلقى عليه نظرة لا أكثر.
class SpyLobbyView extends StatelessWidget {
  const SpyLobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final palette = context.palette;
    final seated = snapshot.seatedPlayers;
    final split = SessionBody.isSplit(context);
    final minutes = (snapshot.estimatedSeconds / 60).round();

    final players = SectionCard(
      title: 'اللاعبين (${seated.length})',
      child: ResponsiveGrid(
        minItemWidth: 210,
        spacing: 10,
        children: [
          for (final player in seated)
            _PlayerTile(player: player, isHost: player.id == snapshot.hostId),
        ],
      ),
    );

    return Column(
      children: [
        SessionHeader(
          title: 'لعبة الجاسوس',
          subtitle: 'عم ننطر الباقيين...',
          emoji: '🕵️',
          // maybePop لا pop: الخروج يمرّ على PopScope فيسأل ويبلّغ السيرفر.
          onBack: () => Navigator.of(context).maybePop(),
          stats: [
            SessionStat('${seated.length}', 'لاعبين'),
            const SessionStat('1', 'جاسوس'),
            SessionStat('~$minutes', 'دقيقة'),
          ],
        ),
        Expanded(
          child: SpyBody(
            main: SpyStage(
              maxWidth: split ? 860 : ContentWidth.standard,
              children: [
                if (!split) ...[
                  ResponsiveGrid(
                    minItemWidth: 300,
                    maxColumns: 2,
                    equalHeight: false,
                    children: [
                      const _HowItWorks(),
                      _ConfigSummary(config: snapshot.config),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                players,
                if (seated.length < 3) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    color: palette.surfaceAlt,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'بدنا 3 لاعبين على الأقل — وكل ما زاد العدد صار إخفاء '
                            'الجاسوس أصعب وأمتع. ابعت رمز القناة لحدا كمان.',
                            style: TextStyle(
                              color: palette.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            side: SidePanel(
              children: [
                _ConfigSummary(config: snapshot.config),
                const SizedBox(height: 16),
                const _HowItWorks(),
              ],
            ),
            footer: snapshot.me.isHost
                ? FilledButton.icon(
                    onPressed: snapshot.canStart
                        ? () => context.read<SpyGameCubit>().startGame()
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    // لحظة "ابدأ" تسحب الكلمة وتختار الجاسوس وتقفل القائمة.
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
  const _PlayerTile({required this.player, required this.isHost});

  final SpyPlayer player;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: palette.outline),
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
                if (isHost) ...[
                  const SizedBox(height: 4),
                  const InfoChip('صاحب الغرفة'),
                ],
              ],
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
      ('🗝️', 'الكل بياخد نفس الكلمة — إلا واحد، هو الجاسوس.'),
      ('❓', 'كل واحد بدوره بيسأل لاعب سؤال عن الكلمة بلا ما يقولها.'),
      ('🗳️', 'بعد ما يسأل الكل، بتصوّتوا على مين الجاسوس.'),
      ('🏆', 'مسكتوه؟ فزتوا. نجا لآخر جولة؟ فاز هو.'),
    ];

    return SectionCard(
      title: 'كيف بتنلعب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(steps[index].$1, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index].$2,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13.5,
                        height: 1.5,
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

class _ConfigSummary extends StatelessWidget {
  const _ConfigSummary({required this.config});

  final SpyConfig config;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = context.read<SpyGameCubit>().state.snapshot;

    return SectionCard(
      title: 'شروط اللعبة',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          InfoChip(
            snapshot?.categoryLabel == null
                ? '🎲 مجموعة مفاجأة'
                : '${snapshot?.categoryEmoji ?? ''} ${snapshot?.categoryLabel}',
          ),
          InfoChip(
            '${config.turnSeconds} ثانية للدور',
            icon: Icons.timer_outlined,
          ),
          InfoChip('${config.maxRounds} جولات', icon: Icons.repeat),
          if (config.lastGuess)
            InfoChip(
              'فرصة أخيرة للجاسوس',
              color: palette.accent,
              icon: Icons.casino_outlined,
            ),
        ],
      ),
    );
  }
}
