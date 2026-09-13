import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../data/game_repository.dart';
import '../data/spy_repository.dart';
import '../model/spy_models.dart';
import 'spy_signal.dart';

class SpyGameState extends Equatable {
  const SpyGameState({
    this.snapshot,
    this.loading = true,
    this.error,
    this.realtime = RealtimeStatus.connecting,
    this.clockSkewMs = 0,
    this.leaving = false,
    this.selectedTargetId,
  });

  final SpySnapshot? snapshot;
  final bool loading;
  final String? error;
  final RealtimeStatus realtime;

  /// فرق ساعة الجهاز عن ساعة السيرفر — كل العدّادات تُصحَّح به.
  final int clockSkewMs;

  final bool leaving;

  /// من اخترته لتسأله — قبل أن ترسل السؤال.
  final String? selectedTargetId;

  SpyRound? get round => snapshot?.round;

  SpyPhase get phase => round?.phase ?? SpyPhase.roleReveal;

  int get serverNow => DateTime.now().millisecondsSinceEpoch + clockSkewMs;

  SpyGameState copyWith({
    SpySnapshot? snapshot,
    bool? loading,
    String? error,
    bool clearError = false,
    RealtimeStatus? realtime,
    int? clockSkewMs,
    bool? leaving,
    String? selectedTargetId,
    bool clearTarget = false,
  }) => SpyGameState(
    snapshot: snapshot ?? this.snapshot,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    realtime: realtime ?? this.realtime,
    clockSkewMs: clockSkewMs ?? this.clockSkewMs,
    leaving: leaving ?? this.leaving,
    selectedTargetId: clearTarget
        ? null
        : (selectedTargetId ?? this.selectedTargetId),
  );

  @override
  List<Object?> get props => [
    snapshot,
    loading,
    error,
    realtime,
    clockSkewMs,
    leaving,
    selectedTargetId,
  ];
}

/// عقل الجلسة على الجهاز.
///
/// لا يقرّر شيئاً: يعرض ما يبثّه السيرفر ويرسل نوايا اللاعب. وله هنا واجب
/// إضافي تفرضه طبيعة اللعبة — **السرّ لا يصل عبر القناة الحيّة**. فحين تبدأ
/// اللعبة يطلب هذا الصنف لقطة جديدة ليقرأ منها دوره هو وحده: كلمته، أو أنه
/// الجاسوس. لا يمكن استخراج أيّ من الاثنين من الأحداث المبثوثة.
class SpyGameCubit extends Cubit<SpyGameState> {
  SpyGameCubit({
    required this.games,
    required this.spy,
    required this.realtime,
    required this.gameId,
    required this.viewerId,
  }) : super(const SpyGameState()) {
    _events = realtime.events.listen(_onEvent);
    _status = realtime.status.listen(
      (status) => emit(state.copyWith(realtime: status)),
    );
    // ما فات أثناء الانقطاع لا يُبَث ثانية — نجلب لقطة جديدة بدله.
    _reconnects = realtime.reconnected.listen((_) => refresh());
  }

  final GameRepository games;
  final SpyRepository spy;
  final RealtimeClient realtime;
  final String gameId;
  final String viewerId;

  final _signals = StreamController<SpySignal>.broadcast();
  late final StreamSubscription<RealtimeEvent> _events;
  late final StreamSubscription<RealtimeStatus> _status;
  late final StreamSubscription<void> _reconnects;

  Stream<SpySignal> get signals => _signals.stream;

  // ---------------------------------------------------------------------------
  // صلاحيات اللحظة — تُشتق من الحالة لا تُنتظر من السيرفر
  // ---------------------------------------------------------------------------

  /// هل أنا لاعب ما زال في اللعبة (لا متفرّج ولا مخرَج)؟
  bool get amActive {
    final me = state.snapshot?.me;

    return me != null && me.isPlayer && !me.isOut;
  }

  bool get canAsk =>
      state.phase == SpyPhase.asking &&
      amActive &&
      state.round?.currentAskerId == viewerId;

  bool get canAnswer =>
      state.phase == SpyPhase.answering &&
      amActive &&
      state.round?.currentTurn?.targetId == viewerId;

  bool get canVote =>
      state.phase == SpyPhase.voting && amActive && state.round?.myVote == null;

