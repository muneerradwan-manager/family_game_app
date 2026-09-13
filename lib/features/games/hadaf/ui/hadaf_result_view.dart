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
import '../cubit/hadaf_game_cubit.dart';
import '../model/hadaf_models.dart';
import 'widgets/hadaf_share_card.dart';
import 'widgets/standings_view.dart';

/// شاشة النتيجة.
class HadafResultView extends StatefulWidget {
  const HadafResultView({super.key});

  @override
  State<HadafResultView> createState() => _HadafResultViewState();
}

class _HadafResultViewState extends State<HadafResultView> {
  bool _opening = false;
  bool _sharing = false;

  /// نلتقطها أثناء البناء: بطاقة المشاركة تُرسم خارج شجرة هذه الشاشة، فلا
  /// تصلها ألوان الثيم من السياق.
  late AppPalette _palette;

  Future<void> _playAgain() async {
    final snapshot = context.read<HadafGameCubit>().state.snapshot!;
    final router = GoRouter.of(context);

    setState(() => _opening = true);

    try {
      final gameId = await context.read<GameRepository>().openRoom(
        channelId: snapshot.channelId,
        gameType: 'hadaf',
        config: {
          'category': snapshot.config.category,
          'rounds': snapshot.config.rounds,
          'questionSeconds': snapshot.config.questionSeconds,
          'flexibleMode': snapshot.config.flexibleMode,
        },
      );

      router.pushReplacement('/games/$gameId?type=hadaf');
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
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
              const Text('🎯', style: TextStyle(fontSize: 54)),
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
                  '${winner.total} نقطة · ${winner.correctCount} إجابة صحيحة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
              if (result.decidedByTiebreak) ...[
                const SizedBox(height: 8),
                const InfoChip('حُسمت بجولة الحسم 🔥', color: Colors.white),
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
              StandingsView(
                standings: result.finalScores,
                viewerId: cubit.viewerId,
                animate: false,
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

  /// مشاركة كصورة أولاً: اللوحة تُقرأ بلمحة في محادثة العيلة، والنص وحده
  /// يضيع بين الرسائل.
  Future<void> _share(HadafResult result, HadafSnapshot snapshot) async {
    setState(() => _sharing = true);

    final caption = _caption(result);
    final image = await renderShareCard(
      context: context,
      card: HadafShareCard(
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
    final file = File('${directory.path}/hadaf-result-${snapshot.gameId}.png');
    await file.writeAsBytes(image);

    await SharePlus.instance.share(
      ShareParams(text: caption, files: [XFile(file.path)]),
    );
  }

  String _caption(HadafResult result) => [
    '🎯 نتيجة لعبة الهدف',
    '',
    for (var index = 0; index < result.finalScores.length; index++)
      '${_medal(index)} ${result.finalScores[index].username} — ${result.finalScores[index].total}',
    '',
    '${result.roundsPlayed} تحدّيات · ${result.finalScores.length} لاعبين',
  ].join('\n');

  static String _medal(int index) => switch (index) {
    0 => '🥇',
    1 => '🥈',
    2 => '🥉',
    _ => '  ',
  };
}
