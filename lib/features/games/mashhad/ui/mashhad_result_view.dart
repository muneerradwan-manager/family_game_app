import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../data/game_repository.dart';
import '../../harf/ui/widgets/result_share_card.dart' show renderShareCard;
import '../cubit/mashhad_game_cubit.dart';
import '../model/mashhad_models.dart';
import 'widgets/mashhad_share_card.dart';

/// شاشة النتيجة: الترتيب + جوائز السهرة + قصة كل لاعب.
class MashhadResultView extends StatefulWidget {
  const MashhadResultView({super.key});

  @override
  State<MashhadResultView> createState() => _MashhadResultViewState();
}

class _MashhadResultViewState extends State<MashhadResultView> {
  bool _opening = false;
  bool _sharing = false;

  /// نلتقطها أثناء البناء: بطاقة المشاركة تُرسم خارج شجرة هذه الشاشة.
  late AppPalette _palette;

  Future<void> _playAgain() async {
    final snapshot = context.read<MashhadGameCubit>().state.snapshot!;
    final router = GoRouter.of(context);

    setState(() => _opening = true);

    try {
      final gameId = await context.read<GameRepository>().openRoom(
        channelId: snapshot.channelId,
        gameType: 'mashhad',
        config: {
          'category': snapshot.config.category,
          'scenes': snapshot.config.scenes,
          'sceneSeconds': snapshot.config.sceneSeconds,
          'familyMode': snapshot.config.familyMode,
        },
      );

      router.pushReplacement('/games/$gameId?type=mashhad');
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final state = context.watch<MashhadGameCubit>().state;
    final snapshot = state.snapshot!;
    final result = snapshot.result;
    final palette = context.palette;

    _palette = palette;

    if (result == null) {
      return const AppLoader(message: 'عم نجهّز النتيجة...');
    }

    final winner = result.winner;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 24,
            bottom: 28,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.headerGradient,
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 10),
              Text(
                winner == null
                    ? 'خلصت السهرة'
                    : 'بطل السهرة: ${winner.username}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (winner != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${winner.total} نقطة · حقّق ${winner.goalsAchieved} هدف',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
              if (result.endedEarly) ...[
                const SizedBox(height: 8),
                Text(
                  result.reason == 'not_enough_players'
                      ? 'وقفت اللعبة — ما ضل كفاية لاعبين'
                      : 'انتهت مبكراً بعد ${result.scenesPlayed} مشاهد',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: context.contentPadding(bottom: 12),
            children: [
              if (result.awards.isNotEmpty) ...[
                const SectionTitle('جوائز السهرة'),
                for (final award in result.awards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AwardTile(award: award),
                  ),
                const SizedBox(height: 12),
              ],
              const SectionTitle('اللوحة النهائية'),
              for (var index = 0; index < result.finalScores.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FinalRow(
                    rank: index + 1,
                    standing: result.finalScores[index],
                    isMe: result.finalScores[index].userId == cubit.viewerId,
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: context.contentPadding(top: 4, bottom: 12),
            child: Column(
              children: [
                FilledButton.icon(
                  onPressed: _opening ? null : _playAgain,
                  icon: _opening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.replay),
                  label: const Text('كمان سهرة؟'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharing
                            ? null
                            : () => _share(result, snapshot),
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.share, size: 18),
                        label: const Text('مشاركة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            context.go('/channels/${snapshot.channelId}'),
                        child: const Text('رجوع للقناة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _share(MashhadResult result, MashhadSnapshot snapshot) async {
    setState(() => _sharing = true);

    final caption = _caption(result);
    final image = await renderShareCard(
      context: context,
      card: MashhadShareCard(
        result: result,
        palette: _palette,
        channelName: 'ألعاب العيلة',
      ),
    );

    if (!mounted) return;

    setState(() => _sharing = false);

    if (image == null) {
      await SharePlus.instance.share(ShareParams(text: caption));

      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/mashhad-${snapshot.gameId}.png');
    await file.writeAsBytes(image);

    await SharePlus.instance.share(
      ShareParams(text: caption, files: [XFile(file.path)]),
    );
  }

  String _caption(MashhadResult result) => [
    '🎬 نتيجة لعبة المشهد',
    '',
    for (var index = 0; index < result.finalScores.length; index++)
      '${_medal(index)} ${result.finalScores[index].username} — ${result.finalScores[index].total}',
    if (result.awards.isNotEmpty) ...[
      '',
      for (final award in result.awards)
        '${award.emoji} ${award.label}: ${award.winners.join(' · ')}',
    ],
    '',
    '${result.scenesPlayed} مشاهد · ${result.finalScores.length} لاعبين',
  ].join('\n');

  static String _medal(int index) => switch (index) {
    0 => '🥇',
    1 => '🥈',
    2 => '🥉',
    _ => '  ',
  };
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({required this.award});

  final AwardResult award;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      color: palette.secondary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(award.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  award.label,
                  style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  award.winners.join(' · '),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${award.votes} صوت',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FinalRow extends StatelessWidget {
  const _FinalRow({
    required this.rank,
    required this.standing,
    required this.isMe,
  });

  final int rank;
  final Standing standing;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPodium = rank <= 3;

    return SectionCard(
      color: isMe
          ? palette.primary.withValues(alpha: 0.08)
          : (isPodium ? palette.primary.withValues(alpha: 0.04) : null),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              switch (rank) {
                1 => '🥇',
                2 => '🥈',
                3 => '🥉',
                _ => '$rank',
              },
              style: TextStyle(
                fontSize: isPodium ? 20 : 16,
                fontWeight: FontWeight.w900,
                color: palette.textMuted,
              ),
            ),
          ),
          PlayerAvatar(
            username: standing.username,
            photoUrl: standing.photoUrl,
            avatarId: standing.avatarId,
            size: 40,
            dimmed: standing.hasLeft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.username,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                // قصة اللاعب لا رقمه وحده: كم هدفاً حقّق وكم تكلّم.
                Text(
                  [
                    '${standing.goalsAchieved} هدف',
                    '${standing.messageCount} رسالة',
                    if (standing.hasLeft) 'طلع',
                  ].join(' · '),
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${standing.total}',
            style: TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
