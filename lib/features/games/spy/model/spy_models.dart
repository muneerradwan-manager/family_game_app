import 'package:equatable/equatable.dart';

/// مراحل الجولة كما يعرّفها السيرفر. الجهاز يعرض ما يقوله السيرفر ولا يقرّر.
enum SpyPhase {
  roleReveal('role_reveal'),
  asking('asking'),
  answering('answering'),
  voting('voting'),
  voteResult('vote_result'),
  spyGuess('spy_guess');

  const SpyPhase(this.value);

  final String value;

  static SpyPhase parse(Object? value) => SpyPhase.values.firstWhere(
    (phase) => phase.value == '$value',
    orElse: () => SpyPhase.roleReveal,
  );

  /// المراحل التي يظهر فيها سجل الأسئلة أسفل الشاشة.
  bool get showsTranscript => const {
    SpyPhase.asking,
    SpyPhase.answering,
    SpyPhase.voting,
  }.contains(this);
}

class SpyConfig extends Equatable {
  const SpyConfig({
    required this.turnSeconds,
    required this.maxRounds,
    required this.lastGuess,
    this.category,
  });

  final int turnSeconds;
  final int maxRounds;

  /// فرصة الجاسوس الأخيرة لتخمين الكلمة بعد انكشافه.
  final bool lastGuess;

  /// مفتاح مجموعة الكلمات المختارة، أو null = مفاجأة.
  final String? category;

  static const empty = SpyConfig(
    turnSeconds: 45,
    maxRounds: 4,
    lastGuess: true,
  );

  factory SpyConfig.fromJson(Map<String, dynamic> json) => SpyConfig(
    turnSeconds: (json['turnSeconds'] as num?)?.toInt() ?? 45,
    maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 4,
    lastGuess: json['lastGuess'] != false,
    category: json['category'] as String?,
  );

  @override
  List<Object?> get props => [turnSeconds, maxRounds, lastGuess, category];
}

class SpyPlayer extends Equatable {
  const SpyPlayer({
    required this.id,
    required this.username,
    required this.isSpectator,
    required this.hasLeft,
    required this.outAtRound,
    this.photoUrl,
    this.avatarId,
    this.gender = 'male',
  });

  final String id;
  final String username;
  final bool isSpectator;
  final bool hasLeft;

  /// الجولة التي خرج فيها بالتصويت — null يعني ما زال في اللعبة.
  final int? outAtRound;

  final String? photoUrl;
  final String? avatarId;
  final String gender;

  bool get isOut => outAtRound != null;

  /// من يستطيع أن يسأل ويجيب ويصوّت الآن.
  bool get isActive => !isSpectator && !hasLeft && !isOut;

  factory SpyPlayer.fromJson(Map<String, dynamic> json) => SpyPlayer(
    id: '${json['id']}',
    username: '${json['username']}',
    isSpectator: json['isSpectator'] == true,
    hasLeft: json['leftAtRound'] != null,
    outAtRound: (json['outAtRound'] as num?)?.toInt(),
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
    outAtRound,
    photoUrl,
    avatarId,
    gender,
  ];
}

/// سؤال واحد وجوابه — وحدة السجل الذي يقرأه الجاسوس ليستنتج الكلمة.
class SpyTurn extends Equatable {
  const SpyTurn({
    required this.id,
    required this.round,
    required this.askerId,
    required this.askerUsername,
    required this.skipped,
    required this.unanswered,
    this.targetId,
    this.targetUsername,
    this.question,
    this.answer,
  });

  final String id;
  final int round;
  final String askerId;
  final String askerUsername;

  /// انتهى وقته قبل أن يسأل.
  final bool skipped;

  /// سُئل ولم يجب حتى انتهى وقته — والصمت نفسه معلومة.
  final bool unanswered;

  final String? targetId;
  final String? targetUsername;
  final String? question;
  final String? answer;

  bool get isPending => !skipped && !unanswered && answer == null;

  factory SpyTurn.fromJson(Map<String, dynamic> json) => SpyTurn(
    id: '${json['id']}',
    round: (json['round'] as num?)?.toInt() ?? 0,
    askerId: '${json['askerId']}',
    askerUsername: '${json['askerUsername']}',
    skipped: json['skipped'] == true,
    unanswered: json['unanswered'] == true,
    targetId: json['targetId'] as String?,
    targetUsername: json['targetUsername'] as String?,
    question: json['question'] as String?,
    answer: json['answer'] as String?,
  );

