import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/cubit/auth_cubit.dart';
import '../../data/game_repository.dart';
import '../cubit/harf_game_cubit.dart';
import '../cubit/harf_signal.dart';
import '../data/harf_repository.dart';
import 'harf_lobby_view.dart';
import 'harf_play_view.dart';
import 'harf_result_view.dart';

/// شاشة الجلسة كاملة: لوبي ← لعب ← نتيجة.
///
/// مرحلة واحدة لا ثلاث شاشات: الانتقال بينها يقرّره السيرفر لحظياً، وتفريقها
/// على مسارات تنقّل يفتح باب سباقات (لاعب ينتقل ولاعب لا) في أسوأ لحظة.
class HarfSessionScreen extends StatelessWidget {
  const HarfSessionScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => HarfGameCubit(
      games: context.read<GameRepository>(),
      harf: context.read<HarfRepository>(),
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
  StreamSubscription<HarfSignal>? _signals;

  @override
  void initState() {
    super.initState();

    // الإشارات (صوت واهتزاز ورسالة عابرة) تصل خارج الحالة حتى لا يعيد كل
    // بناء تشغيلها من جديد.
    _signals = context.read<HarfGameCubit>().signals.listen(_onSignal);
  }

  @override
  void dispose() {
    _signals?.cancel();
    super.dispose();
  }

  Future<void> _onSignal(HarfSignal signal) async {
    final feedback = context.read<GameFeedback>();

    switch (signal) {
      case LetterRevealed():
        await feedback.letterRevealed();

      case StopAnnounced(:final username, :final isMe):
        await feedback.stopPressed();

        if (mounted && !isMe) showAppSnack(context, '$username ضغط ستوب!');

      case VoteDecided(:final answerAccepted):
        await feedback.voteDecided();

        if (mounted) {
          showAppSnack(
            context,
            answerAccepted ? 'الإجابة انقبلت ✅' : 'الإجابة انرفضت ❌',
          );
        }

      case RoundScored():
        await feedback.scoreboard();

      case GameOver():
        await feedback.gameFinished();

      case TiebreakStarted():
        if (mounted) showAppSnack(context, 'تعادل! جولة حسم 🔥');

      case ObjectionOpened():
        await feedback.voteDecided();

      case GameToast(:final message):
        if (mounted) showAppSnack(context, message);
    }
  }

  Future<bool> _confirmLeave() async {
    final state = context.read<HarfGameCubit>().state;

    if (state.snapshot?.isFinished ?? true) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بدك تطلع؟'),
        content: Text(
          state.snapshot?.isLobby == true
              ? 'رح تطلع من الغرفة قبل ما تبلّش اللعبة.'
              // اللعبة تكمل بمؤقتاتها؛ جولة الغائب تُسحب تلقائياً.
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

  /// المغادرة تأكيد ثم إبلاغ السيرفر ثم خروج — بهذا الترتيب، حتى لا تُغلق
  /// الشاشة قبل أن يعرف السيرفر أن اللاعب طلع.
  Future<void> _handleLeave() async {
    if (!await _confirmLeave() || !mounted) return;

    await context.read<HarfGameCubit>().leaveGame();

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
        body: BlocConsumer<HarfGameCubit, HarfGameState>(
          listenWhen: (previous, current) => previous.error != current.error,
          listener: (context, state) {
            if (state.error != null) {
              showAppSnack(context, state.error!, isError: true);
              context.read<HarfGameCubit>().clearError();
            }
          },
          builder: (context, state) {
            if (state.loading && state.snapshot == null) {
              // هيكل بشكل الجلسة لا دائرة: مكان الرأس والقائمة محجوز مسبقاً.
              return const SessionSkeleton();
            }

            final snapshot = state.snapshot;

            if (snapshot == null) {
              return AppErrorView(
                message: state.error ?? 'ما قدرنا نفتح اللعبة.',
                onRetry: () => context.read<HarfGameCubit>().enter(),
              );
            }

            final offline = state.realtime != RealtimeStatus.connected;

            final body = switch (snapshot.status) {
              'lobby' => const HarfLobbyView(),
              'playing' => const HarfPlayView(),
              _ => const HarfResultView(),
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

/// انقطاع الاتصال يجب أن يُرى: اللاعب يستحق أن يعرف لماذا تجمّدت الشاشة.
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
