import 'package:equatable/equatable.dart';

/// مراحل الجولة كما يعرّفها السيرفر. الجهاز يعرض ما يقوله السيرفر ولا يقرّر.
enum HadafPhase {
  ready('ready'),
  question('question'),
  reveal('reveal'),
  scoreboard('scoreboard'),
  tiebreak('tiebreak');

  const HadafPhase(this.value);

  final String value;

  static HadafPhase parse(Object? value) => HadafPhase.values.firstWhere(
    (phase) => phase.value == '$value',
    orElse: () => HadafPhase.ready,
  );

  /// المراحل التي يتسابق فيها اللاعبون فعلاً.
  bool get isRacing =>
      this == HadafPhase.question || this == HadafPhase.tiebreak;

  /// المراحل التي انكشف فيها الجواب.
  bool get isRevealed =>
      this == HadafPhase.reveal || this == HadafPhase.scoreboard;
}

class HadafConfig extends Equatable {
  const HadafConfig({
    required this.rounds,
    required this.questionSeconds,
    required this.flexibleMode,
    required this.risksPerGame,
    this.category,
    this.categoryLabel,
    this.categoryEmoji,
  });

  final int rounds;
  final int questionSeconds;
  final bool flexibleMode;

  /// سقف ⚡ في الجلسة كلها.
  final int risksPerGame;

  /// null = مزيج من كل المجموعات.
  final String? category;
  final String? categoryLabel;
  final String? categoryEmoji;

  static const empty = HadafConfig(
    rounds: 8,
    questionSeconds: 20,
    flexibleMode: false,
    risksPerGame: 3,
  );

  factory HadafConfig.fromJson(Map<String, dynamic> json) => HadafConfig(
    rounds: (json['rounds'] as num?)?.toInt() ?? 8,
    questionSeconds: (json['questionSeconds'] as num?)?.toInt() ?? 20,
    flexibleMode: json['flexibleMode'] == true,
    risksPerGame: (json['risksPerGame'] as num?)?.toInt() ?? 3,
    category: json['category'] as String?,
    categoryLabel: json['categoryLabel'] as String?,
    categoryEmoji: json['categoryEmoji'] as String?,
  );

  @override
  List<Object?> get props => [
    rounds,
    questionSeconds,
    flexibleMode,
    risksPerGame,
    category,
    categoryLabel,
    categoryEmoji,
  ];
}

class HadafPlayer extends Equatable {
  const HadafPlayer({
    required this.id,
    required this.username,
    required this.isSpectator,
    required this.hasLeft,
    this.photoUrl,
    this.avatarId,
    this.gender = 'male',
  });

  final String id;
  final String username;
  final bool isSpectator;
  final bool hasLeft;
  final String? photoUrl;
  final String? avatarId;
  final String gender;

  factory HadafPlayer.fromJson(Map<String, dynamic> json) => HadafPlayer(
    id: '${json['id']}',
    username: '${json['username']}',
    isSpectator: json['isSpectator'] == true,
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
    hasLeft,
    photoUrl,
    avatarId,
    gender,
  ];
}

/// السؤال المعروض.
///
/// [prompt] و[choices] فارغان في مرحلة الاستعداد: السيرفر لا يرسلهما قبل
/// انطلاق الجميع معاً — لا مجال لأن يقرأ أحد السؤال قبل غيره.
class HadafQuestion extends Equatable {
  const HadafQuestion({
    required this.category,
    required this.difficulty,
    this.categoryLabel,
    this.categoryEmoji,
    this.prompt,
    this.choices = const [],
  });

  final String category;
  final String difficulty;
  final String? categoryLabel;
  final String? categoryEmoji;
  final String? prompt;
  final List<String> choices;

  bool get isTeaser => prompt == null || choices.isEmpty;

  String get difficultyLabel => switch (difficulty) {
    'easy' => 'سهل',
    'hard' => 'صعب',
    _ => 'متوسط',
  };

  factory HadafQuestion.fromJson(Map<String, dynamic> json) => HadafQuestion(
    category: '${json['category']}',
    difficulty: '${json['difficulty']}',
    categoryLabel: json['categoryLabel'] as String?,
    categoryEmoji: json['categoryEmoji'] as String?,
    prompt: json['prompt'] as String?,
    choices: ((json['choices'] as List?) ?? const [])
        .map((choice) => '$choice')
        .toList(),
  );

  @override
  List<Object?> get props => [
    category,
    difficulty,
    categoryLabel,
    categoryEmoji,
    prompt,
    choices,
  ];
}

/// سطر لاعب في كشف الجولة.
class RevealRow extends Equatable {
  const RevealRow({
    required this.userId,
    required this.username,
    required this.correct,
    required this.usedRisk,
    required this.rank,
    required this.points,
    required this.streak,
    this.choice,
  });

