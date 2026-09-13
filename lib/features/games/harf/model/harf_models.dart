import 'package:equatable/equatable.dart';

import '../../../../core/network/json.dart';

/// مراحل الجولة كما يعرّفها السيرفر. الجهاز يعرض ما يقوله السيرفر ولا يقرّر.
enum HarfPhase {
  awaitingLetter('awaiting_letter'),
  revealLetter('reveal_letter'),
  writing('writing'),
  grace('grace'),
  reveal('reveal'),
  objection('objection'),
  voting('voting'),
  scoreboard('scoreboard'),
  tiebreak('tiebreak');

  const HarfPhase(this.value);

  final String value;

  static HarfPhase parse(Object? value) => HarfPhase.values.firstWhere(
    (phase) => phase.value == '$value',
    orElse: () => HarfPhase.awaitingLetter,
  );

  /// المراحل التي تُعرض فيها إجابات الجميع.
  bool get showsAllAnswers => const {
    HarfPhase.reveal,
    HarfPhase.objection,
    HarfPhase.voting,
    HarfPhase.scoreboard,
  }.contains(this);
}

class HarfConfig extends Equatable {
  const HarfConfig({
    required this.columns,
    required this.columnLabels,
    required this.roundsPerPlayer,
    required this.writeSeconds,
    required this.flexibleMode,
    this.sixthColumn,
  });

  final List<String> columns;
  final Map<String, String> columnLabels;
  final int roundsPerPlayer;
  final int writeSeconds;
  final bool flexibleMode;
  final String? sixthColumn;

  String labelOf(String column) => columnLabels[column] ?? column;

  static const empty = HarfConfig(
    columns: [],
    columnLabels: {},
    roundsPerPlayer: 1,
    writeSeconds: 90,
    flexibleMode: false,
  );

  factory HarfConfig.fromJson(Map<String, dynamic> json) => HarfConfig(
    columns: ((json['columns'] as List?) ?? const []).map((c) => '$c').toList(),
    columnLabels: asStringMap(json['columnLabels']),
    roundsPerPlayer: (json['roundsPerPlayer'] as num?)?.toInt() ?? 1,
    writeSeconds: (json['writeSeconds'] as num?)?.toInt() ?? 90,
    flexibleMode: json['flexibleMode'] == true,
    sixthColumn: json['sixthColumn'] as String?,
  );

  @override
  List<Object?> get props => [
    columns,
    columnLabels,
    roundsPerPlayer,
    writeSeconds,
    flexibleMode,
    sixthColumn,
  ];
}

class HarfPlayer extends Equatable {
  const HarfPlayer({
    required this.id,
    required this.username,
    required this.isSpectator,
    required this.total,
    required this.hasLeft,
    this.photoUrl,
    this.avatarId,
    this.gender = 'male',
  });

  final String id;
  final String username;
  final bool isSpectator;
  final int total;
  final bool hasLeft;
  final String? photoUrl;
  final String? avatarId;
  final String gender;

  factory HarfPlayer.fromJson(Map<String, dynamic> json) => HarfPlayer(
    id: '${json['id']}',
    username: '${json['username']}',
    isSpectator: json['isSpectator'] == true,
    total: (json['total'] as num?)?.toInt() ?? 0,
    hasLeft: json['leftAtRound'] != null,
    photoUrl: json['photoUrl'] as String?,
    avatarId: json['avatarId'] as String?,
    gender: '${json['gender'] ?? 'male'}',
  );

  @override
  List<Object?> get props => [
    id,
    username,
    isSpectator,
    total,
    hasLeft,
    photoUrl,
    avatarId,
    gender,
  ];
}

/// سطر في لوحة النتائج.
class Standing extends Equatable {
  const Standing({
    required this.userId,
    required this.username,
    required this.total,
    required this.hasLeft,
    this.photoUrl,
    this.avatarId,
  });

  final String userId;
  final String username;
  final int total;
  final bool hasLeft;
  final String? photoUrl;
  final String? avatarId;

  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
    userId: '${json['userId']}',
    username: '${json['username']}',
    total: (json['total'] as num?)?.toInt() ?? 0,
    hasLeft: json['left'] == true,
    photoUrl: json['photoUrl'] as String?,
    avatarId: json['avatarId'] as String?,
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    total,
    hasLeft,
    photoUrl,
    avatarId,
  ];
}

