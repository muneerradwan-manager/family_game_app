import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_client.dart';
import '../../data/game_repository.dart';
import '../data/mashhad_repository.dart';
import '../model/mashhad_models.dart';
import 'mashhad_signal.dart';

class MashhadGameState extends Equatable {
  const MashhadGameState({
    this.snapshot,
    this.loading = true,
    this.error,
    this.realtime = RealtimeStatus.connecting,
    this.clockSkewMs = 0,
    this.leaving = false,
    this.challengedCells = const {},
  });

  final MashhadSnapshot? snapshot;
  final bool loading;
  final String? error;
  final RealtimeStatus realtime;

  /// فرق ساعة الجهاز عن ساعة السيرفر — كل العدّادات تُصحَّح به.
  final int clockSkewMs;

  final bool leaving;

  /// الادّعاءات التي اعترضت عليها في هذا المشهد.
  final Set<String> challengedCells;

  MashhadRound? get round => snapshot?.round;

  MashhadPhase get phase => round?.phase ?? MashhadPhase.roleReveal;

  int get serverNow => DateTime.now().millisecondsSinceEpoch + clockSkewMs;

  MashhadGameState copyWith({
    MashhadSnapshot? snapshot,
    bool? loading,
    String? error,
    bool clearError = false,
    RealtimeStatus? realtime,
    int? clockSkewMs,
    bool? leaving,
    Set<String>? challengedCells,
  }) => MashhadGameState(
    snapshot: snapshot ?? this.snapshot,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    realtime: realtime ?? this.realtime,
    clockSkewMs: clockSkewMs ?? this.clockSkewMs,
    leaving: leaving ?? this.leaving,
    challengedCells: challengedCells ?? this.challengedCells,
  );

  @override
  List<Object?> get props => [
    snapshot,
    loading,
    error,
    realtime,
    clockSkewMs,
    leaving,
    challengedCells,
  ];
}

/// عقل الجلسة على الجهاز.
///
/// لا يقرّر شيئاً: يعرض ما يبثّه السيرفر ويرسل نوايا اللاعب. وله هنا واجب
/// السرّية المزدوج — **دوري وهدفي وسرّي** لا تصل عبر القناة الحيّة، و**الحدث
/// الخاص** كذلك. كلها تأتي في اللقطة مبنيّةً على هويتي أنا. ولهذا حين يبدأ
/// مشهد جديد يطلب هذا الصنف لقطةً ليقرأ دوره فيه.
class MashhadGameCubit extends Cubit<MashhadGameState> {
  MashhadGameCubit({
    required this.games,
    required this.mashhad,
    required this.realtime,
    required this.gameId,
    required this.viewerId,
  }) : super(const MashhadGameState()) {
    _events = realtime.events.listen(_onEvent);
    _status = realtime.status.listen(
      (status) => emit(state.copyWith(realtime: status)),
    );
    _reconnects = realtime.reconnected.listen((_) => refresh());
  }

  final GameRepository games;
  final MashhadRepository mashhad;
  final RealtimeClient realtime;
  final String gameId;
  final String viewerId;

  final _signals = StreamController<MashhadSignal>.broadcast();
  late final StreamSubscription<RealtimeEvent> _events;
  late final StreamSubscription<RealtimeStatus> _status;
  late final StreamSubscription<void> _reconnects;

  Stream<MashhadSignal> get signals => _signals.stream;

  // ---------------------------------------------------------------------------
  // صلاحيات اللحظة
  // ---------------------------------------------------------------------------

  bool get amPlaying => state.snapshot?.me.isPlayer ?? false;

  bool get canSay => amPlaying && state.phase == MashhadPhase.scene;

  bool get canClaim =>
      amPlaying &&
      state.phase == MashhadPhase.claims &&
      !(state.round?.hasClaimed ?? false);

  bool get canChallenge =>
      amPlaying &&
      state.phase == MashhadPhase.challenge &&
      (state.round?.challengesLeft ?? 0) > 0;

  bool get canVote {
    final challenge = state.round?.challenge;

    return amPlaying &&
        state.phase == MashhadPhase.verdict &&
        challenge != null &&
        !challenge.isParty &&
        !challenge.hasVoted;
  }

  /// من أستطيع التصويت له بجائزة: كل لاعب غيري.
  List<MashhadPlayer> get awardCandidates {
    final snapshot = state.snapshot;

    if (snapshot == null) return const [];

    return snapshot.seatedPlayers
        .where((player) => player.id != viewerId)
        .toList();
  }

  bool hasChallenged(String targetUserId, String kind) =>
      state.challengedCells.contains('$targetUserId|$kind');

