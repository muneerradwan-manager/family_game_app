import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/game_layout.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/harf_game_cubit.dart';
import '../model/harf_models.dart';
import 'widgets/answers_table.dart';
import 'widgets/harf_layout.dart';
import 'widgets/letter_stage.dart';
import 'widgets/phase_header.dart';
import 'widgets/scoreboard_view.dart';
import 'widgets/voting_card.dart';
import 'widgets/writing_grid.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
///
/// على الشاشة العريضة يبقى ترتيب النقاط ومعلومات الجولة ظاهرين في عمود
/// جانبي طوال اللعب، بدل أن يُنتظر مشهد النقاط لرؤيتهما.
class HarfPlayView extends StatelessWidget {
  const HarfPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const SessionSkeleton();

    final main = switch (round.phase) {
      HarfPhase.awaitingLetter => const _DrawPhase(),
      HarfPhase.revealLetter => HarfPaneCenter(
        child: LetterStage(letter: round.letter ?? '؟', round: round),
      ),
      HarfPhase.writing || HarfPhase.grace => const WritingGrid(),
      HarfPhase.reveal || HarfPhase.objection => AnswersTable(
        config: snapshot.config,
        round: round,
        // الاعتراض لا يُفتح إلا بعد أن تنتهي مرحلة القراءة والضحك.
        allowObjections:
            round.phase == HarfPhase.objection && snapshot.me.isPlayer,
      ),
      HarfPhase.voting => const VotingCard(),
      HarfPhase.scoreboard => ScoreboardView(snapshot: snapshot, round: round),
      HarfPhase.tiebreak => const _TiebreakPhase(),
    };

