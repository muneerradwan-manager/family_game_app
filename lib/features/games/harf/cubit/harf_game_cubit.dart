import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../data/game_repository.dart';
import '../data/harf_repository.dart';
import '../model/harf_models.dart';
import 'harf_signal.dart';

class HarfGameState extends Equatable {
  const HarfGameState({
    this.snapshot,
    this.loading = true,
    this.error,
    this.draft = const {},
    this.objectedCells = const {},
    this.realtime = RealtimeStatus.connecting,
    this.clockSkewMs = 0,
    this.leaving = false,
  });

  final HarfSnapshot? snapshot;
  final bool loading;
  final String? error;

  /// ما يكتبه اللاعب الآن — يسبق تأكيد السيرفر حتى لا تتلعثم لوحة المفاتيح.
  final Map<String, String> draft;

  /// الخانات التي اعترض عليها هذا اللاعب في الجولة الحالية.
  final Set<String> objectedCells;

  final RealtimeStatus realtime;

  /// فرق ساعة الجهاز عن ساعة السيرفر — كل العدّادات تُصحَّح به.
  final int clockSkewMs;

  final bool leaving;

  HarfRound? get round => snapshot?.round;

  HarfPhase get phase => round?.phase ?? HarfPhase.awaitingLetter;

  /// وقت السيرفر الآن حسب تقدير الجهاز.
  int get serverNow => DateTime.now().millisecondsSinceEpoch + clockSkewMs;

  int remainingMs(int deadline) => (deadline - serverNow).clamp(0, 1 << 31);

  HarfGameState copyWith({
    HarfSnapshot? snapshot,
    bool? loading,
    String? error,
    bool clearError = false,
    Map<String, String>? draft,
    Set<String>? objectedCells,
    RealtimeStatus? realtime,
    int? clockSkewMs,
    bool? leaving,
  }) => HarfGameState(
    snapshot: snapshot ?? this.snapshot,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    draft: draft ?? this.draft,
    objectedCells: objectedCells ?? this.objectedCells,
    realtime: realtime ?? this.realtime,
    clockSkewMs: clockSkewMs ?? this.clockSkewMs,
    leaving: leaving ?? this.leaving,
  );

  @override
  List<Object?> get props => [
    snapshot,
    loading,
    error,
    draft,
    objectedCells,
    realtime,
    clockSkewMs,
    leaving,
  ];
}

/// عقل الجلسة على الجهاز.
///
/// لا يقرّر شيئاً: يعرض ما يبثّه السيرفر ويرسل نوايا اللاعب. المرحلة والحرف
/// والنقاط كلها تصل جاهزة، والدور الوحيد هنا هو ترتيبها للعرض وتصحيح فرق
/// الساعة حتى يرى الجميع العدّاد نفسه.
class HarfGameCubit extends Cubit<HarfGameState> {
  HarfGameCubit({
    required this.games,
    required this.harf,
    required this.realtime,
    required this.gameId,
    required this.viewerId,
  }) : super(const HarfGameState()) {
    _events = realtime.events.listen(_onEvent);
    _status = realtime.status.listen(
      (status) => emit(state.copyWith(realtime: status)),
    );
    // ما فات أثناء الانقطاع لا يُبَث ثانية — نجلب لقطة جديدة بدله.
    _reconnects = realtime.reconnected.listen((_) => refresh());
  }

  final GameRepository games;
  final HarfRepository harf;
  final RealtimeClient realtime;
  final String gameId;
  final String viewerId;

  final _signals = StreamController<HarfSignal>.broadcast();
  late final StreamSubscription<RealtimeEvent> _events;
  late final StreamSubscription<RealtimeStatus> _status;
  late final StreamSubscription<void> _reconnects;
  final _answerDebounce = <String, Timer>{};

  Stream<HarfSignal> get signals => _signals.stream;

  /// صاحب الدور في مرحلة السحب هو وحده من يظهر له زر "اسحب".
  bool get isMyTurnToDraw =>
      state.phase == HarfPhase.awaitingLetter &&
      state.round?.drawerUserId == viewerId;

  // ---------------------------------------------------------------------------
  // دورة الحياة
  // ---------------------------------------------------------------------------