  final String userId;
  final String username;
  final bool correct;
  final bool usedRisk;

  /// ترتيبه بين المصيبين — 0 يعني لم يصب.
  final int rank;

  final int points;
  final int streak;
  final int? choice;

  factory RevealRow.fromJson(Map<String, dynamic> json) => RevealRow(
    userId: '${json['userId']}',
    username: '${json['username']}',
    correct: json['correct'] == true,
    usedRisk: json['usedRisk'] == true,
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    points: (json['points'] as num?)?.toInt() ?? 0,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    choice: (json['choice'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    correct,
    usedRisk,
    rank,
    points,
    streak,
    choice,
  ];
}

/// سطر في لوحة النتائج.
class Standing extends Equatable {
  const Standing({
    required this.userId,
    required this.username,
    required this.total,
    required this.streak,
    required this.bestStreak,
    required this.correctCount,
    required this.hasLeft,
    this.photoUrl,
    this.avatarId,
  });

  final String userId;
  final String username;
  final int total;
  final int streak;
  final int bestStreak;
  final int correctCount;
  final bool hasLeft;
  final String? photoUrl;
  final String? avatarId;

  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
    userId: '${json['userId']}',
    username: '${json['username']}',
    total: (json['total'] as num?)?.toInt() ?? 0,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
    correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
    hasLeft: json['left'] == true,
    photoUrl: json['photoUrl'] as String?,
    avatarId: json['avatarId'] as String?,
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    total,
    streak,
    bestStreak,
    correctCount,
    hasLeft,
    photoUrl,
    avatarId,
  ];
}

/// موقع المستخدم من هذه الجلسة.
class HadafRole extends Equatable {
  const HadafRole({
    required this.isPlayer,
    required this.isSpectator,
    required this.isHost,
    required this.canEndEarly,
    required this.total,
    required this.streak,
    required this.risksLeft,
    required this.correctCount,
  });

  final bool isPlayer;
  final bool isSpectator;
  final bool isHost;
  final bool canEndEarly;
  final int total;
  final int streak;

  /// كم ⚡ بقيت لي في هذه الجلسة.
  final int risksLeft;

  final int correctCount;

  static const spectator = HadafRole(
    isPlayer: false,
    isSpectator: true,
    isHost: false,
    canEndEarly: false,
    total: 0,
    streak: 0,
    risksLeft: 0,
    correctCount: 0,
  );

  factory HadafRole.fromJson(Map<String, dynamic> json) => HadafRole(
    isPlayer: json['isPlayer'] == true,
    isSpectator: json['isSpectator'] == true,
    isHost: json['isHost'] == true,
    canEndEarly: json['canEndEarly'] == true,
    total: (json['total'] as num?)?.toInt() ?? 0,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    risksLeft: (json['risksLeft'] as num?)?.toInt() ?? 0,
    correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
  );

  HadafRole copyWith({
    bool? isHost,
    bool? canEndEarly,
    int? total,
    int? streak,
    int? risksLeft,
    int? correctCount,
  }) => HadafRole(
    isPlayer: isPlayer,
    isSpectator: isSpectator,
    isHost: isHost ?? this.isHost,
    canEndEarly: canEndEarly ?? this.canEndEarly,
    total: total ?? this.total,
    streak: streak ?? this.streak,
    risksLeft: risksLeft ?? this.risksLeft,
    correctCount: correctCount ?? this.correctCount,
  );

  @override
  List<Object?> get props => [
    isPlayer,
    isSpectator,
    isHost,
    canEndEarly,
    total,
    streak,
    risksLeft,
    correctCount,
  ];
}

/// الجولة الجارية.
class HadafRound extends Equatable {
  const HadafRound({
    required this.number,
    required this.phase,
    required this.phaseStartedAt,
    required this.deadline,
    this.question,
    this.answeredCount = 0,
    this.activeCount = 0,
    this.myChoice,
    this.myRisk = false,
    this.myCorrect,
    this.answerIndex,
    this.explanation,
    this.rows = const [],
    this.tiedPlayers = const [],
  });

  final int number;
  final HadafPhase phase;
  final int phaseStartedAt;
  final int deadline;
  final HadafQuestion? question;

  final int answeredCount;
  final int activeCount;

  /// اختياري أنا — يصل في اللقطة وحدها، ولا يعرفه غيري قبل الكشف.
  final int? myChoice;
  final bool myRisk;

  /// null أثناء السباق: معرفة أنك أصبت قبل الإقفال تكشف الجواب.
  final bool? myCorrect;

  /// موقع الجواب الصحيح — null قبل الكشف.
  final int? answerIndex;

  final String? explanation;
  final List<RevealRow> rows;
  final List<String> tiedPlayers;

  bool get hasAnswered => myChoice != null;