/// صف إجابات لاعب واحد في مرحلة العرض.
class AnswerRow extends Equatable {
  const AnswerRow({
    required this.userId,
    required this.username,
    required this.answers,
  });

  final String userId;
  final String username;
  final Map<String, String> answers;

  factory AnswerRow.fromJson(Map<String, dynamic> json) => AnswerRow(
    userId: '${json['userId']}',
    username: '${json['username']}',
    answers: asStringMap(json['answers']),
  );

  @override
  List<Object?> get props => [userId, username, answers];
}

/// نقاط لاعب في جولة واحدة.
class RoundScore extends Equatable {
  const RoundScore({
    required this.perColumn,
    required this.stopBonus,
    required this.penalties,
    required this.total,
  });

  final Map<String, int> perColumn;
  final int stopBonus;
  final int penalties;
  final int total;

  factory RoundScore.fromJson(Map<String, dynamic> json) => RoundScore(
    perColumn: asIntMap(json['perColumn']),
    stopBonus: (json['stopBonus'] as num?)?.toInt() ?? 0,
    penalties: (json['penalties'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [perColumn, stopBonus, penalties, total];
}

/// الاعتراض المعروض حالياً للتصويت — واحد في كل مرة.
class ObjectionView extends Equatable {
  const ObjectionView({
    required this.id,
    required this.byUsername,
    required this.targetUserId,
    required this.targetUsername,
    required this.column,
    required this.columnLabel,
    required this.answer,
    required this.isParty,
    required this.hasVoted,
    this.index = 1,
    this.total = 1,
  });

  final String id;
  final String byUsername;
  final String targetUserId;
  final String targetUsername;
  final String column;
  final String columnLabel;
  final String answer;

  /// المعترِض والمعترَض عليه وشركاؤهما لا يصوّتون — كلهم أصحاب مصلحة.
  final bool isParty;
  final bool hasVoted;
  final int index;
  final int total;

  factory ObjectionView.fromJson(Map<String, dynamic> json, String viewerId) {
    final parties = ((json['parties'] as List?) ?? const [])
        .map((p) => '$p')
        .toList();

    return ObjectionView(
      id: '${json['objectionId']}',
      byUsername: '${json['byUsername']}',
      targetUserId: '${json['targetUserId']}',
      targetUsername: '${json['targetUsername']}',
      column: '${json['column']}',
      columnLabel: '${json['columnLabel']}',
      answer: '${json['answer']}',
      isParty: json['isParty'] == true || parties.contains(viewerId),
      hasVoted: json['hasVoted'] == true,
      index: (json['index'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 1,
    );
  }

  ObjectionView copyWith({bool? hasVoted}) => ObjectionView(
    id: id,
    byUsername: byUsername,
    targetUserId: targetUserId,
    targetUsername: targetUsername,
    column: column,
    columnLabel: columnLabel,
    answer: answer,
    isParty: isParty,
    hasVoted: hasVoted ?? this.hasVoted,
    index: index,
    total: total,
  );

  @override
  List<Object?> get props => [
    id,
    byUsername,
    targetUserId,
    targetUsername,
    column,
    columnLabel,
    answer,
    isParty,
    hasVoted,
    index,
    total,
  ];
}

/// الجولة الجارية.
class HarfRound extends Equatable {
  const HarfRound({
    required this.number,
    required this.phase,
    required this.phaseStartedAt,
    required this.deadline,
    required this.drawerUserId,
    this.letter,
    this.stopBy,
    this.myAnswers = const {},
    this.objectionsLeft = 3,
    this.rows = const [],
    this.roundScores = const {},
    this.objection,
    this.tiedPlayers = const [],
    this.tiebreakColumn,
  });

  final int number;
  final HarfPhase phase;
  final int phaseStartedAt;
  final int deadline;
  final String drawerUserId;
  final String? letter;
  final String? stopBy;
  final Map<String, String> myAnswers;
  final int objectionsLeft;
  final List<AnswerRow> rows;
  final Map<String, RoundScore> roundScores;
  final ObjectionView? objection;
  final List<String> tiedPlayers;
  final String? tiebreakColumn;

  factory HarfRound.fromJson(Map<String, dynamic> json, String viewerId) =>
      HarfRound(
        number: (json['no'] as num?)?.toInt() ?? 0,
        phase: HarfPhase.parse(json['phase']),
        phaseStartedAt: (json['phaseStartedAt'] as num?)?.toInt() ?? 0,
        deadline: (json['deadline'] as num?)?.toInt() ?? 0,
        drawerUserId: '${json['drawerUserId']}',
        letter: json['letter'] as String?,
        stopBy: json['stopBy'] as String?,
        myAnswers: asStringMap(json['myAnswers']),
        objectionsLeft: (json['myObjectionsLeft'] as num?)?.toInt() ?? 3,
        rows: ((json['rows'] as List?) ?? const [])
            .map(
              (item) =>
                  AnswerRow.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        roundScores: asJsonMap(json['roundScores']).map(
          (key, value) => MapEntry(key, RoundScore.fromJson(asJsonMap(value))),
        ),
        objection: json['objection'] is Map
            ? ObjectionView.fromJson(
                Map<String, dynamic>.from(json['objection'] as Map),
                viewerId,
              )
            : null,
        tiedPlayers: ((json['tiedPlayers'] as List?) ?? const [])
            .map((p) => '$p')
            .toList(),
        tiebreakColumn: json['tiebreakColumn'] as String?,
      );

  HarfRound copyWith({
    int? number,
    HarfPhase? phase,
    int? phaseStartedAt,
    int? deadline,
    String? drawerUserId,
    String? letter,
    String? stopBy,
    Map<String, String>? myAnswers,
    int? objectionsLeft,
    List<AnswerRow>? rows,
    Map<String, RoundScore>? roundScores,
    ObjectionView? objection,
    bool clearObjection = false,
    List<String>? tiedPlayers,
    String? tiebreakColumn,
  }) => HarfRound(
    number: number ?? this.number,
    phase: phase ?? this.phase,
    phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
    deadline: deadline ?? this.deadline,
    drawerUserId: drawerUserId ?? this.drawerUserId,
    letter: letter ?? this.letter,
    stopBy: stopBy ?? this.stopBy,
    myAnswers: myAnswers ?? this.myAnswers,
    objectionsLeft: objectionsLeft ?? this.objectionsLeft,
    rows: rows ?? this.rows,
    roundScores: roundScores ?? this.roundScores,
    objection: clearObjection ? null : (objection ?? this.objection),
    tiedPlayers: tiedPlayers ?? this.tiedPlayers,
    tiebreakColumn: tiebreakColumn ?? this.tiebreakColumn,
  );

  @override
  List<Object?> get props => [
    number,
    phase,
    phaseStartedAt,
    deadline,
    drawerUserId,
    letter,
    stopBy,
    myAnswers,
    objectionsLeft,
    rows,
    roundScores,
    objection,
    tiedPlayers,
    tiebreakColumn,
  ];
}

/// موقع المستخدم من هذه الجلسة.
class MyRole extends Equatable {
  const MyRole({
    required this.isPlayer,
    required this.isSpectator,
    required this.isHost,
    required this.canEndEarly,
    required this.total,
  });

  final bool isPlayer;
  final bool isSpectator;
  final bool isHost;
  final bool canEndEarly;
  final int total;

  static const spectator = MyRole(
    isPlayer: false,
    isSpectator: true,
    isHost: false,
    canEndEarly: false,
    total: 0,
  );

  factory MyRole.fromJson(Map<String, dynamic> json) => MyRole(
    isPlayer: json['isPlayer'] == true,
    isSpectator: json['isSpectator'] == true,
    isHost: json['isHost'] == true,
    canEndEarly: json['canEndEarly'] == true,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );

  MyRole copyWith({bool? isHost, bool? canEndEarly}) => MyRole(
    isPlayer: isPlayer,
    isSpectator: isSpectator,
    isHost: isHost ?? this.isHost,
    canEndEarly: canEndEarly ?? this.canEndEarly,
    total: total,
  );

  @override
  List<Object?> get props => [
    isPlayer,
    isSpectator,
    isHost,
    canEndEarly,
    total,
  ];
}

/// النتيجة النهائية.
class HarfResult extends Equatable {
  const HarfResult({
    required this.winnerId,
    required this.finalScores,
    required this.endedEarly,
    required this.decidedByTiebreak,
    required this.roundsPlayed,
    this.reason,
  });

  final String? winnerId;
  final List<Standing> finalScores;
  final bool endedEarly;
  final bool decidedByTiebreak;
  final int roundsPlayed;
  final String? reason;

  Standing? get winner {
    for (final row in finalScores) {
      if (row.userId == winnerId) return row;
    }
    return finalScores.isEmpty ? null : finalScores.first;
  }

  factory HarfResult.fromJson(Map<String, dynamic> json) => HarfResult(
    winnerId: json['winnerId'] as String?,
    finalScores: ((json['finalScores'] as List?) ?? const [])
        .map(
          (item) => Standing.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    endedEarly: json['endedEarly'] == true,
    decidedByTiebreak: json['decidedByTiebreak'] == true,
    roundsPlayed: (json['roundsPlayed'] as num?)?.toInt() ?? 0,
    reason: json['reason'] as String?,
  );

  @override
  List<Object?> get props => [
    winnerId,
    finalScores,
    endedEarly,
    decidedByTiebreak,
    roundsPlayed,
    reason,
  ];
}

/// لقطة الجلسة كما يراها هذا المستخدم.
class HarfSnapshot extends Equatable {
  const HarfSnapshot({
    required this.gameId,
    required this.channelId,
    required this.status,
    required this.config,
    required this.hostId,
    required this.players,
    required this.order,
    required this.currentRound,
    required this.totalRounds,
    required this.standings,
    required this.estimatedSeconds,
    required this.canStart,
    required this.me,
    this.round,
    this.result,
  });

  final String gameId;
  final String channelId;
  final String status;
  final HarfConfig config;
  final String hostId;
  final List<HarfPlayer> players;
  final List<String> order;
  final int currentRound;
  final int totalRounds;
  final List<Standing> standings;
  final int estimatedSeconds;
  final bool canStart;
  final MyRole me;
  final HarfRound? round;
  final HarfResult? result;

  bool get isLobby => status == 'lobby';

  bool get isPlaying => status == 'playing';

  bool get isFinished => status == 'finished' || status == 'abandoned';

  List<HarfPlayer> get seatedPlayers =>
      players.where((player) => !player.isSpectator).toList();

  HarfPlayer? playerById(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  factory HarfSnapshot.fromJson(
    Map<String, dynamic> json,
    String viewerId,
  ) => HarfSnapshot(
    gameId: '${json['gameId']}',
    channelId: '${json['channelId']}',
    status: '${json['status']}',
    config: HarfConfig.fromJson(
      json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
    ),
    hostId: '${json['hostId']}',
    players: ((json['players'] as List?) ?? const [])
        .map(
          (item) => HarfPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    order: ((json['order'] as List?) ?? const []).map((id) => '$id').toList(),
    currentRound: (json['currentRound'] as num?)?.toInt() ?? 0,
    totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 0,
    standings: ((json['standings'] as List?) ?? const [])
        .map(
          (item) => Standing.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    estimatedSeconds: (json['estimatedSeconds'] as num?)?.toInt() ?? 0,
    canStart: json['canStart'] == true,
    me: json['me'] is Map
        ? MyRole.fromJson(Map<String, dynamic>.from(json['me'] as Map))
        : MyRole.spectator,
    round: json['round'] is Map
        ? HarfRound.fromJson(
            Map<String, dynamic>.from(json['round'] as Map),
            viewerId,
          )
        : null,
    result: json['result'] is Map
        ? HarfResult.fromJson(Map<String, dynamic>.from(json['result'] as Map))
        : null,
  );

  HarfSnapshot copyWith({
    String? status,
    HarfConfig? config,
    String? hostId,
    List<HarfPlayer>? players,
    List<String>? order,
    int? currentRound,
    int? totalRounds,
    List<Standing>? standings,
    int? estimatedSeconds,
    bool? canStart,
    MyRole? me,
    HarfRound? round,
    bool clearRound = false,
    HarfResult? result,
  }) => HarfSnapshot(
    gameId: gameId,
    channelId: channelId,
    status: status ?? this.status,
    config: config ?? this.config,
    hostId: hostId ?? this.hostId,
    players: players ?? this.players,
    order: order ?? this.order,
    currentRound: currentRound ?? this.currentRound,
    totalRounds: totalRounds ?? this.totalRounds,
    standings: standings ?? this.standings,
    estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
    canStart: canStart ?? this.canStart,
    me: me ?? this.me,
    round: clearRound ? null : (round ?? this.round),
    result: result ?? this.result,
  );

  @override
  List<Object?> get props => [
    gameId,
    channelId,
    status,
    config,
    hostId,
    players,
    order,
    currentRound,
    totalRounds,
    standings,
    estimatedSeconds,
    canStart,
    me,
    round,
    result,
  ];
}