    return Column(
      children: [
        PhaseHeader(state: state),
        Expanded(
          child: HarfSessionBody(
            main: main,
            side: _PlaySidePanel(state: state),
            footer: snapshot.me.canEndEarly
                ? TextButton.icon(
                    onPressed: () => _confirmEndEarly(context),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('إنهاء مبكّر وعرض النتيجة'),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmEndEarly(BuildContext context) async {
    final cubit = context.read<HarfGameCubit>();

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

/// العمود الجانبي أثناء اللعب (الشاشة العريضة وحدها).
///
/// في مشهد النقاط يعرض المحتوى الرئيسي الترتيب نفسه، فيعرض العمود ترتيب
/// الأدوار بدله — تكرار اللوحة نفسها مرتين بجانب بعضهما يشتّت ولا يضيف.
class _PlaySidePanel extends StatelessWidget {
  const _PlaySidePanel({required this.state});

  final HarfGameState state;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot!;
    final round = state.round!;
    final drawer = snapshot.playerById(round.drawerUserId);

    return SidePanel(
      children: [
        SectionCard(
          title: 'الجولة',
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              HarfDetailRow(
                icon: Icons.flag_outlined,
                label: 'الجولة',
                value: '${round.number} من ${snapshot.totalRounds}',
              ),
              HarfDetailRow(
                icon: Icons.sort_by_alpha,
                label: 'الحرف',
                value: round.phase == HarfPhase.awaitingLetter
                    ? '—'
                    : (round.letter ?? '—'),
              ),
              HarfDetailRow(
                icon: Icons.casino_outlined,
                label: 'دور السحب',
                value: drawer?.username ?? '—',
              ),
              HarfDetailRow(
                icon: Icons.timer_outlined,
                label: 'وقت الكتابة',
                value: '${snapshot.config.writeSeconds} ثانية',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (round.phase == HarfPhase.scoreboard)
          _TurnOrderCard(snapshot: snapshot, drawerId: round.drawerUserId)
        else
          _LiveStandingsCard(snapshot: snapshot, round: round),
      ],
    );
  }
}

class _LiveStandingsCard extends StatelessWidget {
  const _LiveStandingsCard({required this.snapshot, required this.round});

  final HarfSnapshot snapshot;
  final HarfRound round;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final viewerId = context.read<HarfGameCubit>().viewerId;
    final standings = snapshot.standings;

    return SectionCard(
      title: 'النقاط',
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < standings.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _SideRow(
              leading: '${index + 1}',
              highlight: standings[index].userId == viewerId,
              avatar: PlayerAvatar(
                username: standings[index].username,
                photoUrl: standings[index].photoUrl,
                avatarId: standings[index].avatarId,
                size: 32,
                dimmed: standings[index].hasLeft,
              ),
              name: standings[index].username,
              badge: standings[index].userId == round.stopBy
                  ? InfoChip('ضغط ستوب', color: palette.accent)
                  : standings[index].userId == round.drawerUserId
                  ? Icon(
                      Icons.casino_outlined,
                      size: 16,
                      color: palette.textMuted,
                    )
                  : null,
              trailing: Text(
                '${standings[index].total}',
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TurnOrderCard extends StatelessWidget {
  const _TurnOrderCard({required this.snapshot, required this.drawerId});

  final HarfSnapshot snapshot;
  final String drawerId;

  @override
  Widget build(BuildContext context) {
    final players = [for (final id in snapshot.order) ?snapshot.playerById(id)];

    return SectionCard(
      title: 'ترتيب الأدوار',
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < players.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _SideRow(
              leading: '${index + 1}',
              highlight: players[index].id == drawerId,
              avatar: PlayerAvatar(
                username: players[index].username,
                photoUrl: players[index].photoUrl,
                avatarId: players[index].avatarId,
                gender: Gender.parse(players[index].gender),
                size: 32,
                dimmed: players[index].hasLeft,
              ),
              name: players[index].username,
              badge: players[index].id == drawerId
                  ? const InfoChip('دور السحب')
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _SideRow extends StatelessWidget {
  const _SideRow({
    required this.leading,
    required this.avatar,
    required this.name,
    this.highlight = false,
    this.badge,
    this.trailing,
  });

  final String leading;
  final Widget avatar;
  final String name;
  final bool highlight;
  final Widget? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      color: highlight ? palette.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              leading,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: palette.textMuted,
              ),
            ),
          ),
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 6), badge!],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// سحب الحرف: صاحب الدور يضغط، والعدّاد ظاهر للجميع.
///
/// السيرفر هو من يسحب في الحالتين — بالضغطة أو بانتهاء المهلة — فلا فرق
/// بين من ضغط ومن تأخّر إلا في الشعور.
class _DrawPhase extends StatelessWidget {
  const _DrawPhase();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HarfGameCubit>();
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final drawer = snapshot.playerById(state.round!.drawerUserId);
    final isMyTurn = cubit.isMyTurnToDraw;
    final palette = context.palette;

    if (!isMyTurn) {
      return HarfPaneCenter(
        child: SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              PlayerAvatar(
                username: drawer?.username ?? '',
                photoUrl: drawer?.photoUrl,
                avatarId: drawer?.avatarId,
                gender: Gender.parse(drawer?.gender),
                size: 84,
              ),
              const SizedBox(height: 18),
              Text(
                'دور ${drawer?.username ?? 'اللاعب'} يسحب الحرف',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return HarfPaneCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // صيغة الخطاب تتبع الجنس: دورك تسحب / دورك تسحبي.
            snapshot.me.isPlayer && _isFemale(context)
                ? 'دورك تسحبي الحرف!'
                : 'دورك تسحب الحرف!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          // الزر لحظة اللعبة الأوضح، فيحتفظ بتدرّج الثيم وحده في الشاشة.
          GestureDetector(
            onTap: cubit.drawLetter,
            child: Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: palette.headerGradient),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.30),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'اسحب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'إذا خلص الوقت، السيرفر بيسحب عنك — بلا عقوبة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  bool _isFemale(BuildContext context) {
    final state = context.read<HarfGameCubit>().state;
    final me = state.snapshot?.playerById(
      context.read<HarfGameCubit>().viewerId,
    );

    return Gender.parse(me?.gender) == Gender.female;
  }
}

/// جولة الحسم: حرف واحد وعمود واحد، وأول إجابة صحيحة تصل بختم السيرفر تحسم.
class _TiebreakPhase extends StatefulWidget {
  const _TiebreakPhase();

  @override
  State<_TiebreakPhase> createState() => _TiebreakPhaseState();
}

class _TiebreakPhaseState extends State<_TiebreakPhase> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HarfGameCubit>();
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round!;
    final palette = context.palette;
    final amTied = round.tiedPlayers.contains(cubit.viewerId);
    final column = round.tiebreakColumn;

    return HarfPaneCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            'تعادل! جولة حسم',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أول إجابة صحيحة توصل بتفوز',
            style: TextStyle(color: palette.textMuted),
          ),
          const SizedBox(height: 24),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: palette.headerGradient),
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            child: Text(
              round.letter ?? '؟',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 58,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          InfoChip(
            column == null ? '' : snapshot.config.labelOf(column),
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 24),
          if (amTied)
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(hintText: 'اكتب إجابتك'),
                    onSubmitted: (value) => cubit.submitTiebreak(value),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => cubit.submitTiebreak(_controller.text),
                    child: const Text('أرسل'),
                  ),
                ],
              ),
            )
          else
            SectionCard(
              color: palette.surfaceAlt,
              child: Text(
                'المتعادلين عم يتسابقوا — تفرّج!',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
