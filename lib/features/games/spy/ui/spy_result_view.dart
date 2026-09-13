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
import '../../../../shared/widgets/skeleton.dart';
import '../../data/game_repository.dart';
import '../../harf/ui/widgets/result_share_card.dart' show renderShareCard;
import '../cubit/spy_game_cubit.dart';
import '../model/spy_models.dart';
import 'widgets/spy_layout.dart';
import 'widgets/spy_share_card.dart';
import 'widgets/transcript_view.dart';

/// شاشة النتيجة — وهنا وحدها تُكشف الكلمة وهوية الجاسوس.
///
/// زر "كمان لعبة؟" هو أعلى رافعة لإعادة اللعب: يفتح غرفة جديدة بنفس
/// الإعدادات بدل إعادة المرور بشاشتي الاختيار والشروط.
///
/// على الشاشة العريضة الأزرار وتاريخ الطرد في العمود الجانبي: الكشف
/// والتفاصيل تملأ الوسط، والخطوة التالية في مرمى العين بلا تمرير.
class SpyResultView extends StatefulWidget {
  const SpyResultView({super.key});

  @override
  State<SpyResultView> createState() => _SpyResultViewState();
}

class _SpyResultViewState extends State<SpyResultView> {
  bool _opening = false;
  bool _sharing = false;

  /// نلتقطها أثناء البناء: بطاقة المشاركة تُرسم خارج شجرة هذه الشاشة، فلا
  /// تصلها ألوان الثيم من السياق.
  late AppPalette _palette;

  Future<void> _playAgain() async {
    final snapshot = context.read<SpyGameCubit>().state.snapshot!;
    final router = GoRouter.of(context);

    setState(() => _opening = true);

    try {
      final gameId = await context.read<GameRepository>().openRoom(
        channelId: snapshot.channelId,
        gameType: 'spy',
        config: {
          'category': snapshot.config.category,
          'turnSeconds': snapshot.config.turnSeconds,
          'maxRounds': snapshot.config.maxRounds,
          'lastGuess': snapshot.config.lastGuess,
        },
      );

      router.pushReplacement('/games/$gameId?type=spy');
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final snapshot = state.snapshot!;
    final result = snapshot.result;
    final palette = context.palette;

    _palette = palette;

    if (result == null) return const SessionSkeleton();

    final split = SessionBody.isSplit(context);

    final playAgain = FilledButton.icon(
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
    );

    final share = OutlinedButton.icon(
      onPressed: _sharing ? null : () => _share(result, snapshot),
      icon: _sharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share, size: 18),
      label: const Text('مشاركة'),
    );

    final backToChannel = OutlinedButton(
      onPressed: () => context.go('/channels/${snapshot.channelId}'),
      child: const Text('رجوع للقناة'),
    );

    final ejections = result.ejections.isEmpty
        ? null
        : _EjectionsCard(ejections: result.ejections);

    return Column(
      children: [
        SessionHeader(
          title: 'نتيجة لعبة الجاسوس',
          subtitle: result.categoryLabel == null
              ? null
              : '${result.categoryEmoji ?? ''} ${result.categoryLabel}',
          emoji: '🕵️',
          showBack: false,
          stats: [
            SessionStat('${result.roundsPlayed}', 'جولات'),
            SessionStat('${result.players.length}', 'لاعبين'),
            SessionStat('${result.ejections.length}', 'انطردوا'),
          ],
        ),
        Expanded(
          child: SpyBody(
            main: SpyStage(
              maxWidth: split ? 820 : ContentWidth.standard,
              children: [
                _OutcomeHero(result: result),
                const SizedBox(height: 16),
                _SecretReveal(result: result),
                const SizedBox(height: 16),
                if (result.guess != null) ...[
                  _GuessCard(guess: result.guess!, word: result.word),
                  const SizedBox(height: 16),
                ],
                const SectionTitle('اللاعبين'),
                ResponsiveGrid(
                  minItemWidth: 280,
                  maxColumns: 2,
                  spacing: 10,
                  children: [
                    for (final player in result.players)
                      _PlayerRow(player: player),
                  ],
                ),
                if (!split && ejections != null) ...[
                  const SizedBox(height: 20),
                  ejections,
                ],
                if (snapshot.transcript.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionTitle('كل الأسئلة'),
                  TranscriptView(
                    turns: snapshot.transcript,
                    viewerId: cubit.viewerId,
                    compact: true,
                  ),
                ],
              ],
            ),
            side: SidePanel(
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      playAgain,
                      const SizedBox(height: 10),
                      share,
                      const SizedBox(height: 10),
                      backToChannel,
                    ],
                  ),
                ),
                if (ejections != null) ...[
                  const SizedBox(height: 16),
                  ejections,
                ],
              ],
            ),
            // على العرض الضيق الأزرار تذييل ثابت كما كانت؛ على العريض هي
            // في العمود الجانبي فلا تُكرَّر أسفل الشاشة.
            footer: split
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      playAgain,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: share),
                          const SizedBox(width: 10),
                          Expanded(child: backToChannel),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// مشاركة كصورة أولاً: النتيجة تُقرأ بلمحة في محادثة العيلة، والنص وحده
  /// يضيع بين الرسائل. النص يبقى مرافقاً وبديلاً لو تعذّر الرسم.
  Future<void> _share(SpyResult result, SpySnapshot snapshot) async {
    setState(() => _sharing = true);

    final caption = _caption(result);
    final image = await renderShareCard(
      context: context,
      card: SpyShareCard(
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
    final file = File('${directory.path}/spy-result-${snapshot.gameId}.png');
    await file.writeAsBytes(image);

    await SharePlus.instance.share(
      ShareParams(text: caption, files: [XFile(file.path)]),
    );
  }

  String _caption(SpyResult result) => [
    '🕵️ نتيجة لعبة الجاسوس',
    '',
    result.headline,
    'الكلمة كانت: ${result.word ?? '—'}',
    '',
    '${result.roundsPlayed} جولات · ${result.players.length} لاعبين',
  ].join('\n');
}

/// من فاز — اللحظة الدرامية الأخيرة، ولهذا وحدها تحتفظ بتدرّج الثيم.
class _OutcomeHero extends StatelessWidget {
  const _OutcomeHero({required this.result});

  final SpyResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(switch (result.winner) {
            'spy' => '🕵️',
            'players' => '🎉',
            _ => '🏁',
          }, style: const TextStyle(fontSize: 50)),
          const SizedBox(height: 8),
          Text(
            switch (result.winner) {
              'spy' => 'فاز الجاسوس!',
              'players' => 'فاز اللاعبين!',
              _ => 'خلصت اللعبة',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// كشف السرّ — أول ما تبحث عنه العين حين تنتهي الجلسة.
class _SecretReveal extends StatelessWidget {
  const _SecretReveal({required this.result});

  final SpyResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RevealTile(
              emoji: result.categoryEmoji ?? '🗝️',
              label: 'الكلمة كانت',
              value: result.word ?? '—',
              caption: result.categoryLabel,
              tone: palette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RevealTile(
              emoji: '🕵️',
              label: 'الجاسوس كان',
              value: result.spyUsername ?? '—',
              tone: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealTile extends StatelessWidget {
  const _RevealTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.tone,
    this.caption,
  });

  final String emoji;
  final String label;
  final String value;
  final Color tone;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: palette.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: tone,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            InfoChip(caption!, color: tone),
          ],
        ],
      ),
    );
  }
}

class _GuessCard extends StatelessWidget {
  const _GuessCard({required this.guess, required this.word});

