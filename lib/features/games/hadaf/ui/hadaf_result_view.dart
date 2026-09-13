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
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../data/game_repository.dart';
import '../../harf/ui/widgets/result_share_card.dart' show renderShareCard;
import '../cubit/hadaf_game_cubit.dart';
import '../model/hadaf_models.dart';
import 'widgets/hadaf_layout.dart';
import 'widgets/hadaf_share_card.dart';
import 'widgets/hadaf_skeletons.dart';
import 'widgets/standings_view.dart';

/// شاشة النتيجة.
///
/// على الشاشة العريضة: الفائز واللوحة في العمود الرئيسي، والأزرار والأرقام في
/// العمود الجانبي. على الجوال الأزرار في تذييل ثابت كما كانت.
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

    _palette = context.palette;

    if (result == null) return const HadafResultSkeleton();

    final split = SessionBody.isSplit(context);
    final winner = result.winner;

    final stats = [
      SessionStat('${result.roundsPlayed}', 'تحدّيات'),
      SessionStat('${result.finalScores.length}', 'لاعبين'),
      if (winner != null) SessionStat('${winner.total}', 'نقطة للفائز'),
    ];

    final actions = _ResultActions(
      opening: _opening,
      sharing: _sharing,
      stacked: split,
      onPlayAgain: _playAgain,
      onShare: () => _share(result, snapshot),
      onBack: () => context.go('/channels/${snapshot.channelId}'),
    );

    return Column(
      children: [
        SessionHeader(
          title: 'لعبة الهدف',
          subtitle: 'خلصت اللعبة',
          emoji: '🎯',
          // على الجوال الأرقام في الرأس؛ على العريضة مكانها العمود الجانبي.
          stats: split ? const [] : stats,
        ),
        Expanded(
          child: SessionBody(
            main: HadafScroll(
              maxWidth: split ? 900 : ContentWidth.standard,
              // بلا تذييل على العريضة: القائمة تحجز شريط التنقّل بنفسها.
              reserveInset: split,
              children: [
                _WinnerCard(result: result, viewerId: cubit.viewerId),
                const SizedBox(height: 16),
                StandingsView(
                  title: 'اللوحة النهائية',
                  standings: result.finalScores,
                  viewerId: cubit.viewerId,
                  animate: false,
                ),
              ],
            ),
            side: split
                ? HadafSide(
                    children: [
                      SectionCard(child: actions),
                      const SizedBox(height: 16),
                      SectionCard(
                        padding: const EdgeInsets.all(12),
                        child: StatStrip(stats: stats),
                      ),
                    ],
                  )
                : null,
            footer: split ? null : actions,
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

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.opening,
    required this.sharing,
    required this.stacked,
    required this.onPlayAgain,
    required this.onShare,
    required this.onBack,
  });

  final bool opening;
  final bool sharing;

  /// في العمود الجانبي كل زر بسطر؛ في تذييل الجوال زرّا المشاركة والرجوع
  /// يتقاسمان سطراً فلا يأكل التذييل نصف الشاشة.
  final bool stacked;

  final VoidCallback onPlayAgain;
  final VoidCallback onShare;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final share = OutlinedButton.icon(
      onPressed: sharing ? null : onShare,
      icon: sharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share, size: 18),
      label: const Text('مشاركة'),
    );

    final back = OutlinedButton(
      onPressed: onBack,
      child: const Text('رجوع للقناة'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: opening ? null : onPlayAgain,
          icon: opening
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
        if (stacked) ...[
          share,
          const SizedBox(height: 8),
          back,
        ] else
          Row(
            children: [
              Expanded(child: share),
              const SizedBox(width: 10),
              Expanded(child: back),
            ],
          ),
      ],
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.result, required this.viewerId});

  final HadafResult result;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final winner = result.winner;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          const GradientMark(emoji: '🎯', size: 64),
          const SizedBox(height: 14),
          Text(
            winner == null ? 'خلصت اللعبة' : 'الفائز: ${winner.username}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (winner != null) ...[
            const SizedBox(height: 4),
            Text(
              '${winner.total} نقطة · ${winner.correctCount} إجابة صحيحة',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 14),
            ),
          ],
          if (result.decidedByTiebreak || result.endedEarly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (result.decidedByTiebreak)
                  InfoChip('حُسمت بجولة الحسم 🔥', color: palette.accent),
                if (result.endedEarly)
                  InfoChip(
                    result.reason == 'not_enough_players'
                        ? 'وقفت اللعبة — ما ضل كفاية لاعبين'
                        : 'انتهت مبكراً بعد ${result.roundsPlayed} جولات',
                    color: palette.warning,
                    icon: Icons.info_outline_rounded,
                  ),
              ],
            ),
          ],
          if (result.finalScores.length >= 2) ...[
            const SizedBox(height: 22),
            _Podium(scores: result.finalScores, viewerId: viewerId),
          ],
        ],
      ),
    );
  }
}

/// منصّة الثلاثة الأوائل: الأول في الوسط وأعلى، كما في أي منصّة تتويج.
class _Podium extends StatelessWidget {
  const _Podium({required this.scores, required this.viewerId});

  final List<Standing> scores;
  final String viewerId;

  static const _heights = [92.0, 66.0, 50.0];
  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final order = [1, 0, if (scores.length > 2) 2];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final place in order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerAvatar(
                    username: scores[place].username,
                    photoUrl: scores[place].photoUrl,
                    avatarId: scores[place].avatarId,
                    size: place == 0 ? 52 : 42,
                    dimmed: scores[place].hasLeft,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    scores[place].username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: scores[place].userId == viewerId
                          ? FontWeight.w900
                          : FontWeight.w700,
                      fontSize: 13.5,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    '${scores[place].total}',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: _heights[place],
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 8),
                    alignment: Alignment.topCenter,
                    decoration: BoxDecoration(
                      color: place == 0
                          ? palette.primary.withValues(alpha: 0.14)
                          : palette.surfaceAlt,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.control),
                      ),
                    ),
                    child: Text(
                      _medals[place],
                      style: const TextStyle(fontSize: 22),
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