  /// من أستطيع أن أسأله: كل لاعب فعّال غيري.
  List<SpyPlayer> get askableTargets {
    final snapshot = state.snapshot;

    if (snapshot == null) return const [];

    return snapshot.activePlayers
        .where((player) => player.id != viewerId)
        .toList();
  }

  /// من أستطيع أن أصوّت عليه: كل لاعب فعّال غيري.
  List<SpyPlayer> get suspects => askableTargets;

  // ---------------------------------------------------------------------------
  // دورة الحياة
  // ---------------------------------------------------------------------------

  Future<void> enter() async {
    emit(state.copyWith(loading: true, clearError: true));

    await realtime.subscribe('game.$gameId');

    try {
      final snapshot = SpySnapshot.fromJson(await games.join(gameId));

      emit(state.copyWith(snapshot: snapshot, loading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(loading: false, error: error.message));
    }
  }

  Future<void> refresh() async {
    try {
      final snapshot = SpySnapshot.fromJson(await games.snapshot(gameId));

      emit(state.copyWith(snapshot: snapshot, loading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));
    }
  }

  Future<void> leaveGame() async {
    emit(state.copyWith(leaving: true));

    try {
      await games.leave(gameId);
    } on ApiException {
      // المغادرة محلية أولاً؛ السيرفر يكتشف الغياب بمؤقّتاته على أي حال.
    }
  }

  // ---------------------------------------------------------------------------
  // نوايا اللاعب
  // ---------------------------------------------------------------------------

  Future<void> startGame() async {
    try {
      await games.start(gameId);
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));
    }
  }

  Future<void> endEarly() async {
    try {
      await games.endEarly(gameId);
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));
    }
  }

  void selectTarget(String userId) =>
      emit(state.copyWith(selectedTargetId: userId));

  void askQuestion(String question) {
    final target = state.selectedTargetId;

    if (!canAsk || target == null || question.trim().isEmpty) return;

    spy.ask(gameId, targetUserId: target, question: question.trim());
  }

  void answerQuestion(String answer) {
    if (!canAnswer || answer.trim().isEmpty) return;

    spy.answer(gameId, answer.trim());
  }

  void vote(String suspectUserId) {
    if (!canVote || suspectUserId == viewerId) return;

    // نُظهر الاختيار فوراً: انتظار ردّ الشبكة على ضغطة تصويت يبدو كعطل.
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            myVote: suspectUserId,
            votedCount: (state.round?.votedCount ?? 0) + 1,
          ),
        ),
      ),
    );

    spy.vote(gameId, suspectUserId);
  }

  void submitGuess(String word) {
    if (state.phase != SpyPhase.spyGuess) return;
    if (state.snapshot?.me.isSpy != true) return;

    spy.guess(gameId, word);
  }

  void clearError() => emit(state.copyWith(clearError: true));

  // ---------------------------------------------------------------------------
  // أحداث القناة الحيّة
  // ---------------------------------------------------------------------------

  void _onEvent(RealtimeEvent event) {
    if (event.channel != 'game.$gameId') return;

    _syncClock(event.serverTime);

    if (state.snapshot == null) return;

    switch (event.name) {
      case 'lobby_updated':
        _applyLobby(event.data);

      case 'game_started':
        _applyGameStarted(event.data);

      case 'round_started':
        _applyRoundStarted(event.data);

      case 'turn_started':
        _applyTurnStarted(event.data);

      case 'question_asked':
        _applyQuestionAsked(event.data);

      case 'answer_given':
        _applyAnswerGiven(event.data);

      case 'turn_skipped':
        _applyTurnSkipped(event.data);

      case 'voting_started':
        _signals.add(const VotingOpened());

      case 'vote_cast':
        _applyVoteCast(event.data);

      case 'vote_result':
        _applyVoteResult(event.data);

      case 'spy_guess_started':
        _applySpyGuessStarted(event.data);

      case 'phase_changed':
        _applyPhaseChanged(event.data);

      case 'game_finished':
        _applyFinished(event.data);

      case 'player_left':
        _applyPlayerLeft(event.data);

      case 'player_returned':
        _signals.add(GameToast('${event.data['username']} رجع!'));
        unawaited(refresh());

      case 'spectator_joined':
        _signals.add(GameToast('${event.data['username']} عم يتفرج'));

      case 'game_abandoned':
        _signals.add(const GameToast('انلغت اللعبة — ما ضل حدا باللوبي.'));
    }
  }

  /// ساعة الجهاز قد تسبق أو تتأخر عن السيرفر بثوانٍ. نقيس الفرق من كل حدث
  /// فتُعرض العدّادات نفسها على كل الأجهزة مهما اختلفت ساعاتها.
  void _syncClock(int serverTime) {
    if (serverTime == 0) return;

    final skew = serverTime - DateTime.now().millisecondsSinceEpoch;

    if ((skew - state.clockSkewMs).abs() < 500) return;

    emit(state.copyWith(clockSkewMs: skew));
  }

  void _applyLobby(Map<String, dynamic> data) {
    final hostId = '${data['hostId']}';

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          players: _players(data['players']),
          hostId: hostId,
          estimatedSeconds: (data['estimatedSeconds'] as num?)?.toInt(),
          canStart: data['canStart'] == true,
          me: state.snapshot?.me.copyWith(isHost: hostId == viewerId),
        ),
      ),
    );
  }

  /// بدأت اللعبة: نطبّق ما هو عام، ثم نطلب لقطة لنقرأ دورنا السرّي.
  ///
  /// الكلمة وهوية الجاسوس ليستا في هذا الحدث ولا في أي حدث — وهذا مقصود:
  /// ما يمرّ على القناة يصل لكل المشتركين فيها.
  void _applyGameStarted(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          status: 'playing',
          config: SpyConfig.fromJson(
            Map<String, dynamic>.from(data['config'] as Map),
          ),
          categoryLabel: data['categoryLabel'] as String?,
          categoryEmoji: data['categoryEmoji'] as String?,
          maxRounds: (data['config'] as Map?)?['maxRounds'] as int?,
          players: _players(data['players']),
        ),
      ),
    );

    unawaited(refresh());
  }

  void _applyRoundStarted(Map<String, dynamic> data) {
    final round = (data['round'] as num?)?.toInt() ?? 1;

    emit(
      state.copyWith(
        clearTarget: true,
        snapshot: state.snapshot?.copyWith(
          currentRound: round,
          maxRounds: (data['maxRounds'] as num?)?.toInt(),
          round: SpyRound(
            number: round,
            phase: SpyPhase.asking,
            phaseStartedAt: state.serverNow,
            deadline: state.serverNow,
            askQueue: ((data['askOrder'] as List?) ?? const [])
                .map((id) => '$id')
                .toList(),
          ),
        ),
      ),
    );

    _signals.add(RoundOpened(round));
  }

  void _applyTurnStarted(Map<String, dynamic> data) {
    final askerId = '${data['askerId']}';

    emit(
      state.copyWith(
        clearTarget: true,
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            currentAskerId: askerId,
            currentAskerUsername: '${data['askerUsername']}',
            // دور جديد يبدأ بلا سؤال معلّق.
            clearTurn: true,
          ),
        ),
      ),
    );

    if (askerId == viewerId) _signals.add(const MyTurnToAsk());
  }

  void _applyQuestionAsked(Map<String, dynamic> data) {
    final turn = SpyTurn.fromJson(data);

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          transcript: [...?state.snapshot?.transcript, turn],
          round: state.round?.copyWith(currentTurn: turn),
        ),
      ),
    );

    _signals.add(
      turn.targetId == viewerId
          ? QuestionForMe(turn.askerUsername)
          : const QuestionAsked(),
    );
  }

  void _applyAnswerGiven(Map<String, dynamic> data) {
    final turnId = '${data['turnId']}';
    final answer = data['answer'] as String?;
    final unanswered = data['unanswered'] == true;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          transcript: [
            for (final turn in state.snapshot?.transcript ?? const <SpyTurn>[])
              if (turn.id == turnId)
                turn.copyWith(answer: answer, unanswered: unanswered)
              else
                turn,
          ],
        ),
      ),
    );

    if (unanswered) {
      final turn = state.snapshot?.transcript.where((t) => t.id == turnId);

      if (turn != null && turn.isNotEmpty) {
        _signals.add(GameToast('${turn.first.targetUsername} ما جاوب!'));
      }
    }
  }

  void _applyTurnSkipped(Map<String, dynamic> data) {
    final askerId = '${data['askerId']}';

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          transcript: [
            ...?state.snapshot?.transcript,
            SpyTurn(
              id: 'skipped-$askerId-${state.snapshot?.currentRound}',
              round: state.snapshot?.currentRound ?? 0,
              askerId: askerId,
              askerUsername: '${data['askerUsername']}',
              skipped: true,
              unanswered: false,
            ),
          ],
        ),
      ),
    );

    _signals.add(GameToast('${data['askerUsername']} خلص وقته بلا سؤال'));
  }

  void _applyVoteCast(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            votedCount: (data['voted'] as num?)?.toInt(),
            eligibleCount: (data['eligible'] as num?)?.toInt(),
          ),
        ),
      ),
    );
  }

  void _applyVoteResult(Map<String, dynamic> data) {
    final outcome = VoteOutcome.fromJson(data);
    final ejectedId = outcome.ejectedUserId;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(voteResult: outcome),
          // من خرج يبقى في القائمة مُعلَّماً — الشاشة تشطب اسمه لا تخفيه.
          players: [
            for (final player in state.snapshot?.players ?? const <SpyPlayer>[])
              if (player.id == ejectedId)
                SpyPlayer(
                  id: player.id,
                  username: player.username,
                  isSpectator: player.isSpectator,
                  hasLeft: player.hasLeft,
                  outAtRound: state.snapshot?.currentRound,
                  photoUrl: player.photoUrl,
                  avatarId: player.avatarId,
                  gender: player.gender,
                )
              else
                player,
          ],
          me: ejectedId == viewerId
              ? state.snapshot?.me.copyWith(isOut: true)
              : null,
        ),
      ),
    );

    _signals.add(VoteRevealed(caughtSpy: outcome.wasSpy, tie: outcome.tie));
  }

  void _applySpyGuessStarted(Map<String, dynamic> data) {
    final spyUserId = '${data['spyUserId']}';

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            spyUserId: spyUserId,
            spyUsername: '${data['spyUsername']}',
            guessOptions: ((data['options'] as List?) ?? const [])
                .map((word) => '$word')
                .toList(),
          ),
        ),
      ),
    );

    _signals.add(SpyGuessOpened(isMe: spyUserId == viewerId));
  }

  void _applyPhaseChanged(Map<String, dynamic> data) {
    final phase = SpyPhase.parse(data['phase']);
    final previous = state.round;

    final next =
        (previous ??
                SpyRound(
                  number: (data['round'] as num?)?.toInt() ?? 0,
                  phase: phase,
                  phaseStartedAt: 0,
                  deadline: 0,
                ))
            .copyWith(
              number: (data['round'] as num?)?.toInt(),
              phase: phase,
              phaseStartedAt: (data['phaseStartedAt'] as num?)?.toInt(),
              deadline: (data['deadline'] as num?)?.toInt(),
              currentAskerId: data['currentAskerId'] as String?,
              askQueue: ((data['askQueue'] as List?) ?? const [])
                  .map((id) => '$id')
                  .toList(),
            );

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          currentRound: (data['round'] as num?)?.toInt(),
          maxRounds: (data['maxRounds'] as num?)?.toInt(),
          round: next,
        ),
      ),
    );
  }

  void _applyFinished(Map<String, dynamic> data) {
    final result = SpyResult.fromJson(
      Map<String, dynamic>.from(data['result'] as Map),
    );

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(status: 'finished', result: result),
      ),
    );

    final me = result.players.where((player) => player.userId == viewerId);

    _signals.add(GameOver(iWon: me.isNotEmpty && me.first.won));
  }

  void _applyPlayerLeft(Map<String, dynamic> data) {
    _signals.add(GameToast('${data['username']} طلع من اللعبة'));

    final hostId = data['hostId'] as String?;

    if (hostId != null) {
      emit(
        state.copyWith(
          snapshot: state.snapshot?.copyWith(
            hostId: hostId,
            me: state.snapshot?.me.copyWith(isHost: hostId == viewerId),
          ),
        ),
      );
    }

    unawaited(refresh());
  }

  List<SpyPlayer> _players(Object? raw) => ((raw as List?) ?? const [])
      .map((item) => SpyPlayer.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();

  @override
  Future<void> close() async {
    await _events.cancel();
    await _status.cancel();
    await _reconnects.cancel();
    await realtime.unsubscribe('game.$gameId');
    await _signals.close();

    return super.close();
  }
}
