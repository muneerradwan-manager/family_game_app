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
import '../../../../shared/widgets/countdown.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../data/game_repository.dart';
import '../cubit/harf_game_cubit.dart';
import '../model/harf_models.dart';
import 'widgets/harf_layout.dart';
import 'widgets/result_share_card.dart';

/// شاشة النتيجة.
///
/// زر "كمان لعبة؟" هو أعلى رافعة لإعادة اللعب في التطبيق كله: يفتح غرفة
/// جديدة بنفس الإعدادات بدل إعادة المرور بشاشتي الاختيار والشروط.
///
/// على الشاشة العريضة الأزرار في العمود الجانبي بجانب اللوحة، فتبقى في مرمى
/// العين مهما طالت القائمة؛ على الأضيق في تذييل ثابت.
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

    if (result == null) return const SessionSkeleton();

    final winner = result.winner;
    final scores = result.finalScores;
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

    return Column(
      children: [
        SessionHeader(
          title: 'لعبة الحروف',
          subtitle: winner == null
              ? 'خلصت اللعبة'
              : 'الفائز: ${winner.username}',
          emoji: '🔠',
          showBack: false,
          stats: [
            SessionStat('${result.roundsPlayed}', 'جولة'),
            SessionStat('${scores.length}', 'لاعبين'),
            if (winner != null) SessionStat('${winner.total}', 'نقطة'),
          ],
        ),
        Expanded(
          child: HarfSessionBody(
            main: HarfPaneList(
              maxWidth: split ? ContentWidth.wide : ContentWidth.standard,
              children: [
                _WinnerCard(result: result),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'اللوحة النهائية',
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var index = 0; index < scores.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _FinalRow(rank: index + 1, standing: scores[index]),
                      ],
                    ],
                  ),
                ),
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
                const SizedBox(height: 16),
                _ResultDetails(result: result, config: snapshot.config),
              ],
            ),
            // بلا تذييل على الشاشة العريضة: الأزرار نفسها في العمود الجانبي.
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

/// الفائز ومنصّة الثلاثة الأوائل — لحظة الاحتفال الوحيدة في الشاشة، فتحتفظ
/// بلمسة التدرّج على عمود المركز الأول.
class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.result});

  final HarfResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final winner = result.winner;
    final scores = result.finalScores;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 46)),
          const SizedBox(height: 8),
          Text(
            winner == null ? 'خلصت اللعبة' : 'الفائز: ${winner.username}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (winner != null) ...[
            const SizedBox(height: 2),
            Text(
              '${winner.total} نقطة',
              style: TextStyle(color: palette.textMuted, fontSize: 15),
            ),
          ],
          if (result.decidedByTiebreak || result.endedEarly) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (result.decidedByTiebreak)
                  InfoChip(
                    'حُسمت بجولة الحسم',
                    color: palette.accent,
                    icon: Icons.local_fire_department_outlined,
                  ),
                if (result.endedEarly)
                  InfoChip(
                    result.reason == 'not_enough_players'
                        ? 'وقفت اللعبة — ما ضل كفاية لاعبين'
                        : 'انتهت مبكراً بعد ${result.roundsPlayed} جولات',
                    color: palette.warning,
                    icon: Icons.info_outline,
                  ),
              ],
            ),
          ],
          // المنصّة من لاعبَين فأكثر: لاعب واحد على منصّة يبدو خطأً لا احتفالاً.
          if (scores.length >= 2) ...[
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _PodiumStep(rank: 2, standing: scores[1])),
                  const SizedBox(width: 10),
                  Expanded(child: _PodiumStep(rank: 1, standing: scores[0])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: scores.length >= 3
                        ? _PodiumStep(rank: 3, standing: scores[2])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({required this.rank, required this.standing});

  final int rank;
  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final first = rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerAvatar(
          username: standing.username,
          photoUrl: standing.photoUrl,
          avatarId: standing.avatarId,
          size: first ? 60 : 46,
          dimmed: standing.hasLeft,
        ),
        const SizedBox(height: 6),
        Text(
          standing.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: first ? 14.5 : 13,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: switch (rank) {
            1 => 76,
            2 => 56,
            _ => 42,
          },
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: first
                ? LinearGradient(
                    colors: palette.headerGradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: first ? null : palette.surfaceAlt,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.control),
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(switch (rank) {
                1 => '🥇',
                2 => '🥈',
                _ => '🥉',
              }, style: const TextStyle(fontSize: 18)),
              Text(
                '${standing.total}',
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: first ? Colors.white : palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// تفاصيل اللعبة في العمود الجانبي.
class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.result, required this.config});

  final HarfResult result;
  final HarfConfig config;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'تفاصيل اللعبة',
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Column(
      children: [
        HarfDetailRow(
          icon: Icons.flag_outlined,
          label: 'الجولات',
          value: '${result.roundsPlayed}',
        ),
        HarfDetailRow(
          icon: Icons.people_outline,
          label: 'اللاعبين',
          value: '${result.finalScores.length}',
        ),
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
      ],
    ),
  );
}

class _FinalRow extends StatelessWidget {
  const _FinalRow({required this.rank, required this.standing});

  final int rank;
  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPodium = rank <= 3;

    return Container(
      color: rank == 1 ? palette.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
