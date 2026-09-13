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
import '../../../../shared/widgets/countdown.dart';
import '../../data/game_repository.dart';
import '../cubit/harf_game_cubit.dart';
import '../model/harf_models.dart';
import 'widgets/result_share_card.dart';

/// شاشة النتيجة.
///
/// زر "كمان لعبة؟" هو أعلى رافعة لإعادة اللعب في التطبيق كله: يفتح غرفة
/// جديدة بنفس الإعدادات بدل إعادة المرور بشاشتي الاختيار والشروط.
class HarfResultView extends StatefulWidget {
  const HarfResultView({super.key});

  @override
  State<HarfResultView> createState() => _HarfResultViewState();
}

class _HarfResultViewState extends State<HarfResultView> {
  bool _opening = false;
  bool _sharing = false;

  /// نلتقطها أثناء البناء: بطاقة المشاركة تُرسم خارج شجرة هذه الشاشة، فلا
  /// تصلها ألوان الثيم من السياق.
  late AppPalette _palette;

  Future<void> _playAgain() async {
    final state = context.read<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final router = GoRouter.of(context);

    setState(() => _opening = true);

    try {
      final gameId = await context.read<GameRepository>().openRoom(
        channelId: snapshot.channelId,
        gameType: 'harf',
        config: {
          'sixthColumn': snapshot.config.sixthColumn,
          'roundsPerPlayer': snapshot.config.roundsPerPlayer,
          'writeSeconds': snapshot.config.writeSeconds,
          'flexibleMode': snapshot.config.flexibleMode,
        },
      );

      router.pushReplacement('/games/$gameId?type=harf');
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final result = snapshot.result;
    final palette = context.palette;

    _palette = palette;

    if (result == null) {
      return const AppLoader(message: 'عم نجهّز النتيجة...');
    }

    final winner = result.winner;
    final scores = result.finalScores;

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
              const Text('🏆', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 10),
              Text(
                winner == null ? 'خلصت اللعبة' : 'الفائز: ${winner.username}',
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
                  '${winner.total} نقطة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                  ),
                ),
              ],
              if (result.decidedByTiebreak) ...[
                const SizedBox(height: 8),
                const InfoChip('حُسمت بجولة الحسم', color: Colors.white),
              ],
              if (result.endedEarly) ...[
                const SizedBox(height: 8),
                Text(
                  result.reason == 'not_enough_players'
                      ? 'وقفت اللعبة — ما ضل كفاية لاعبين'
                      : 'انتهت مبكراً بعد ${result.roundsPlayed} جولات',
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
              const SectionTitle('اللوحة النهائية'),
              for (var index = 0; index < scores.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FinalRow(rank: index + 1, standing: scores[index]),
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
                  label: const Text('كمان لعبة؟'),
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

  /// مشاركة كصورة أولاً: لوحة النتائج تُقرأ بلمحة في محادثة العيلة، والنص
  /// وحده يضيع بين الرسائل. النص يبقى مرافقاً وبديلاً لو تعذّر الرسم.
  Future<void> _share(HarfResult result, HarfSnapshot snapshot) async {
    setState(() => _sharing = true);

    final caption = _caption(result);
    final image = await renderShareCard(
      context: context,
      card: ResultShareCard(
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
    final file = File('${directory.path}/harf-result-${snapshot.gameId}.png');
    await file.writeAsBytes(image);

    await SharePlus.instance.share(
      ShareParams(text: caption, files: [XFile(file.path)]),
    );
  }

  String _caption(HarfResult result) => [
    '🔠 نتيجة لعبة الحروف',
    '',
    for (var index = 0; index < result.finalScores.length; index++)
      '${_medal(index)} ${result.finalScores[index].username} — ${result.finalScores[index].total}',
    '',
    '${result.roundsPlayed} جولات · ${result.finalScores.length} لاعبين',
  ].join('\n');

  static String _medal(int index) => switch (index) {
    0 => '🥇',
    1 => '🥈',
    2 => '🥉',
    _ => '  ',
  };
}

class _FinalRow extends StatelessWidget {
  const _FinalRow({required this.rank, required this.standing});

  final int rank;
  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPodium = rank <= 3;

    return SectionCard(
      color: isPodium ? palette.primary.withValues(alpha: 0.06) : null,
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
                // من غادر يبقى في اللوحة بنقاطه المتجمّدة.
                if (standing.hasLeft)
                  Text(
                    'طلع من اللعبة',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          AnimatedScore(
            standing.total,
            duration: const Duration(milliseconds: 1200),
            style: TextStyle(
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
