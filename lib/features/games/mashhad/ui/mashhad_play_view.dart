import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../cubit/mashhad_game_cubit.dart';
import '../model/mashhad_models.dart';
import 'widgets/awards_card.dart';
import 'widgets/claims_card.dart';
import 'widgets/mashhad_layout.dart';
import 'widgets/mashhad_phase_header.dart';
import 'widgets/reveal_board.dart';
import 'widgets/role_brief.dart';
import 'widgets/scene_chat.dart';
import 'widgets/scene_scoreboard.dart';
import 'widgets/verdict_card.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
///
/// على الشاشة العريضة يرافق المرحلةَ عمودٌ جانبي بما يخدمها ولا يكرّرها:
/// دوري وأحداثي أثناء المشهد، الأدوار المكشوفة أثناء التصويت، والترتيب العام
/// في الباقي.
class MashhadPlayView extends StatefulWidget {
  const MashhadPlayView({super.key});

  @override
  State<MashhadPlayView> createState() => _MashhadPlayViewState();
}

class _MashhadPlayViewState extends State<MashhadPlayView> {
  /// المرحلة تبقى حيّة حين يظهر العمود الجانبي أو يختفي (تدوير تابلت، تكبير
  /// نافذة): بدونه يضيع نص نصف مكتوب في الشات أو اختيارات ادّعاء لم تُرسل.
  final _stageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final state = context.watch<MashhadGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const SessionSkeleton();

    final side = SessionBody.isSplit(context)
        ? _side(snapshot, round, cubit.viewerId)
        : null;
    final split = side != null;

    // الشات يحجز شريط التنقّل بحقل كتابته، فلا تذييل تحته.
    final canEndEarly =
        round.phase != MashhadPhase.scene && snapshot.me.canEndEarly;

    // المفتاح بالمشهد والمرحلة: كل مرحلة تبدأ من أعلى، وبطاقة الدور تعود
    // مقلوبة في كل مشهد جديد.
    final stageKey = ValueKey('${round.number}-${round.phase}');

    Widget stage(Widget child, {double maxWidth = 560}) => _Stage(
      key: stageKey,
      split: split,
      reserveInset: !canEndEarly,
      maxWidth: maxWidth,
      child: child,
    );

    final main = switch (round.phase) {
      MashhadPhase.roleReveal => stage(
        RoleBrief(
          title: round.title,
          setup: round.setup,
          categoryLabel: round.categoryLabel,
          categoryEmoji: round.categoryEmoji,
          role: round.myRole,
          isSpectator: snapshot.me.isSpectator,
        ),
      ),
      // الشات يملأ العمود بنفسه: له حقل إدخال وتمرير خاصّان به.
      MashhadPhase.scene => SceneChat(
        key: ValueKey('chat-${round.number}'),
        round: round,
        split: split,
      ),
      MashhadPhase.claims => stage(ClaimsCard(round: round)),
      MashhadPhase.challenge => stage(
        RevealBoard(round: round),
        maxWidth: 820,
      ),
      MashhadPhase.verdict => stage(
        round.challenge == null
            ? const VerdictCardSkeleton()
            : VerdictCard(challenge: round.challenge!),
      ),
      MashhadPhase.scoreboard => stage(
        SceneScoreboard(
          scores: round.sceneScores,
          standings: snapshot.standings,
          viewerId: cubit.viewerId,
          showStandings: !split,
        ),
        maxWidth: ContentWidth.standard,
      ),
      MashhadPhase.awards => stage(AwardsCard(round: round), maxWidth: 820),
    };

    return Column(
      children: [
        MashhadPhaseHeader(
          state: state,
          // يمرّ على PopScope في شاشة الجلسة: نفس تأكيد زر الرجوع في النظام.
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: SessionBody(
            main: KeyedSubtree(key: _stageKey, child: main),
            side: side,
            sideWidth: mashhadSideWidth,
            footer: canEndEarly
                ? TextButton.icon(
                    onPressed: () => _confirmEndEarly(context),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('إنهاء مبكّر وعرض الترتيب'),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /// محتوى العمود الجانبي لكل مرحلة — null حين لا يوجد ما يستحقه.
  Widget? _side(MashhadSnapshot snapshot, MashhadRound round, String viewer) {
    final standings = snapshot.standings.isEmpty
        ? null
        : SidePanel(
            children: [
              StandingsCard(standings: snapshot.standings, viewerId: viewer),
            ],
          );

    final cast = _CastCard(
      players: snapshot.seatedPlayers,
      transcript: round.transcript,
      viewerId: viewer,
    );

    return switch (round.phase) {
      MashhadPhase.roleReveal => SidePanel(children: [cast]),
      // دوري وأحداثي من لقطتي أنا وحدي — نفس ما يظهر فوق الشات على الجوال.
      MashhadPhase.scene => SidePanel(
        children: [
          if (round.myRole != null) ...[
            RoleSideCard(role: round.myRole!),
            const SizedBox(height: 16),
          ],
          if (round.myEvents.isNotEmpty) ...[
            SectionCard(
              title: 'أحداث المشهد',
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, event) in round.myEvents.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    SceneEventTile(event: event),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          cast,
        ],
      ),
      // الأدوار انكشفت للجميع قبل التصويت؛ بجانبه تسهّل الحكم على الاعتراض.
      MashhadPhase.verdict when round.rows.isNotEmpty => SidePanel(
        title: 'انكشفت الأدوار',
        children: [RevealBoard(round: round, compact: true)],
      ),
      _ => standings,
    };
  }

  Future<void> _confirmEndEarly(BuildContext context) async {
    final cubit = context.read<MashhadGameCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنهاء اللعبة؟'),
        content: const Text('رح تنعرض النتيجة النهائية بالنقاط الحالية.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('كمّل'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('خلّصها'),
          ),
        ],
      ),
    );

    if (confirmed == true) await cubit.endEarly();
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    super.key,
    required this.child,
    required this.split,
    required this.reserveInset,
    this.maxWidth = 560,
  });

  final Widget child;
  final bool split;

  /// بلا تذييل تحت المسرح، فآخر بطاقة يجب أن تتخطى شريط التنقّل بنفسها.
  final bool reserveInset;

  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: mashhadMainPadding(
      context,
      split: split,
      top: 22,
      bottom: 24,
      maxWidth: maxWidth,
      reserveInset: reserveInset,
    ),
    child: child,
  );
}

/// الممثّلون في العمود الجانبي.
class _CastCard extends StatelessWidget {
  const _CastCard({
    required this.players,
    required this.transcript,
    required this.viewerId,
  });

  final List<MashhadPlayer> players;
  final List<SceneMessage> transcript;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    // اسم الشخصية كما ظهر في الشات نفسه — لا شيء لم يُعرض للجميع أصلاً.
    final roles = <String, String>{
      for (final message in transcript)
        if (message.role != null) message.userId: message.role!,
    };

    return SectionCard(
      title: 'الممثّلين',
      trailing: InfoChip('${players.length}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          for (final player in players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: CastRow(
                player: player,
                caption: player.hasLeft ? 'طلع' : roles[player.id],
                trailing: player.id == viewerId ? const InfoChip('إنت') : null,
              ),
            ),
        ],
      ),
    );
  }
}
