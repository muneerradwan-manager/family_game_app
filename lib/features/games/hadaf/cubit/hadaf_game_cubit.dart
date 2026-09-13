import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../data/game_repository.dart';
import '../data/hadaf_repository.dart';
import '../model/hadaf_models.dart';
import 'hadaf_signal.dart';

class HadafGameState extends Equatable {
  const HadafGameState({
    this.snapshot,
    this.loading = true,
    this.error,
    this.realtime = RealtimeStatus.connecting,
    this.clockSkewMs = 0,
    this.leaving = false,
    this.riskArmed = false,
  });

  final HadafSnapshot? snapshot;
  final bool loading;
  final String? error;
  final RealtimeStatus realtime;

  /// فرق ساعة الجهاز عن ساعة السيرفر — كل العدّادات تُصحَّح به.
  final int clockSkewMs;

  final bool leaving;

  /// ⚡ مُفعّلة: الضغطة التالية على خيار تكون مراهنة.
  final bool riskArmed;

  HadafRound? get round => snapshot?.round;

  HadafPhase get phase => round?.phase ?? HadafPhase.ready;

  int get serverNow => DateTime.now().millisecondsSinceEpoch + clockSkewMs;

  HadafGameState copyWith({
    HadafSnapshot? snapshot,
    bool? loading,
    String? error,
    bool clearError = false,
    RealtimeStatus? realtime,
    int? clockSkewMs,
    bool? leaving,
    bool? riskArmed,
  }) => HadafGameState(
    snapshot: snapshot ?? this.snapshot,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    realtime: realtime ?? this.realtime,
    clockSkewMs: clockSkewMs ?? this.clockSkewMs,
    leaving: leaving ?? this.leaving,
    riskArmed: riskArmed ?? this.riskArmed,
  );

  @override
  List<Object?> get props => [
    snapshot,
    loading,
    error,
    realtime,
    clockSkewMs,
    leaving,
    riskArmed,
  ];
}

/// عقل الجلسة على الجهاز.
///
/// لا يقرّر شيئاً: يعرض ما يبثّه السيرفر ويرسل نيّة واحدة — الإجابة. ولا
/// يرسل معها توقيتاً: **ختم الوصول على السيرفر هو ما يرتّب المتسابقين**،
/// وهذا ما يجعل السباق عادلاً بين جهاز سريع وجهاز بطيء على الشبكة نفسها.
class HadafGameCubit extends Cubit<HadafGameState> {
  HadafGameCubit({
    required this.games,
    required this.hadaf,
    required this.realtime,
    required this.gameId,
    required this.viewerId,
  }) : super(const HadafGameState()) {
    _events = realtime.events.listen(_onEvent);
    _status = realtime.status.listen(
      (status) => emit(state.copyWith(realtime: status)),
    );
    _reconnects = realtime.reconnected.listen((_) => refresh());
  }

  final GameRepository games;
  final HadafRepository hadaf;
  final RealtimeClient realtime;
  final String gameId;
  final String viewerId;

  final _signals = StreamController<HadafSignal>.broadcast();
  late final StreamSubscription<RealtimeEvent> _events;
  late final StreamSubscription<RealtimeStatus> _status;
  late final StreamSubscription<void> _reconnects;

  Stream<HadafSignal> get signals => _signals.stream;

  // ---------------------------------------------------------------------------
  // صلاحيات اللحظة
  // ---------------------------------------------------------------------------

  bool get amPlaying => state.snapshot?.me.isPlayer ?? false;

  /// في جولة الحسم يتسابق المتعادلون وحدهم.
  bool get amRacing {
    final round = state.round;

    if (round == null || !amPlaying) return false;

    if (round.phase == HadafPhase.tiebreak) {
      return round.tiedPlayers.contains(viewerId);
    }

    return round.phase == HadafPhase.question;
  }

  bool get canAnswer => amRacing && !(state.round?.hasAnswered ?? false);

  bool get canArmRisk => canAnswer && (state.snapshot?.me.risksLeft ?? 0) > 0;

  // ---------------------------------------------------------------------------
  // دورة الحياة
  // ---------------------------------------------------------------------------