  factory HadafRound.fromJson(Map<String, dynamic> json) => HadafRound(
    number: (json['no'] as num?)?.toInt() ?? 0,
    phase: HadafPhase.parse(json['phase']),
    phaseStartedAt: (json['phaseStartedAt'] as num?)?.toInt() ?? 0,
    deadline: (json['deadline'] as num?)?.toInt() ?? 0,
    question: json['question'] is Map
        ? HadafQuestion.fromJson(
            Map<String, dynamic>.from(json['question'] as Map),
          )
        : null,
    answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
    activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
    myChoice: (json['myChoice'] as num?)?.toInt(),
    myRisk: json['myRisk'] == true,
    myCorrect: json['myCorrect'] as bool?,
    answerIndex: (json['answerIndex'] as num?)?.toInt(),
    explanation: json['explanation'] as String?,
    rows: ((json['rows'] as List?) ?? const [])
        .map(
          (item) => RevealRow.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    tiedPlayers: ((json['tiedPlayers'] as List?) ?? const [])
        .map((id) => '$id')
        .toList(),
  );

  HadafRound copyWith({
    int? number,
    HadafPhase? phase,
    int? phaseStartedAt,
    int? deadline,
    HadafQuestion? question,
    int? answeredCount,
    int? activeCount,
    int? myChoice,
    bool? myRisk,
    bool? myCorrect,
    int? answerIndex,
    String? explanation,
    List<RevealRow>? rows,
    List<String>? tiedPlayers,
  }) => HadafRound(
    number: number ?? this.number,
    phase: phase ?? this.phase,
    phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
    deadline: deadline ?? this.deadline,
    question: question ?? this.question,
    answeredCount: answeredCount ?? this.answeredCount,
    activeCount: activeCount ?? this.activeCount,
    myChoice: myChoice ?? this.myChoice,
    myRisk: myRisk ?? this.myRisk,
    myCorrect: myCorrect ?? this.myCorrect,
    answerIndex: answerIndex ?? this.answerIndex,
    explanation: explanation ?? this.explanation,
    rows: rows ?? this.rows,
    tiedPlayers: tiedPlayers ?? this.tiedPlayers,
  );

  @override
  List<Object?> get props => [
    number,
    phase,
    phaseStartedAt,
    deadline,
    question,
    answeredCount,
    activeCount,
    myChoice,
    myRisk,
    myCorrect,
    answerIndex,
    explanation,
    rows,
    tiedPlayers,
  ];
}

/// النتيجة النهائية.
class HadafResult extends Equatable {
  const HadafResult({
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

  factory HadafResult.fromJson(Map<String, dynamic> json) => HadafResult(
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
class HadafSnapshot extends Equatable {
  const HadafSnapshot({
    required this.gameId,
    required this.channelId,
    required this.status,
    required this.config,
    required this.hostId,
    required this.players,
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
  final HadafConfig config;
  final String hostId;
  final List<HadafPlayer> players;
  final int currentRound;
  final int totalRounds;
  final List<Standing> standings;
  final int estimatedSeconds;
  final bool canStart;
  final HadafRole me;
  final HadafRound? round;
  final HadafResult? result;

  bool get isLobby => status == 'lobby';

  bool get isPlaying => status == 'playing';

  bool get isFinished => status == 'finished' || status == 'abandoned';

  List<HadafPlayer> get seatedPlayers =>
      players.where((player) => !player.isSpectator).toList();

  HadafPlayer? playerById(String? id) {
    if (id == null) return null;

    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  factory HadafSnapshot.fromJson(Map<String, dynamic> json) => HadafSnapshot(
    gameId: '${json['gameId']}',
    channelId: '${json['channelId']}',
    status: '${json['status']}',
    config: HadafConfig.fromJson(
      json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
    ),
    hostId: '${json['hostId']}',
    players: ((json['players'] as List?) ?? const [])
        .map(
          (item) =>
              HadafPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
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
        ? HadafRole.fromJson(Map<String, dynamic>.from(json['me'] as Map))
        : HadafRole.spectator,
    round: json['round'] is Map
        ? HadafRound.fromJson(Map<String, dynamic>.from(json['round'] as Map))
        : null,
    result: json['result'] is Map
        ? HadafResult.fromJson(Map<String, dynamic>.from(json['result'] as Map))
        : null,
  );

  HadafSnapshot copyWith({
    String? status,
    HadafConfig? config,
    String? hostId,
    List<HadafPlayer>? players,
    int? currentRound,
    int? totalRounds,
    List<Standing>? standings,
    int? estimatedSeconds,
    bool? canStart,
    HadafRole? me,
    HadafRound? round,
    bool clearRound = false,
    HadafResult? result,
  }) => HadafSnapshot(
    gameId: gameId,
    channelId: channelId,
    status: status ?? this.status,
    config: config ?? this.config,
    hostId: hostId ?? this.hostId,
    players: players ?? this.players,
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