  SpyTurn copyWith({String? answer, bool? unanswered}) => SpyTurn(
    id: id,
    round: round,
    askerId: askerId,
    askerUsername: askerUsername,
    skipped: skipped,
    unanswered: unanswered ?? this.unanswered,
    targetId: targetId,
    targetUsername: targetUsername,
    question: question,
    answer: answer ?? this.answer,
  );

  @override
  List<Object?> get props => [
    id,
    round,
    askerId,
    askerUsername,
    skipped,
    unanswered,
    targetId,
    targetUsername,
    question,
    answer,
  ];
}

/// عدد أصوات لاعب واحد — تُكشف كلها معاً عند إعلان النتيجة.
class VoteCount extends Equatable {
  const VoteCount({
    required this.userId,
    required this.username,
    required this.votes,
  });

  final String userId;
  final String username;
  final int votes;

  factory VoteCount.fromJson(Map<String, dynamic> json) => VoteCount(
    userId: '${json['userId']}',
    username: '${json['username']}',
    votes: (json['votes'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [userId, username, votes];
}

/// نتيجة تصويت جولة واحدة.
class VoteOutcome extends Equatable {
  const VoteOutcome({
    required this.tie,
    required this.wasSpy,
    required this.counts,
    this.ejectedUserId,
    this.ejectedUsername,
  });

  /// تعادل على الصدارة (أو صفر أصوات) = ما خرج حدا.
  final bool tie;

  final bool wasSpy;
  final List<VoteCount> counts;
  final String? ejectedUserId;
  final String? ejectedUsername;

  factory VoteOutcome.fromJson(Map<String, dynamic> json) => VoteOutcome(
    tie: json['tie'] == true,
    wasSpy: json['wasSpy'] == true,
    ejectedUserId: json['ejectedUserId'] as String?,
    ejectedUsername: json['ejectedUsername'] as String?,
    counts: ((json['counts'] as List?) ?? const [])
        .map(
          (item) => VoteCount.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  @override
  List<Object?> get props => [
    tie,
    wasSpy,
    counts,
    ejectedUserId,
    ejectedUsername,
  ];
}

/// من خرج في أي جولة — سطر في شريط تاريخ الجلسة.
class Ejection extends Equatable {
  const Ejection({
    required this.round,
    required this.userId,
    required this.username,
    required this.wasSpy,
    required this.votes,
  });

  final int round;
  final String userId;
  final String username;
  final bool wasSpy;
  final int votes;

  factory Ejection.fromJson(Map<String, dynamic> json) => Ejection(
    round: (json['round'] as num?)?.toInt() ?? 0,
    userId: '${json['userId']}',
    username: '${json['username']}',
    wasSpy: json['wasSpy'] == true,
    votes: (json['votes'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [round, userId, username, wasSpy, votes];
}

/// موقع المستخدم من هذه الجلسة — ومنه وحده يعرف كلمته أو أنه الجاسوس.
class SpyRole extends Equatable {
  const SpyRole({
    required this.isPlayer,
    required this.isSpectator,
    required this.isHost,
    required this.canEndEarly,
    required this.isSpy,
    required this.isOut,
    this.word,
  });

  final bool isPlayer;
  final bool isSpectator;
  final bool isHost;
  final bool canEndEarly;

  /// يصل من السيرفر لصاحبه وحده — ولا يمرّ على القناة الحيّة أبداً.
  final bool isSpy;

  final bool isOut;

  /// الكلمة السرّية: تصل للاعبين غير الجاسوس فقط.
  final String? word;

  static const spectator = SpyRole(
    isPlayer: false,
    isSpectator: true,
    isHost: false,
    canEndEarly: false,
    isSpy: false,
    isOut: false,
  );

  factory SpyRole.fromJson(Map<String, dynamic> json) => SpyRole(
    isPlayer: json['isPlayer'] == true,
    isSpectator: json['isSpectator'] == true,
    isHost: json['isHost'] == true,
    canEndEarly: json['canEndEarly'] == true,
    isSpy: json['isSpy'] == true,
    isOut: json['isOut'] == true,
    word: json['word'] as String?,
  );

  SpyRole copyWith({bool? isHost, bool? canEndEarly, bool? isOut}) => SpyRole(
    isPlayer: isPlayer,
    isSpectator: isSpectator,
    isHost: isHost ?? this.isHost,
    canEndEarly: canEndEarly ?? this.canEndEarly,
    isSpy: isSpy,
    isOut: isOut ?? this.isOut,
    word: word,
  );

  @override
  List<Object?> get props => [
    isPlayer,
    isSpectator,
    isHost,
    canEndEarly,
    isSpy,
    isOut,
    word,
  ];
}

/// الجولة الجارية.
class SpyRound extends Equatable {
  const SpyRound({
    required this.number,
    required this.phase,
    required this.phaseStartedAt,
    required this.deadline,
    this.currentAskerId,
    this.currentAskerUsername,
    this.currentTurn,
    this.askQueue = const [],
    this.votedCount = 0,
    this.eligibleCount = 0,
    this.myVote,
    this.canAsk = false,
    this.canAnswer = false,
    this.canVote = false,
    this.voteResult,
    this.guessOptions = const [],
    this.spyUserId,
    this.spyUsername,
  });

  final int number;
  final SpyPhase phase;
  final int phaseStartedAt;
  final int deadline;

  final String? currentAskerId;
  final String? currentAskerUsername;

  /// السؤال المطروح الآن بانتظار جوابه.
  final SpyTurn? currentTurn;

  /// من بقي عليه أن يسأل في هذه الجولة.
  final List<String> askQueue;

  final int votedCount;
  final int eligibleCount;

  /// صوتي أنا — لا أحد غيري يراه قبل إعلان النتيجة.
  final String? myVote;

  final bool canAsk;
  final bool canAnswer;
  final bool canVote;

  final VoteOutcome? voteResult;

  /// خيارات فرصة الجاسوس الأخيرة — تظهر للجميع، فالباقون يعرفون الكلمة.
  final List<String> guessOptions;

  /// يصل فقط في مرحلة التخمين، بعد أن ينكشف الجاسوس بالتصويت.
  final String? spyUserId;
  final String? spyUsername;

  factory SpyRound.fromJson(Map<String, dynamic> json) => SpyRound(
    number: (json['no'] as num?)?.toInt() ?? 0,
    phase: SpyPhase.parse(json['phase']),
    phaseStartedAt: (json['phaseStartedAt'] as num?)?.toInt() ?? 0,
    deadline: (json['deadline'] as num?)?.toInt() ?? 0,
    currentAskerId: json['currentAskerId'] as String?,
    currentAskerUsername: json['currentAskerUsername'] as String?,
    currentTurn: json['currentTurn'] is Map
        ? SpyTurn.fromJson(
            Map<String, dynamic>.from(json['currentTurn'] as Map),
          )
        : null,
    askQueue: ((json['askQueue'] as List?) ?? const [])
        .map((id) => '$id')
        .toList(),
    votedCount: (json['votedCount'] as num?)?.toInt() ?? 0,
    eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
    myVote: json['myVote'] as String?,
    canAsk: json['canAsk'] == true,
    canAnswer: json['canAnswer'] == true,
    canVote: json['canVote'] == true,
    voteResult: json['voteResult'] is Map
        ? VoteOutcome.fromJson(
            Map<String, dynamic>.from(json['voteResult'] as Map),
          )
        : null,
    guessOptions: ((json['guessOptions'] as List?) ?? const [])
        .map((word) => '$word')
        .toList(),
    spyUserId: json['spyUserId'] as String?,
    spyUsername: json['spyUsername'] as String?,
  );

  SpyRound copyWith({
    int? number,
    SpyPhase? phase,
    int? phaseStartedAt,
    int? deadline,
    String? currentAskerId,
    String? currentAskerUsername,
    SpyTurn? currentTurn,
    bool clearTurn = false,
    List<String>? askQueue,
    int? votedCount,
    int? eligibleCount,
    String? myVote,
    bool? canAsk,
    bool? canAnswer,
    bool? canVote,
    VoteOutcome? voteResult,
    List<String>? guessOptions,
    String? spyUserId,
    String? spyUsername,
  }) => SpyRound(
    number: number ?? this.number,
    phase: phase ?? this.phase,
    phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
    deadline: deadline ?? this.deadline,
    currentAskerId: currentAskerId ?? this.currentAskerId,
    currentAskerUsername: currentAskerUsername ?? this.currentAskerUsername,
    currentTurn: clearTurn ? null : (currentTurn ?? this.currentTurn),
    askQueue: askQueue ?? this.askQueue,
    votedCount: votedCount ?? this.votedCount,
    eligibleCount: eligibleCount ?? this.eligibleCount,
    myVote: myVote ?? this.myVote,
    canAsk: canAsk ?? this.canAsk,
    canAnswer: canAnswer ?? this.canAnswer,
    canVote: canVote ?? this.canVote,
    voteResult: voteResult ?? this.voteResult,
    guessOptions: guessOptions ?? this.guessOptions,
    spyUserId: spyUserId ?? this.spyUserId,
    spyUsername: spyUsername ?? this.spyUsername,
  );

  @override
  List<Object?> get props => [
    number,
    phase,
    phaseStartedAt,
    deadline,
    currentAskerId,
    currentAskerUsername,
    currentTurn,
    askQueue,
    votedCount,
    eligibleCount,
    myVote,
    canAsk,
    canAnswer,
    canVote,
    voteResult,
    guessOptions,
    spyUserId,
    spyUsername,
  ];
}

/// سطر لاعب في شاشة النتيجة — بعد أن يُكشف كل شيء.
class SpyResultPlayer extends Equatable {
  const SpyResultPlayer({
    required this.userId,
    required this.username,
    required this.wasSpy,
    required this.won,
    required this.hasLeft,
    this.outAtRound,
    this.photoUrl,
    this.avatarId,
  });

  final String userId;
  final String username;
  final bool wasSpy;
  final bool won;
  final bool hasLeft;
  final int? outAtRound;
  final String? photoUrl;
  final String? avatarId;

  factory SpyResultPlayer.fromJson(Map<String, dynamic> json) =>
      SpyResultPlayer(
        userId: '${json['userId']}',
        username: '${json['username']}',
        wasSpy: json['wasSpy'] == true,
        won: json['won'] == true,
        hasLeft: json['hasLeft'] == true,
        outAtRound: (json['outAtRound'] as num?)?.toInt(),
        photoUrl: json['photoUrl'] as String?,
        avatarId: json['avatarId'] as String?,
      );

  @override
  List<Object?> get props => [
    userId,
    username,
    wasSpy,
    won,
    hasLeft,
    outAtRound,
    photoUrl,
    avatarId,
  ];
}

/// تخمين الجاسوس في فرصته الأخيرة.
class SpyGuess extends Equatable {
  const SpyGuess({required this.word, required this.correct});

  final String word;
  final bool correct;

  factory SpyGuess.fromJson(Map<String, dynamic> json) =>
      SpyGuess(word: '${json['word']}', correct: json['correct'] == true);

  @override
  List<Object?> get props => [word, correct];
}

/// النتيجة النهائية — هنا وحدها تُكشف الكلمة وهوية الجاسوس.
class SpyResult extends Equatable {
  const SpyResult({
    required this.winner,
    required this.reason,
    required this.headline,
    required this.players,
    required this.ejections,
    required this.roundsPlayed,
    this.word,
    this.categoryLabel,
    this.categoryEmoji,
    this.spyUserId,
    this.spyUsername,
    this.guess,
  });

  /// players | spy | none — و`none` تعني إنهاءً إدارياً بلا فائز.
  final String winner;
  final String reason;
  final String headline;
  final List<SpyResultPlayer> players;
  final List<Ejection> ejections;
  final int roundsPlayed;
  final String? word;
  final String? categoryLabel;
  final String? categoryEmoji;
  final String? spyUserId;
  final String? spyUsername;
  final SpyGuess? guess;

  bool get playersWon => winner == 'players';

  bool get spyWon => winner == 'spy';

  factory SpyResult.fromJson(Map<String, dynamic> json) => SpyResult(
    winner: '${json['winner']}',
    reason: '${json['reason']}',
    headline: '${json['headline'] ?? ''}',
    word: json['word'] as String?,
    categoryLabel: json['categoryLabel'] as String?,
    categoryEmoji: json['categoryEmoji'] as String?,
    spyUserId: json['spyUserId'] as String?,
    spyUsername: json['spyUsername'] as String?,
    roundsPlayed: (json['roundsPlayed'] as num?)?.toInt() ?? 0,
    guess: json['spyGuess'] is Map
        ? SpyGuess.fromJson(Map<String, dynamic>.from(json['spyGuess'] as Map))
        : null,
    players: ((json['players'] as List?) ?? const [])
        .map(
          (item) =>
              SpyResultPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    ejections: ((json['ejections'] as List?) ?? const [])
        .map(
          (item) => Ejection.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  @override
  List<Object?> get props => [
    winner,
    reason,
    headline,
    players,
    ejections,
    roundsPlayed,
    word,
    categoryLabel,
    categoryEmoji,
    spyUserId,
    spyUsername,
    guess,
  ];
}

/// لقطة الجلسة كما يراها هذا المستخدم.
class SpySnapshot extends Equatable {
  const SpySnapshot({
    required this.gameId,
    required this.channelId,
    required this.status,
    required this.config,
    required this.hostId,
    required this.players,
    required this.currentRound,
    required this.maxRounds,
    required this.transcript,
    required this.ejections,
    required this.estimatedSeconds,
    required this.canStart,
    required this.me,
    this.categoryLabel,
    this.categoryEmoji,
    this.round,
    this.result,
  });

  final String gameId;
  final String channelId;
  final String status;
  final SpyConfig config;
  final String hostId;
  final List<SpyPlayer> players;
  final int currentRound;
  final int maxRounds;

  /// كل الأسئلة والأجوبة منذ بداية الجلسة — وهذا ما يقرأه الجاسوس.
  final List<SpyTurn> transcript;

  final List<Ejection> ejections;
  final int estimatedSeconds;
  final bool canStart;
  final SpyRole me;

  /// المجموعة معروفة للجميع — الجاسوس يعرف أننا نتكلم عن حيوان.
  final String? categoryLabel;
  final String? categoryEmoji;

  final SpyRound? round;
  final SpyResult? result;

  bool get isLobby => status == 'lobby';

  bool get isPlaying => status == 'playing';

  bool get isFinished => status == 'finished' || status == 'abandoned';

  List<SpyPlayer> get seatedPlayers =>
      players.where((player) => !player.isSpectator).toList();

  List<SpyPlayer> get activePlayers =>
      players.where((player) => player.isActive).toList();

  SpyPlayer? playerById(String? id) {
    if (id == null) return null;

    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  /// أسئلة الجولة الحالية وحدها — أعلى السجل وأكثره دلالة.
  List<SpyTurn> get currentRoundTurns =>
      transcript.where((turn) => turn.round == currentRound).toList();

  factory SpySnapshot.fromJson(Map<String, dynamic> json) => SpySnapshot(
    gameId: '${json['gameId']}',
    channelId: '${json['channelId']}',
    status: '${json['status']}',
    config: SpyConfig.fromJson(
      json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
    ),
    hostId: '${json['hostId']}',
    players: ((json['players'] as List?) ?? const [])
        .map(
          (item) => SpyPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    currentRound: (json['currentRound'] as num?)?.toInt() ?? 0,
    maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 4,
    categoryLabel: json['categoryLabel'] as String?,
    categoryEmoji: json['categoryEmoji'] as String?,
    transcript: ((json['transcript'] as List?) ?? const [])
        .map((item) => SpyTurn.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    ejections: ((json['ejections'] as List?) ?? const [])
        .map(
          (item) => Ejection.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    estimatedSeconds: (json['estimatedSeconds'] as num?)?.toInt() ?? 0,
    canStart: json['canStart'] == true,
    me: json['me'] is Map
        ? SpyRole.fromJson(Map<String, dynamic>.from(json['me'] as Map))
        : SpyRole.spectator,
    round: json['round'] is Map
        ? SpyRound.fromJson(Map<String, dynamic>.from(json['round'] as Map))
        : null,
    result: json['result'] is Map
        ? SpyResult.fromJson(Map<String, dynamic>.from(json['result'] as Map))
        : null,
  );

  SpySnapshot copyWith({
    String? status,
    SpyConfig? config,
    String? hostId,
    List<SpyPlayer>? players,
    int? currentRound,
    int? maxRounds,
    List<SpyTurn>? transcript,
    List<Ejection>? ejections,
    int? estimatedSeconds,
    bool? canStart,
    SpyRole? me,
    String? categoryLabel,
    String? categoryEmoji,
    SpyRound? round,
    bool clearRound = false,
    SpyResult? result,
  }) => SpySnapshot(
    gameId: gameId,
    channelId: channelId,
    status: status ?? this.status,
    config: config ?? this.config,
    hostId: hostId ?? this.hostId,
    players: players ?? this.players,
    currentRound: currentRound ?? this.currentRound,
    maxRounds: maxRounds ?? this.maxRounds,
    transcript: transcript ?? this.transcript,
    ejections: ejections ?? this.ejections,
    estimatedSeconds: estimatedSeconds ?? this.estimatedSeconds,
    canStart: canStart ?? this.canStart,
    me: me ?? this.me,
    categoryLabel: categoryLabel ?? this.categoryLabel,
    categoryEmoji: categoryEmoji ?? this.categoryEmoji,
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
    maxRounds,
    transcript,
    ejections,
    estimatedSeconds,
    canStart,
    me,
    categoryLabel,
    categoryEmoji,
    round,
    result,
  ];
}