  /// الدخول للجلسة: اشتراك في غرفتها ثم انضمام يعيد اللقطة كاملة.
  Future<void> enter() async {
    emit(state.copyWith(loading: true, clearError: true));

    await realtime.subscribe('game.$gameId');

    try {
      final snapshot = HarfSnapshot.fromJson(
        await games.join(gameId),
        viewerId,
      );

      emit(
        state.copyWith(
          snapshot: snapshot,
          loading: false,
          draft: Map.of(snapshot.round?.myAnswers ?? const {}),
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(loading: false, error: error.message));
    }
  }

  Future<void> refresh() async {
    try {
      final snapshot = HarfSnapshot.fromJson(
        await games.snapshot(gameId),
        viewerId,
      );

      emit(
        state.copyWith(
          snapshot: snapshot,
          loading: false,
          // المسوّدة تُبنى من السيرفر: هو مرجع ما وصل فعلاً.
          draft: Map.of(snapshot.round?.myAnswers ?? const {}),
        ),
      );
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

  void drawLetter() {
    if (state.phase != HarfPhase.awaitingLetter) return;

    harf.drawLetter(gameId);
  }

  /// كل تغيير يُرسَل للسيرفر — لكن بعد سكون قصير حتى لا نرسل طلباً لكل حرف.
  void setAnswer(String column, String text) {
    emit(state.copyWith(draft: {...state.draft, column: text}));

    _answerDebounce[column]?.cancel();
    _answerDebounce[column] = Timer(
      const Duration(milliseconds: 220),
      () => harf.updateAnswer(gameId, column, text),
    );
  }

  /// الزر مقفول حتى تمتلئ كل الخانات — والسيرفر يتحقق مجدداً على أي حال.
  bool get canPressStop {
    final snapshot = state.snapshot;

    if (snapshot == null || !snapshot.me.isPlayer) return false;
    if (state.phase != HarfPhase.writing) return false;
    if (snapshot.round?.stopBy != null) return false;

    return snapshot.config.columns.every(
      (column) => (state.draft[column] ?? '').trim().isNotEmpty,
    );
  }

  void pressStop() {
    if (!canPressStop) return;

    // نُفرغ المؤجّل فوراً: ضغطة الستوب يجب ألا تسبق آخر حرف كتبه اللاعب.
    _flushPendingAnswers();
    harf.pressStop(gameId);
  }

  void raiseObjection({required String targetUserId, required String column}) {
    final key = '$targetUserId|$column';

    if (state.objectedCells.contains(key)) return;

    emit(state.copyWith(objectedCells: {...state.objectedCells, key}));
    harf.raiseObjection(gameId, targetUserId: targetUserId, column: column);
  }

  bool hasObjectedTo(String targetUserId, String column) =>
      state.objectedCells.contains('$targetUserId|$column');

  void castVote({required bool answerIsValid}) {
    final objection = state.round?.objection;

    if (objection == null || objection.isParty || objection.hasVoted) return;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            objection: objection.copyWith(hasVoted: true),
          ),
        ),
      ),
    );

