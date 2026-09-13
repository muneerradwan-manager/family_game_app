import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../auth/cubit/auth_cubit.dart';
import '../../data/game_repository.dart';
import '../cubit/hadaf_game_cubit.dart';
import '../cubit/hadaf_signal.dart';
import '../data/hadaf_repository.dart';
import 'hadaf_lobby_view.dart';
import 'hadaf_play_view.dart';
import 'hadaf_result_view.dart';

/// شاشة الجلسة كاملة: لوبي ← لعب ← نتيجة.
class HadafSessionScreen extends StatelessWidget {
  const HadafSessionScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => HadafGameCubit(
      games: context.read<GameRepository>(),
      hadaf: context.read<HadafRepository>(),
      realtime: context.read<RealtimeClient>(),
      gameId: gameId,
      viewerId: context.read<AuthCubit>().state.userId,
    )..enter(),
    child: const _SessionView(),
  );
}

class _SessionView extends StatefulWidget {
  const _SessionView();

  @override
  State<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<_SessionView> {
  StreamSubscription<HadafSignal>? _signals;

  @override
  void initState() {
    super.initState();

    _signals = context.read<HadafGameCubit>().signals.listen(_onSignal);
  }

  @override
  void dispose() {
    _signals?.cancel();
    super.dispose();
  }

  Future<void> _onSignal(HadafSignal signal) async {
    final feedback = context.read<GameFeedback>();

    switch (signal) {
      case RoundReady(:final round):
        await feedback.scoreboard();

        if (mounted && round > 1) showAppSnack(context, 'تحدّي $round');

      case QuestionOpened():
        // انطلاق: اهتزاز وصوت — اللحظة التي يبدأ فيها السباق فعلاً.
        await feedback.letterRevealed();

      case AnswerLocked(:final usedRisk):
        await feedback.stopPressed();

        if (mounted && usedRisk) showAppSnack(context, '⚡ راهنت — بالتوفيق!');

      case AnswerRevealed(:final iWasCorrect, :final points, :final rank):
        await feedback.voteDecided();

        if (mounted) {
          showAppSnack(context, switch (true) {
            _ when iWasCorrect && rank == 1 => '🥇 الأسرع! +$points',
            _ when iWasCorrect => '✅ صح +$points',
            _ when points < 0 => '❌ غلط $points',
            _ => '❌ غلط',
          });
        }

      case StreakHit(:final streak):
        await feedback.scoreboard();

        if (mounted) showAppSnack(context, '🔥 $streak صحيحة ورا بعض!');

      case TiebreakStarted(:final amTied):
        await feedback.stopPressed();

        if (mounted) {
          showAppSnack(
            context,
            amTied ? 'تعادل! جولة حسم 🔥' : 'تعادل — المتعادلين عم يتسابقوا',
          );
        }

      case GameOver():
        await feedback.gameFinished();

      case GameToast(:final message):
        if (mounted) showAppSnack(context, message);
    }
  }

  Future<bool> _confirmLeave() async {
    final state = context.read<HadafGameCubit>().state;

    if (state.snapshot?.isFinished ?? true) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بدك تطلع؟'),
        content: Text(
          state.snapshot?.isLobby == true
              ? 'رح تطلع من الغرفة قبل ما تبلّش اللعبة.'
              : 'اللعبة رح تكمل بدونك، وبتقدر ترجع خلال جولتين بنقاطك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('كمّل لعب'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('اطلع'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// المغادرة تأكيد ثم إبلاغ السيرفر ثم خروج — بهذا الترتيب.
  Future<void> _handleLeave() async {
    if (!await _confirmLeave() || !mounted) return;

    await context.read<HadafGameCubit>().leaveGame();

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleLeave();
      },
      child: Scaffold(
        body: BlocConsumer<HadafGameCubit, HadafGameState>(
          listenWhen: (previous, current) => previous.error != current.error,
          listener: (context, state) {
            if (state.error != null) {
              showAppSnack(context, state.error!, isError: true);
              context.read<HadafGameCubit>().clearError();
            }
          },
          builder: (context, state) {
            if (state.loading && state.snapshot == null) {
              return const AppLoader(message: 'عم ندخّلك على اللعبة...');
            }

            final snapshot = state.snapshot;

            if (snapshot == null) {
              return AppErrorView(
                message: state.error ?? 'ما قدرنا نفتح اللعبة.',
                onRetry: () => context.read<HadafGameCubit>().enter(),
              );
            }

            final offline = state.realtime != RealtimeStatus.connected;

            final body = switch (snapshot.status) {
              'lobby' => const HadafLobbyView(),
              'playing' => const HadafPlayView(),
              _ => const HadafResultView(),
            };

            return Column(
              children: [
                if (offline) const _OfflineBanner(),
                Expanded(
                  // الشريط استهلك حشوة شريط الحالة، فنخفيها عمّا تحته وإلا
                  // أضافها رأس المرحلة مرة ثانية ونزل المحتوى مرتين.
                  child: offline
                      ? MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: body,
                        )
                      : body,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// انقطاع الاتصال يجب أن يُرى — وفي لعبة سرعة هو أهم ما يُرى.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: context.palette.accent,
    padding: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + 6,
      bottom: 6,
    ),
    child: const Text(
      'عم نحاول نرجع الاتصال...',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}