  final SpyGuess guess;
  final String? word;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = guess.correct ? palette.accent : palette.primary;

    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              guess.correct ? '🎯' : '💨',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guess.correct ? 'الجاسوس خمّن صح!' : 'الجاسوس خمّن غلط',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guess.correct
                      ? 'قال "${guess.word}" — وفاز رغم انكشافه.'
                      : 'قال "${guess.word}" والكلمة كانت "${word ?? '—'}".',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    height: 1.5,
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

class _EjectionsCard extends StatelessWidget {
  const _EjectionsCard({required this.ejections});

  final List<Ejection> ejections;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: 'مين طلع بأي جولة',
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final ejection in ejections)
            ListTile(
              dense: true,
              leading: Text(
                ejection.wasSpy ? '🕵️' : '🙅',
                style: const TextStyle(fontSize: 20),
              ),
              title: Text(
                ejection.username,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              subtitle: Text(
                'جولة ${ejection.round} · ${ejection.votes} أصوات',
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final SpyResultPlayer player;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      color: player.wasSpy ? palette.accent.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              player.won ? '🏆' : '',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 6),
          PlayerAvatar(
            username: player.username,
            photoUrl: player.photoUrl,
            avatarId: player.avatarId,
            size: 40,
            dimmed: player.hasLeft,
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
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                if (player.hasLeft)
                  Text(
                    'طلع من اللعبة',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  )
                else if (player.outAtRound != null)
                  Text(
                    'انطرد بجولة ${player.outAtRound}',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (player.wasSpy)
            InfoChip(
              'الجاسوس',
              color: palette.accent,
              icon: Icons.visibility_off,
            ),
        ],
      ),
    );
  }
}
