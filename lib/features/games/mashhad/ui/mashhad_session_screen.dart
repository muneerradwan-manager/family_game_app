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
import '../cubit/mashhad_game_cubit.dart';
import '../cubit/mashhad_signal.dart';
import '../data/mashhad_repository.dart';
import 'mashhad_lobby_view.dart';
import 'mashhad_play_view.dart';
import 'mashhad_result_view.dart';

/// شاشة الجلسة كاملة: لوبي ← مشاهد ← نتيجة.
class MashhadSessionScreen extends StatelessWidget {
  const MashhadSessionScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => MashhadGameCubit(
      games: context.read<GameRepository>(),
      mashhad: context.read<MashhadRepository>(),
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
  StreamSubscription<MashhadSignal>? _signals;

  @override
  void initState() {
    super.initState();

    _signals = context.read<MashhadGameCubit>().signals.listen(_onSignal);
  }

  @override
  void dispose() {
    _signals?.cancel();
    super.dispose();
  }

  Future<void> _onSignal(MashhadSignal signal) async {
    final feedback = context.read<GameFeedback>();

    switch (signal) {
      case SceneOpened(:final title):
        await feedback.scoreboard();

        if (mounted) showAppSnack(context, '🎬 $title');

      case SceneLive():
        await feedback.letterRevealed();

        if (mounted) showAppSnack(context, 'المشهد بلّش — احكوا!');

      case PublicEvent(:final text):
        // الحدث العام يهزّ الجهاز: هو ما يقلب المشهد.
        await feedback.stopPressed();

        if (mounted) showAppSnack(context, text);

      case PrivateEvent():
        await feedback.stopPressed();

        if (mounted) showAppSnack(context, '🤫 وصلك خبر — إلك وحدك!');

      case SomeoneGotSecret(:final username):
        if (mounted) showAppSnack(context, '🤫 $username وصله خبر خاص...');

      case SceneClosed():
        await feedback.voteDecided();

        if (mounted) showAppSnack(context, '⏰ انتهى المشهد!');

      case ClaimsRevealed():
        await feedback.letterRevealed();

        if (mounted) showAppSnack(context, '🎭 انكشفت الأدوار!');

      case ChallengeRaised(:final onMe):
        await feedback.voteDecided();

        if (mounted && onMe) {
          showAppSnack(context, '⚖️ في حدا معترض على ادّعاءك!');
        }

      case VerdictDecided(:final claimStood, :final aboutMe):
        await feedback.voteDecided();

        if (mounted) {
          showAppSnack(context, switch (true) {
            _ when aboutMe && claimStood => 'ادّعاءك صمد ✅',
            _ when aboutMe => 'ادّعاءك سقط ❌',
            _ when claimStood => 'الادّعاء صمد ✅',
            _ => 'الادّعاء سقط ❌',
          });
        }

      case SceneScored(:final myPoints):
        await feedback.scoreboard();

        if (mounted && myPoints != 0) {
          showAppSnack(
            context,
            myPoints > 0 ? 'أخدت $myPoints نقطة' : 'خسرت ${-myPoints} نقطة',
          );
        }

      case AwardsOpened():
        await feedback.scoreboard();

        if (mounted) showAppSnack(context, '🏅 وقت جوائز السهرة');

      case GameOver():
        await feedback.gameFinished();

      case GameToast(:final message):
        if (mounted) showAppSnack(context, message);
    }
  }

  Future<bool> _confirmLeave() async {
    final state = context.read<MashhadGameCubit>().state;

    if (state.snapshot?.isFinished ?? true) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بدك تطلع؟'),
        content: Text(
          state.snapshot?.isLobby == true
              ? 'رح تطلع من الغرفة قبل ما تبلّش اللعبة.'
              // دورك جزء من الحبكة؛ خروجك يترك ثغرة في القصة.
              : 'المشهد رح يكمل بدونك، وبتقدر ترجع بالمشهد الجاي.',
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

    await context.read<MashhadGameCubit>().leaveGame();

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
        // الشات يرفع لوحة المفاتيح: نترك Scaffold يقلّص المساحة بدل أن
        // تغطّي اللوحة حقل الكتابة.
        resizeToAvoidBottomInset: true,
        body: BlocConsumer<MashhadGameCubit, MashhadGameState>(
          listenWhen: (previous, current) => previous.error != current.error,
          listener: (context, state) {
            if (state.error != null) {
              showAppSnack(context, state.error!, isError: true);
              context.read<MashhadGameCubit>().clearError();
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
                onRetry: () => context.read<MashhadGameCubit>().enter(),
              );
            }

            final offline = state.realtime != RealtimeStatus.connected;

            final body = switch (snapshot.status) {
              'lobby' => const MashhadLobbyView(),
              'playing' => const MashhadPlayView(),
              _ => const MashhadResultView(),
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

/// انقطاع الاتصال يجب أن يُرى — وفي لعبة شات هو أهم ما يُرى.
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
