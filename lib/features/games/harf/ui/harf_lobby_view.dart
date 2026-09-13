import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/harf_game_cubit.dart';
import '../model/harf_models.dart';

/// اللوبي: الأسماء تظهر لحظياً، والمدة المتوقعة تتحدّث مع كل انضمام.
class HarfLobbyView extends StatelessWidget {
  const HarfLobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final palette = context.palette;
    final seated = snapshot.seatedPlayers;
    final rounds = snapshot.totalRounds;

    return Column(
      children: [
        GradientHeader(
          title: 'لعبة الحروف',
          subtitle: 'عم ننطر الباقيين...',
          leading: const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: BackButton(color: Colors.white),
          ),
          child: _LobbyMeter(
            playerCount: seated.length,
            rounds: rounds,
            estimatedSeconds: snapshot.estimatedSeconds,
          ),
        ),
        Expanded(
          child: ListView(
            padding: context.contentPadding(),
            children: [
              _ConfigSummary(config: snapshot.config),
              const SizedBox(height: 20),
              // فوق 12 جولة: اقتراح تلقائي بتخفيض الجولات حمايةً من لعبة تُهجر.
              if (rounds > 12) ...[
                _TooLongWarning(rounds: rounds),
                const SizedBox(height: 20),
              ],
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
                    'بدنا 3 لاعبين على الأقل حتى نبلّش — ابعت رمز القناة لحدا كمان.',
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

/// السطر الحي: لاعبين · جولات · مدة متوقعة — يتحدّث مع كل انضمام.
class _LobbyMeter extends StatelessWidget {
  const _LobbyMeter({
    required this.playerCount,
    required this.rounds,
    required this.estimatedSeconds,
  });

  final int playerCount;
  final int rounds;
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
          _MeterItem(value: '$playerCount', label: 'لاعبين'),
          _MeterDivider(),
          _MeterItem(value: '$rounds', label: 'جولة'),
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

class _ConfigSummary extends StatelessWidget {
  const _ConfigSummary({required this.config});

  final HarfConfig config;

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
              for (final column in config.columns)
                InfoChip(config.labelOf(column)),
              InfoChip(
                '${config.writeSeconds} ثانية',
                icon: Icons.timer_outlined,
              ),
              InfoChip(
                '${config.roundsPerPlayer} جولة/شخص',
                icon: Icons.repeat,
              ),
              if (config.flexibleMode)
                InfoChip(
                  'الوضع المرن',
                  color: palette.accent,
                  icon: Icons.child_care,
                ),
            ],
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
      color: palette.accent.withValues(alpha: 0.10),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: palette.accent),
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