  // ---------------------------------------------------------------------------
  // دورة الحياة
  // ---------------------------------------------------------------------------

  Future<void> enter() async {
    emit(state.copyWith(loading: true, clearError: true));

    await realtime.subscribe('game.$gameId');

    try {
      final snapshot = MashhadSnapshot.fromJson(await games.join(gameId));

      emit(state.copyWith(snapshot: snapshot, loading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(loading: false, error: error.message));
    }
  }

  Future<void> refresh() async {
    try {
      final snapshot = MashhadSnapshot.fromJson(await games.snapshot(gameId));

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

  void say(String text) {
    if (!canSay || text.trim().isEmpty) return;

    mashhad.say(gameId, text.trim());
  }

  void claim({required bool main, bool bonus = false, bool event = false}) {
    if (!canClaim) return;

    // نُظهر الادّعاء فوراً: انتظار الشبكة على ضغطة زر يبدو كعطل.
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            myClaim: MyClaim(main: main, bonus: bonus, event: event),
            claimedCount: (state.round?.claimedCount ?? 0) + 1,
          ),
        ),
      ),
    );

    mashhad.claim(gameId, main: main, bonus: bonus, event: event);
  }

  void challenge({required String targetUserId, required String kind}) {
    if (!canChallenge || targetUserId == viewerId) return;

    final key = '$targetUserId|$kind';

    if (state.challengedCells.contains(key)) return;

    emit(
      state.copyWith(
        challengedCells: {...state.challengedCells, key},
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            challengesLeft: ((state.round?.challengesLeft ?? 1) - 1).clamp(
              0,
              9,
            ),
          ),
        ),
      ),
    );

    mashhad.challenge(gameId, targetUserId: targetUserId, kind: kind);
  }

  void vote({required bool achieved}) {
    final challenge = state.round?.challenge;

    if (!canVote || challenge == null) return;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            challenge: challenge.copyWith(hasVoted: true),
          ),
        ),
      ),
    );

    mashhad.vote(gameId, challengeId: challenge.id, achieved: achieved);
  }

  void voteAward({required String awardKey, required String targetUserId}) {
    if (!amPlaying || state.phase != MashhadPhase.awards) return;
    if (targetUserId == viewerId) return;
    if (state.round?.myAwardVotes.containsKey(awardKey) ?? false) return;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            myAwardVotes: {
              ...?state.round?.myAwardVotes,
              awardKey: targetUserId,
            },
          ),
        ),
      ),
    );

    mashhad.award(gameId, awardKey: awardKey, targetUserId: targetUserId);
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

      case 'scene_started':
        _applySceneStarted(event.data);

      case 'said':
        _applySaid(event.data);

      case 'scene_event':
        _applyPublicEvent(event.data);

      case 'private_event_sent':
        _applyPrivateEvent(event.data);

      case 'scene_ended':
        _signals.add(const SceneClosed());

      case 'claims_revealed':
        _applyClaimsRevealed(event.data);

      case 'claim_locked':
        _applyClaimLocked(event.data);

      case 'challenge_raised':
        _applyChallengeRaised(event.data);

      case 'verdict_opened':
        _applyVerdictOpened(event.data);

      case 'verdict_result':
        _applyVerdictResult(event.data);

      case 'scene_scored':
        _applySceneScored(event.data);

      case 'awards_started':
        _applyAwardsStarted(event.data);

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
          config: MashhadConfig.fromJson(
            Map<String, dynamic>.from(data['config'] as Map),
          ),
          totalScenes: (data['scenes'] as num?)?.toInt(),
          players: _players(data['players']),
        ),
      ),
    );
  }

  /// بدأ مشهد: الحبكة عامة، أما دوري فأطلبه في لقطة خاصة.
  ///
  /// الأدوار والأهداف والأسرار لا تمرّ على القناة — وهذا مقصود: ما يمرّ عليها
  /// يصل لكل المشتركين فيها.
  void _applySceneStarted(Map<String, dynamic> data) {
    final scene = (data['scene'] as num?)?.toInt() ?? 1;

    emit(
      state.copyWith(
        challengedCells: const {},
        snapshot: state.snapshot?.copyWith(
          currentScene: scene,
          totalScenes: (data['totalScenes'] as num?)?.toInt(),
          round: MashhadRound(
            number: scene,
            phase: MashhadPhase.roleReveal,
            phaseStartedAt: state.serverNow,
            deadline: state.serverNow,
            title: '${data['title']}',
            setup: '${data['setup']}',
            categoryLabel: data['categoryLabel'] as String?,
            categoryEmoji: data['categoryEmoji'] as String?,
          ),
        ),
      ),
    );

    _signals.add(SceneOpened('${data['title']}'));
    unawaited(refresh());
  }

  void _applySaid(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            transcript: [
              ...?state.round?.transcript,
              SceneMessage.fromJson(data),
            ],
          ),
        ),
      ),
    );
  }

  void _applyPublicEvent(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            myEvents: [
              ...?state.round?.myEvents,
              SceneEvent(
                text: '${data['text']}',
                scope: 'all',
                at: state.serverNow,
              ),
            ],
          ),
        ),
      ),
    );

    _signals.add(PublicEvent('${data['text']}'));
  }

  /// وصل حدث خاص لأحدهم. نصّه لا يُبَث — من وصله يقرؤه في لقطته وحده.
  void _applyPrivateEvent(Map<String, dynamic> data) {
    final userId = '${data['userId']}';

    if (userId == viewerId) {
      _signals.add(const PrivateEvent());
      unawaited(refresh());

      return;
    }

    final player = state.snapshot?.playerById(userId);

    _signals.add(SomeoneGotSecret(player?.username ?? 'حدا'));
  }

  void _applyClaimLocked(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            claimedCount: (data['claimed'] as num?)?.toInt(),
            activeCount: (data['total'] as num?)?.toInt(),
          ),
        ),
      ),
    );
  }

  void _applyClaimsRevealed(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(
            rows: ((data['rows'] as List?) ?? const [])
                .map(
                  (item) =>
                      ClaimRow.fromJson(Map<String, dynamic>.from(item as Map)),
                )
                .toList(),
          ),
        ),
      ),
    );

    _signals.add(const ClaimsRevealed());
  }

  void _applyChallengeRaised(Map<String, dynamic> data) {
    _signals.add(ChallengeRaised(onMe: '${data['targetUserId']}' == viewerId));
  }

  void _applyVerdictOpened(Map<String, dynamic> data) {
    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          round: state.round?.copyWith(challenge: ChallengeView.fromJson(data)),
        ),
      ),
    );
  }

  void _applyVerdictResult(Map<String, dynamic> data) {
    _signals.add(
      VerdictDecided(
        // upheld = الادّعاء صمد · rejected = سقط
        claimStood: '${data['verdict']}' != 'rejected',
        aboutMe: '${data['targetUserId']}' == viewerId,
      ),
    );
  }

  void _applySceneScored(Map<String, dynamic> data) {
    final rows = ((data['rows'] as List?) ?? const [])
        .map(
          (item) => SceneScore.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final mine = rows.where((row) => row.userId == viewerId);

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          standings: ((data['standings'] as List?) ?? const [])
              .map(
                (item) =>
                    Standing.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList(),
          round: state.round?.copyWith(sceneScores: rows, clearChallenge: true),
        ),
      ),
    );

    _signals.add(SceneScored(myPoints: mine.isEmpty ? 0 : mine.first.points));
  }

  void _applyAwardsStarted(Map<String, dynamic> data) {
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
            awards: ((data['awards'] as List?) ?? const [])
                .map(
                  (item) => AwardKind.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );

    _signals.add(const AwardsOpened());
  }

  void _applyPhaseChanged(Map<String, dynamic> data) {
    final phase = MashhadPhase.parse(data['phase']);
    final previous = state.round;

    emit(
      state.copyWith(
        snapshot: state.snapshot?.copyWith(
          currentScene: (data['scene'] as num?)?.toInt(),
          totalScenes: (data['totalScenes'] as num?)?.toInt(),
          round:
              (previous ??
                      MashhadRound(
                        number: (data['scene'] as num?)?.toInt() ?? 0,
                        phase: phase,
                        phaseStartedAt: 0,
                        deadline: 0,
                        title: '',
                        setup: '',
                      ))
                  .copyWith(
                    number: (data['scene'] as num?)?.toInt(),
                    phase: phase,
                    phaseStartedAt: (data['phaseStartedAt'] as num?)?.toInt(),
                    deadline: (data['deadline'] as num?)?.toInt(),
                    // انتهى التصويت على الاعتراض الحالي.
                    clearChallenge: phase != MashhadPhase.verdict,
                  ),
        ),
      ),
    );

    if (phase == MashhadPhase.scene) _signals.add(const SceneLive());
  }

  void _applyFinished(Map<String, dynamic> data) {
    final result = MashhadResult.fromJson(
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

  List<MashhadPlayer> _players(Object? raw) => ((raw as List?) ?? const [])
      .map(
        (item) =>
            MashhadPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
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