    harf.castVote(gameId, objectionId: objection.id, isValid: answerIsValid);
  }

  void submitTiebreak(String text) => harf.submitTiebreak(gameId, text);

  void clearError() => emit(state.copyWith(clearError: true));

  // ---------------------------------------------------------------------------
  // أحداث القناة الحيّة
  // ---------------------------------------------------------------------------

  void _onEvent(RealtimeEvent event) {
    if (event.channel != 'game.$gameId') return;

    _syncClock(event.serverTime);

    final snapshot = state.snapshot;

    if (snapshot == null) return;

    switch (event.name) {
      case 'lobby_updated':
        _applyLobby(event.data);

      case 'game_started':
        _applyGameStarted(event.data);

      case 'round_started':
        _applyRoundStarted(event.data);

      case 'letter_drawn':
        _applyLetterDrawn(event.data);

      case 'phase_changed':
        _applyPhaseChanged(event.data);

      case 'stop_pressed':
        _applyStopPressed(event.data);

      case 'answers_revealed':
        _applyAnswersRevealed(event.data);

      case 'objection_raised':
        _applyObjectionRaised(event.data);

      case 'objection_opened':
        _applyObjectionOpened(event.data);

      case 'vote_result':
        _applyVoteResult(event.data);

      case 'scoreboard':
        _applyScoreboard(event.data);

      case 'tiebreak_started':
        _signals.add(const TiebreakStarted());

      case 'tiebreak_answered':
        _signals.add(
          GameToast('${event.data['username']} حسمها: ${event.data['answer']}'),
        );

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

    // فرق أقل من نصف ثانية ضجيج شبكة لا انحراف ساعة.
    if ((skew - state.clockSkewMs).abs() < 500) return;

    emit(state.copyWith(clockSkewMs: skew));
  }

  void _applyLobby(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          players: _players(data['players']),
          hostId: '${data['hostId']}',
          totalRounds: (data['totalRounds'] as num?)?.toInt(),
          estimatedSeconds: (data['estimatedSeconds'] as num?)?.toInt(),
          canStart: data['canStart'] == true,
          me: state.snapshot?.me.copyWith(
            isHost: '${data['hostId']}' == viewerId,
          ),
        ),
      ),
    );
  }

  void _applyGameStarted(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          status: 'playing',
          config: HarfConfig.fromJson(
            Map<String, dynamic>.from(data['config'] as Map),
          ),
          order: ((data['order'] as List?) ?? const [])
              .map((id) => '$id')
              .toList(),
          totalRounds: (data['totalRounds'] as num?)?.toInt(),
          players: _players(data['players']),
        ),
      ),
    );
  }

  void _applyRoundStarted(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        draft: const {},
        objectedCells: const {},
        snapshot: state.snapshot?.copyWith(
          currentRound: (data['round'] as num?)?.toInt(),
          totalRounds: (data['totalRounds'] as num?)?.toInt(),
          round: HarfRound(
            number: (data['round'] as num?)?.toInt() ?? 0,
            phase: HarfPhase.awaitingLetter,
            phaseStartedAt: state.serverNow,
            deadline: state.serverNow,
            drawerUserId: '${data['drawerUserId']}',
            objectionsLeft: 3,
          ),
        ),
      ),
    );
  }

  void _applyLetterDrawn(Map<String, dynamic> data) {
    final letter = '${data['letter']}';

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(letter: letter),
        ),
      ),
    );

    _signals.add(LetterRevealed(letter));

    if (data['auto'] == true && state.round?.drawerUserId == viewerId) {
      _signals.add(const GameToast('انتهى الوقت — تم السحب تلقائياً'));
    }
  }

  void _applyPhaseChanged(Map<String, dynamic> data) {
    final phase = HarfPhase.parse(data['phase']);
    final previous = state.round;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          currentRound: (data['round'] as num?)?.toInt(),
          totalRounds: (data['totalRounds'] as num?)?.toInt(),
          round:
              (previous ??
                      HarfRound(
                        number: (data['round'] as num?)?.toInt() ?? 0,
                        phase: phase,
                        phaseStartedAt: 0,
                        deadline: 0,
                        drawerUserId: '${data['drawerUserId']}',
                      ))
                  .copyWith(
                    number: (data['round'] as num?)?.toInt(),
                    phase: phase,
                    phaseStartedAt: (data['phaseStartedAt'] as num?)?.toInt(),
                    deadline: (data['deadline'] as num?)?.toInt(),
                    drawerUserId: '${data['drawerUserId']}',
                    letter: data['letter'] as String?,
                    stopBy: data['stopBy'] as String?,
                    // انتهى التصويت على الاعتراض الحالي.
                    clearObjection: phase != HarfPhase.voting,
                  ),
        ),
      ),
    );
  }

  void _applyStopPressed(Map<String, dynamic> data) {
    final byUserId = '${data['byUserId']}';

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(stopBy: byUserId),
        ),
      ),
    );

    _signals.add(
      StopAnnounced('${data['byUsername']}', isMe: byUserId == viewerId),
    );
  }

  void _applyAnswersRevealed(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            letter: data['letter'] as String?,
            stopBy: data['stopBy'] as String?,
            rows: ((data['rows'] as List?) ?? const [])
                .map(
                  (item) => AnswerRow.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _applyObjectionRaised(Map<String, dynamic> data) {
    if ('${data['by']}' != viewerId) return;

    final left = (state.round?.objectionsLeft ?? 3) - 1;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(objectionsLeft: left.clamp(0, 3)),
        ),
      ),
    );
  }

  void _applyObjectionOpened(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            objection: ObjectionView.fromJson(data, viewerId),
          ),
        ),
      ),
    );

    _signals.add(const ObjectionOpened());
  }

  void _applyVoteResult(Map<String, dynamic> data) {
    final accepted = '${data['verdict']}' != 'invalid';

    _signals.add(VoteDecided(answerAccepted: accepted));
  }

  void _applyScoreboard(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          standings: ((data['standings'] as List?) ?? const [])
              .map(
                (item) =>
                    Standing.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList(),
          round: state.round?.copyWith(
            roundScores: asJsonMap(data['roundScores']).map(
              (key, value) =>
                  MapEntry(key, RoundScore.fromJson(asJsonMap(value))),
            ),
          ),
        ),
      ),
    );

    _signals.add(const RoundScored());
  }

  void _applyFinished(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          status: 'finished',
          result: HarfResult.fromJson(
            Map<String, dynamic>.from(data['result'] as Map),
          ),
        ),
      ),
    );

    _signals.add(const GameOver());
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

  List<HarfPlayer> _players(Object? raw) => ((raw as List?) ?? const [])
      .map(
        (item) => HarfPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  void _flushPendingAnswers() {
    for (final entry in _answerDebounce.entries) {
      if (entry.value.isActive) {
        entry.value.cancel();
        harf.updateAnswer(gameId, entry.key, state.draft[entry.key] ?? '');
      }
    }
  }

  @override
  Future<void> close() async {
    for (final timer in _answerDebounce.values) {
      timer.cancel();
    }

    await _events.cancel();
    await _status.cancel();
    await _reconnects.cancel();
    await realtime.unsubscribe('game.$gameId');
    await _signals.close();

    return super.close();
  }
}