  Future<void> enter() async {
    emit(state.copyWith(loading: true, clearError: true));

    await realtime.subscribe('game.$gameId');

    try {
      final snapshot = HadafSnapshot.fromJson(await games.join(gameId));

      emit(state.copyWith(snapshot: snapshot, loading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(loading: false, error: error.message));
    }
  }

  Future<void> refresh() async {
    try {
      final snapshot = HadafSnapshot.fromJson(await games.snapshot(gameId));

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

  /// ⚡ قرار واعٍ: تُفعَّل ثم تُختار الإجابة.
  void toggleRisk() {
    if (!canArmRisk && !state.riskArmed) return;

    emit(state.copyWith(riskArmed: !state.riskArmed));
  }

  /// الإجابة تُرسل مرة واحدة ولا تُبدَّل — والسيرفر يتحقق مجدداً.
  void answer(int choice) {
    if (!canAnswer) return;

    final risk = state.riskArmed;

    // نُظهر الاختيار فوراً: انتظار الشبكة في سباق يبدو كعطل.
    emit(
      state.copyWith(
        riskArmed: false,
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(myChoice: choice, myRisk: risk),
          me: risk
              ? state.snapshot?.me.copyWith(
                  risksLeft: (state.snapshot!.me.risksLeft - 1).clamp(0, 99),
                )
              : null,
        ),
      ),
    );

    hadaf.answer(gameId, choice: choice, risk: risk);
    _signals.add(AnswerLocked(usedRisk: risk));
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

      case 'question_opened':
        _applyQuestionOpened(event.data);

      case 'answer_locked':
        _applyAnswerLocked(event.data);

      case 'question_closed':
        _applyQuestionClosed(event.data);

      case 'tiebreak_started':
        _applyTiebreak(event.data);

      case 'tiebreak_decided':
        _signals.add(GameToast('${event.data['username']} حسمها! 🔥'));

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

  void _applyGameStarted(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          status: 'playing',
          config: HadafConfig.fromJson(
            Map<String, dynamic>.from(data['config'] as Map),
          ),
          totalRounds: (data['rounds'] as num?)?.toInt(),
          players: _players(data['players']),
        ),
      ),
    );
  }

  void _applyRoundStarted(Map<String, dynamic> data) {
    final round = (data['round'] as num?)?.toInt() ?? 1;

    emit(
      state.copyWith(
        riskArmed: false,
        snapshot: state.snapshot?.copyWith(
          currentRound: round,
          totalRounds: (data['rounds'] as num?)?.toInt(),
          round: HadafRound(
            number: round,
            phase: HadafPhase.ready,
            phaseStartedAt: state.serverNow,
            deadline: state.serverNow,
            // تشويقة الاستعداد: المجموعة والصعوبة بلا نصّ السؤال.
            question: HadafQuestion(
              category: '${data['category']}',
              difficulty: '${data['difficulty']}',
              categoryLabel: data['categoryLabel'] as String?,
              categoryEmoji: data['categoryEmoji'] as String?,
            ),
          ),
        ),
      ),
    );

    _signals.add(RoundReady(round));
  }

  void _applyQuestionOpened(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            question: HadafQuestion.fromJson(
              Map<String, dynamic>.from(data['question'] as Map),
            ),
          ),
        ),
      ),
    );

    _signals.add(const QuestionOpened());
  }

  /// عدد من أجاب فقط — لا من أصاب: الثاني يكشف الجواب لمن ينتظر.
  void _applyAnswerLocked(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            answeredCount: (data['answered'] as num?)?.toInt(),
            activeCount: (data['total'] as num?)?.toInt(),
          ),
        ),
      ),
    );
  }

  void _applyQuestionClosed(Map<String, dynamic> data) {
    final rows = ((data['rows'] as List?) ?? const [])
        .map(
          (item) => RevealRow.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final mine = rows.where((row) => row.userId == viewerId);
    final myRow = mine.isEmpty ? null : mine.first;

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
            answerIndex: (data['answerIndex'] as num?)?.toInt(),
            explanation: data['explanation'] as String?,
            myCorrect: myRow?.correct ?? false,
            rows: rows,
          ),
          me: myRow == null
              ? null
              : state.snapshot?.me.copyWith(streak: myRow.streak),
        ),
      ),
    );

    _signals.add(
      AnswerRevealed(
        iWasCorrect: myRow?.correct ?? false,
        points: myRow?.points ?? 0,
        rank: myRow?.rank ?? 0,
      ),
    );

    if (myRow != null && myRow.streak >= 3) {
      _signals.add(StreakHit(myRow.streak));
    }
  }

  void _applyTiebreak(Map<String, dynamic> data) {
    final tied = ((data['tiedPlayers'] as List?) ?? const [])
        .map((id) => '$id')
        .toList();

    emit(
      state.copyWith(
        riskArmed: false,
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(tiedPlayers: tied),
        ),
      ),
    );

    _signals.add(TiebreakStarted(amTied: tied.contains(viewerId)));
  }

  void _applyPhaseChanged(Map<String, dynamic> data) {
    final phase = HadafPhase.parse(data['phase']);
    final previous = state.round;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          currentRound: (data['round'] as num?)?.toInt(),
          totalRounds: (data['totalRounds'] as num?)?.toInt(),
          round:
              (previous ??
                      HadafRound(
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
                  ),
        ),
      ),
    );
  }

  void _applyFinished(Map<String, dynamic> data) {
    final result = HadafResult.fromJson(
      Map<String, dynamic>.from(data['result'] as Map),
    );

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(status: 'finished', result: result),
      ),
    );

    _signals.add(GameOver(iWon: result.winnerId == viewerId));
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

  List<HadafPlayer> _players(Object? raw) => ((raw as List?) ?? const [])
      .map(
        (item) => HadafPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
      )
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
