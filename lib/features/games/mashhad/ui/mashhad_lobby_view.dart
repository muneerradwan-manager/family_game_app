import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/mashhad_game_cubit.dart';
import '../model/mashhad_models.dart';

/// اللوبي: الأسماء تظهر لحظياً، والمدة المتوقعة تتحدّث مع كل انضمام.
class MashhadLobbyView extends StatelessWidget {
  const MashhadLobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MashhadGameCubit>().state;
    final snapshot = state.snapshot!;
    final palette = context.palette;
    final seated = snapshot.seatedPlayers;

    return Column(
      children: [
        GradientHeader(
          title: 'لعبة المشهد',
          subtitle: 'عم ننطر الباقيين...',
          leading: const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: BackButton(color: Colors.white),
          ),
          child: _LobbyMeter(
            playerCount: seated.length,
            scenes: snapshot.config.scenes,
            estimatedSeconds: snapshot.estimatedSeconds,
          ),
        ),
        Expanded(
          child: ListView(
            padding: context.contentPadding(),
            children: [
              const _HowItWorks(),
              const SizedBox(height: 20),
              _ConfigSummary(config: snapshot.config),
              const SizedBox(height: 20),
              SectionTitle('اللاعبين (${seated.length})'),
              SectionCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final player in seated)
                      ListTile(
                        leading: PlayerAvatar(
                          username: player.username,
                          photoUrl: player.photoUrl,
                          avatarId: player.avatarId,
                          gender: Gender.parse(player.gender),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.username,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            if (player.id == snapshot.hostId) ...[
                              const SizedBox(width: 8),
                              const InfoChip('صاحب الغرفة'),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (seated.length < 3)
                SectionCard(
                  color: palette.surfaceAlt,
                  child: Text(
                    'بدنا 3 لاعبين على الأقل — والأهداف المتضاربة بتصير أحلى '
                    'كل ما زاد العدد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textMuted, height: 1.5),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: context.contentPadding(top: 4, bottom: 12),
            child: snapshot.me.isHost
                ? FilledButton.icon(
                    onPressed: snapshot.canStart
                        ? () => context.read<MashhadGameCubit>().startGame()
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

class _LobbyMeter extends StatelessWidget {
  const _LobbyMeter({
    required this.playerCount,
    required this.scenes,
    required this.estimatedSeconds,
  });

  final int playerCount;
  final int scenes;
  final int estimatedSeconds;

  @override
  Widget build(BuildContext context) {
    final minutes = (estimatedSeconds / 60).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MeterItem(value: '$playerCount', label: 'ممثّلين'),
          _MeterDivider(),
          _MeterItem(value: '$scenes', label: 'مشهد'),
          _MeterDivider(),
          _MeterItem(value: '~$minutes', label: 'دقيقة'),
        ],
      ),
    );
  }
}

class _MeterItem extends StatelessWidget {
  const _MeterItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _MeterDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    color: Colors.white.withValues(alpha: 0.3),
  );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    const steps = [
      ('🎭', 'كل واحد بياخد شخصية وهدف سرّي — وأحياناً معلومة ما حدا بيعرفها.'),
      ('💬', 'المشهد بيبلّش والكل بيحكي بنفس الوقت — فاوض، مثّل، اكذب.'),
      ('⚡', 'أحداث مفاجئة بتقلب المشهد — وبعضها بيوصل لواحد بس.'),
      ('⚖️', 'بالآخر بتقول شو حقّقت، وبتنكشف الأهداف — واللي بيشك بيعترض.'),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'كيف بتنلعب',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final (emoji, text) in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
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

  final MashhadConfig config;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شروط اللعبة',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(
                config.categoryLabel == null
                    ? '🎲 مزيج'
                    : '${config.categoryEmoji ?? ''} ${config.categoryLabel}',
              ),
              InfoChip('${config.scenes} مشهد', icon: Icons.movie_outlined),
              InfoChip(
                '${config.sceneSeconds ~/ 60} دقائق للمشهد',
                icon: Icons.timer_outlined,
              ),
              InfoChip(
                '⚖️ ${config.challengesPerPlayer} اعتراضات',
                color: palette.accent,
              ),
              if (config.familyMode)
                InfoChip(
                  'الوضع العائلي',
                  color: palette.secondary,
                  icon: Icons.child_care,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
