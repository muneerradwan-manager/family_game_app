import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../auth/model/app_user.dart';
import '../cubit/harf_game_cubit.dart';
import '../model/harf_models.dart';
import 'widgets/answers_table.dart';
import 'widgets/letter_stage.dart';
import 'widgets/phase_header.dart';
import 'widgets/scoreboard_view.dart';
import 'widgets/voting_card.dart';
import 'widgets/writing_grid.dart';

/// شاشة اللعب: مرحلة واحدة معروضة في كل لحظة، يقرّرها السيرفر.
class HarfPlayView extends StatelessWidget {
  const HarfPlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HarfGameCubit>().state;
    final snapshot = state.snapshot!;
    final round = state.round;

    if (round == null) return const AppLoader(message: 'عم تجهّز الجولة...');

    return Column(
      children: [
        PhaseHeader(state: state),
        Expanded(
          child: switch (round.phase) {
            HarfPhase.awaitingLetter => const _DrawPhase(),
            HarfPhase.revealLetter => LetterStage(
              letter: round.letter ?? '؟',
              round: round,
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
            HarfPhase.scoreboard => ScoreboardView(
              snapshot: snapshot,
              round: round,
            ),
            HarfPhase.tiebreak => const _TiebreakPhase(),
          },
        ),
        // SafeArea دائماً لا عند وجود الزر فقط: هي التي تحجز ارتفاع شريط
        // تنقّل النظام أسفل الشاشة. بدونها يمتد محتوى المرحلة تحت الشريط
        // ويختفي آخر سطر من الإجابات أو النقاط.
        SafeArea(
          top: false,
          child: snapshot.me.canEndEarly
              ? Padding(
                  padding: context.contentPadding(top: 0, bottom: 8),
                  child: TextButton.icon(
                    onPressed: () => _confirmEndEarly(context),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('إنهاء مبكّر وعرض النتيجة'),
                  ),
                )
              : const SizedBox.shrink(),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyTurn) ...[
              Text(
                // صيغة الخطاب تتبع الجنس: دورك تسحب / دورك تسحبي.
                snapshot.me.isPlayer && _isFemale(context)
                    ? 'دورك تسحبي الحرف!'
                    : 'دورك تسحب الحرف!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
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
                        color: palette.primary.withValues(alpha: 0.35),
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
            ] else ...[
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
          ],
        ),
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

    return SingleChildScrollView(
      padding: context.contentPadding(
        top: 24,
        bottom: 24,
        minHorizontal: 24,
        maxWidth: ContentWidth.form,
      ),
      child: Column(
        children: [
          Text('🔥', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
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
          const SizedBox(height: 26),
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
          const SizedBox(height: 26),
          if (amTied) ...[
            TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: 'اكتب إجابتك'),
              onSubmitted: (value) => cubit.submitTiebreak(value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => cubit.submitTiebreak(_controller.text),
              child: const Text('أرسل'),
            ),
          ] else
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
