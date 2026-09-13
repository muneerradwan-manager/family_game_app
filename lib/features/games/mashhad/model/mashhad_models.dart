import 'package:equatable/equatable.dart';

import '../../../../core/network/json.dart';

/// مراحل المشهد كما يعرّفها السيرفر. الجهاز يعرض ما يقوله السيرفر ولا يقرّر.
enum MashhadPhase {
  roleReveal('role_reveal'),
  scene('scene'),
  claims('claims'),
  challenge('challenge'),
  verdict('verdict'),
  scoreboard('scoreboard'),
  awards('awards');

  const MashhadPhase(this.value);

  final String value;

  static MashhadPhase parse(Object? value) => MashhadPhase.values.firstWhere(
    (phase) => phase.value == '$value',
    orElse: () => MashhadPhase.roleReveal,
  );

  /// المراحل التي انكشفت فيها الأدوار والأهداف للجميع.
  bool get isRevealed => const {
    MashhadPhase.challenge,
    MashhadPhase.verdict,
    MashhadPhase.scoreboard,
    MashhadPhase.awards,
  }.contains(this);
}

class MashhadConfig extends Equatable {
  const MashhadConfig({
    required this.scenes,
    required this.sceneSeconds,
    required this.familyMode,
    required this.challengesPerPlayer,
    this.category,
    this.categoryLabel,
    this.categoryEmoji,
  });

  final int scenes;
  final int sceneSeconds;
  final bool familyMode;
  final int challengesPerPlayer;
  final String? category;
  final String? categoryLabel;
  final String? categoryEmoji;

  static const empty = MashhadConfig(
    scenes: 2,
    sceneSeconds: 180,
    familyMode: false,
    challengesPerPlayer: 2,
  );

  factory MashhadConfig.fromJson(Map<String, dynamic> json) => MashhadConfig(
    scenes: (json['scenes'] as num?)?.toInt() ?? 2,
    sceneSeconds: (json['sceneSeconds'] as num?)?.toInt() ?? 180,
    familyMode: json['familyMode'] == true,
    challengesPerPlayer: (json['challengesPerPlayer'] as num?)?.toInt() ?? 2,
    category: json['category'] as String?,
    categoryLabel: json['categoryLabel'] as String?,
    categoryEmoji: json['categoryEmoji'] as String?,
  );

  @override
  List<Object?> get props => [
    scenes,
    sceneSeconds,
    familyMode,
    challengesPerPlayer,
    category,
    categoryLabel,
    categoryEmoji,
  ];
}

class MashhadPlayer extends Equatable {
  const MashhadPlayer({
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

  bool get isActive => !isSpectator && !hasLeft;

  factory MashhadPlayer.fromJson(Map<String, dynamic> json) => MashhadPlayer(
    id: '${json['id']}',
    username: '${json['username']}',
    isSpectator: json['isSpectator'] == true,
    hasLeft: json['leftAtScene'] != null,
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

/// دوري في هذا المشهد — يصلني وحدي ولا يمرّ على القناة الحيّة.
class MyRole extends Equatable {
  const MyRole({
    required this.name,
    required this.goal,
    required this.difficulty,
    required this.isFiller,
    this.bonus,
    this.secret,
  });

  final String name;
  final String goal;
  final String difficulty;

  /// دور عام من مجموعة الحشو لا من أدوار المشهد الأساسية.
  final bool isFiller;

  final String? bonus;
  final String? secret;

  String get difficultyLabel => switch (difficulty) {
    'easy' => 'سهل',
    'hard' => 'صعب',
    _ => 'متوسط',
  };

  factory MyRole.fromJson(Map<String, dynamic> json) => MyRole(
    name: '${json['name']}',
    goal: '${json['goal']}',
    difficulty: '${json['difficulty'] ?? 'medium'}',
    isFiller: json['filler'] == true,
    bonus: json['bonus'] as String?,
    secret: json['secret'] as String?,
  );

  @override
  List<Object?> get props => [name, goal, difficulty, isFiller, bonus, secret];
}

/// رسالة داخل المشهد.
class SceneMessage extends Equatable {
  const SceneMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.at,
    this.role,
  });

  final String id;
  final String userId;
  final String username;
  final String text;
  final int at;

  /// اسم الشخصية التي يمثّلها — يظهر بجانب اسمه فيتذكّر الجميع من هو.
  final String? role;

  factory SceneMessage.fromJson(Map<String, dynamic> json) => SceneMessage(
    id: '${json['id']}',
    userId: '${json['userId']}',
    username: '${json['username']}',
    text: '${json['text']}',
    at: (json['at'] as num?)?.toInt() ?? 0,
    role: json['role'] as String?,
  );

  @override
  List<Object?> get props => [id, userId, username, text, at, role];
}

/// حدث مفاجئ — عام للجميع أو خاص بي وحدي.
class SceneEvent extends Equatable {
  const SceneEvent({required this.text, required this.scope, required this.at});

  final String text;

  /// all = وصل الجميع · one = وصلني أنا وحدي
  final String scope;
  final int at;

  bool get isPrivate => scope == 'one';

  factory SceneEvent.fromJson(Map<String, dynamic> json) => SceneEvent(
    text: '${json['text']}',
    scope: '${json['scope'] ?? 'all'}',
    at: (json['at'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [text, scope, at];
}

/// ما ادّعيته بعد نهاية المشهد.
class MyClaim extends Equatable {
  const MyClaim({required this.main, required this.bonus, required this.event});

  final bool main;
  final bool bonus;
  final bool event;

  factory MyClaim.fromJson(Map<String, dynamic> json) => MyClaim(
    main: json['main'] == true,
    bonus: json['bonus'] == true,
    event: json['event'] == true,
  );

  @override
  List<Object?> get props => [main, bonus, event];
}

/// سطر الكشف الكبير: دور لاعب وهدفه وما ادّعاه.
class ClaimRow extends Equatable {
  const ClaimRow({
    required this.userId,
    required this.username,
    required this.roleName,
    required this.goal,
    required this.difficulty,
    required this.claimedMain,
    required this.claimedBonus,
    required this.claimedEvent,
    required this.messageCount,
    this.bonus,
    this.secret,
  });

  final String userId;
  final String username;
  final String roleName;
  final String goal;
  final String difficulty;
  final bool claimedMain;
  final bool claimedBonus;
  final bool claimedEvent;
  final int messageCount;
  final String? bonus;
  final String? secret;

  factory ClaimRow.fromJson(Map<String, dynamic> json) => ClaimRow(
    userId: '${json['userId']}',
    username: '${json['username']}',
    roleName: '${json['roleName']}',
    goal: '${json['goal']}',
    difficulty: '${json['difficulty'] ?? 'medium'}',
    claimedMain: json['claimedMain'] == true,
    claimedBonus: json['claimedBonus'] == true,
    claimedEvent: json['claimedEvent'] == true,
    messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    bonus: json['bonus'] as String?,
    secret: json['secret'] as String?,
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    roleName,
    goal,
    difficulty,
    claimedMain,
    claimedBonus,
    claimedEvent,
    messageCount,
    bonus,
    secret,
  ];
}

/// الاعتراض المعروض حالياً للتصويت — واحد في كل مرة.
class ChallengeView extends Equatable {
  const ChallengeView({
    required this.id,
    required this.byUsername,
    required this.targetUserId,
    required this.targetUsername,
    required this.kind,
    required this.roleName,
    required this.goal,
    required this.isParty,
    required this.hasVoted,
  });

  final String id;
  final String byUsername;
  final String targetUserId;
  final String targetUsername;

  /// main · bonus · event
  final String kind;

  final String roleName;
  final String goal;

  /// المعترِض والمعترَض عليه وشركاؤهما لا يصوّتون — كلهم أصحاب مصلحة.
  final bool isParty;
  final bool hasVoted;

  String get kindLabel => switch (kind) {
    'bonus' => 'الهدف الإضافي',
    'event' => 'استغلال الحدث',
    _ => 'الهدف الرئيسي',
  };

  factory ChallengeView.fromJson(Map<String, dynamic> json) => ChallengeView(
    id: '${json['challengeId']}',
    byUsername: '${json['byUsername']}',
    targetUserId: '${json['targetUserId']}',
    targetUsername: '${json['targetUsername']}',
    kind: '${json['kind']}',
    roleName: '${json['roleName']}',
    goal: '${json['goal']}',
    isParty: json['isParty'] == true,
    hasVoted: json['hasVoted'] == true,
  );

  ChallengeView copyWith({bool? hasVoted}) => ChallengeView(
    id: id,
    byUsername: byUsername,
    targetUserId: targetUserId,
    targetUsername: targetUsername,
    kind: kind,
    roleName: roleName,
    goal: goal,
    isParty: isParty,
    hasVoted: hasVoted ?? this.hasVoted,
  );

  @override
  List<Object?> get props => [
    id,
    byUsername,
    targetUserId,
    targetUsername,
    kind,
    roleName,
    goal,
    isParty,
    hasVoted,
  ];
}

/// نقاط لاعب في مشهد واحد.
class SceneScore extends Equatable {
  const SceneScore({
    required this.userId,
    required this.username,
    required this.roleName,
    required this.goal,
    required this.mainAchieved,
    required this.bonusAchieved,
    required this.eventAchieved,
    required this.penalties,
    required this.points,
  });

  final String userId;
  final String username;
  final String roleName;
  final String goal;
  final bool mainAchieved;
  final bool bonusAchieved;
  final bool eventAchieved;
  final int penalties;
  final int points;

  factory SceneScore.fromJson(Map<String, dynamic> json) => SceneScore(
    userId: '${json['userId']}',
    username: '${json['username']}',
    roleName: '${json['roleName']}',
    goal: '${json['goal']}',
    mainAchieved: json['mainAchieved'] == true,
    bonusAchieved: json['bonusAchieved'] == true,
    eventAchieved: json['eventAchieved'] == true,
    penalties: (json['penalties'] as num?)?.toInt() ?? 0,
    points: (json['points'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    roleName,
    goal,
    mainAchieved,
    bonusAchieved,
    eventAchieved,
    penalties,
    points,
  ];
}

/// فئة جائزة نهاية المباراة.
class AwardKind extends Equatable {
  const AwardKind({
    required this.key,
    required this.emoji,
    required this.label,
  });

  final String key;
  final String emoji;
  final String label;

  factory AwardKind.fromJson(Map<String, dynamic> json) => AwardKind(
    key: '${json['key']}',
    emoji: '${json['emoji']}',
    label: '${json['label']}',
  );

  @override
  List<Object?> get props => [key, emoji, label];
}

/// جائزة مُنحت في نهاية المباراة.
class AwardResult extends Equatable {
  const AwardResult({
    required this.key,
    required this.emoji,
    required this.label,
    required this.winners,
    required this.votes,
  });

  final String key;
  final String emoji;
  final String label;
  final List<String> winners;
  final int votes;

  factory AwardResult.fromJson(Map<String, dynamic> json) => AwardResult(
    key: '${json['key']}',
    emoji: '${json['emoji']}',
    label: '${json['label']}',
    votes: (json['votes'] as num?)?.toInt() ?? 0,
    winners: ((json['winners'] as List?) ?? const [])
        .map((item) => '${(item as Map)['username']}')
        .toList(),
  );

  @override
  List<Object?> get props => [key, emoji, label, winners, votes];
}

/// سطر في لوحة النتائج.
class Standing extends Equatable {
  const Standing({
    required this.userId,
    required this.username,
    required this.total,
    required this.goalsAchieved,
    required this.messageCount,
    required this.awards,
    required this.hasLeft,
    this.photoUrl,
    this.avatarId,
  });

  final String userId;
  final String username;
  final int total;
  final int goalsAchieved;
  final int messageCount;
  final List<String> awards;
  final bool hasLeft;
  final String? photoUrl;
  final String? avatarId;

  factory Standing.fromJson(Map<String, dynamic> json) => Standing(
    userId: '${json['userId']}',
    username: '${json['username']}',
    total: (json['total'] as num?)?.toInt() ?? 0,
    goalsAchieved: (json['goalsAchieved'] as num?)?.toInt() ?? 0,
    messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    awards: ((json['awards'] as List?) ?? const []).map((a) => '$a').toList(),
    hasLeft: json['left'] == true,
    photoUrl: json['photoUrl'] as String?,
    avatarId: json['avatarId'] as String?,
  );

  @override
  List<Object?> get props => [
    userId,
    username,
    total,
    goalsAchieved,
    messageCount,
    awards,
    hasLeft,
    photoUrl,
    avatarId,
  ];
}

/// موقع المستخدم من هذه الجلسة.
class MashhadRole extends Equatable {
  const MashhadRole({
    required this.isPlayer,
    required this.isSpectator,
    required this.isHost,
    required this.canEndEarly,
    required this.total,
    required this.goalsAchieved,
  });

  final bool isPlayer;
  final bool isSpectator;
  final bool isHost;
  final bool canEndEarly;
  final int total;
  final int goalsAchieved;

  static const spectator = MashhadRole(
    isPlayer: false,
    isSpectator: true,
    isHost: false,
    canEndEarly: false,
    total: 0,
    goalsAchieved: 0,
  );

  factory MashhadRole.fromJson(Map<String, dynamic> json) => MashhadRole(
    isPlayer: json['isPlayer'] == true,
    isSpectator: json['isSpectator'] == true,
    isHost: json['isHost'] == true,
    canEndEarly: json['canEndEarly'] == true,
    total: (json['total'] as num?)?.toInt() ?? 0,
    goalsAchieved: (json['goalsAchieved'] as num?)?.toInt() ?? 0,
  );

  MashhadRole copyWith({bool? isHost, int? total, int? goalsAchieved}) =>
      MashhadRole(
        isPlayer: isPlayer,
        isSpectator: isSpectator,
        isHost: isHost ?? this.isHost,
        canEndEarly: canEndEarly,
        total: total ?? this.total,
        goalsAchieved: goalsAchieved ?? this.goalsAchieved,
      );

  @override
  List<Object?> get props => [
    isPlayer,
    isSpectator,
    isHost,
    canEndEarly,
    total,
    goalsAchieved,
  ];
}

/// المشهد الجاري.
class MashhadRound extends Equatable {
  const MashhadRound({
    required this.number,
    required this.phase,
    required this.phaseStartedAt,
    required this.deadline,
    required this.title,
    required this.setup,
    this.categoryLabel,
    this.categoryEmoji,
    this.myRole,
    this.transcript = const [],
    this.myEvents = const [],
    this.myClaim,
    this.claimedCount = 0,
    this.activeCount = 0,
    this.canClaimEvent = false,
    this.rows = const [],
    this.challengesLeft = 2,
    this.challenge,
    this.sceneScores = const [],
    this.awards = const [],
    this.myAwardVotes = const {},
  });

  final int number;
  final MashhadPhase phase;
  final int phaseStartedAt;
  final int deadline;
  final String title;
  final String setup;
  final String? categoryLabel;
  final String? categoryEmoji;

  /// دوري أنا — لا أحد غيري يراه قبل الكشف.
  final MyRole? myRole;

  final List<SceneMessage> transcript;

  /// الأحداث التي تخصّني: العامة كلها، والخاصة التي وصلتني وحدي.
  final List<SceneEvent> myEvents;

  final MyClaim? myClaim;
  final int claimedCount;
  final int activeCount;

  /// وصلني حدث خاص، فيحقّ لي أن أدّعي أني استغللته.
  final bool canClaimEvent;

  /// الكشف الكبير — يمتلئ في مرحلة الاعتراض وما بعدها.
  final List<ClaimRow> rows;

  final int challengesLeft;
  final ChallengeView? challenge;
  final List<SceneScore> sceneScores;
  final List<AwardKind> awards;
  final Map<String, String> myAwardVotes;

  bool get hasClaimed => myClaim != null;

  factory MashhadRound.fromJson(Map<String, dynamic> json) => MashhadRound(
    number: (json['no'] as num?)?.toInt() ?? 0,
    phase: MashhadPhase.parse(json['phase']),
    phaseStartedAt: (json['phaseStartedAt'] as num?)?.toInt() ?? 0,
    deadline: (json['deadline'] as num?)?.toInt() ?? 0,
    title: '${json['title'] ?? ''}',
    setup: '${json['setup'] ?? ''}',
    categoryLabel: json['categoryLabel'] as String?,
    categoryEmoji: json['categoryEmoji'] as String?,
    myRole: json['myRole'] is Map
        ? MyRole.fromJson(Map<String, dynamic>.from(json['myRole'] as Map))
        : null,
    transcript: ((json['transcript'] as List?) ?? const [])
        .map(
          (item) =>
              SceneMessage.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    myEvents: ((json['myEvents'] as List?) ?? const [])
        .map(
          (item) => SceneEvent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    myClaim: json['myClaim'] is Map
        ? MyClaim.fromJson(Map<String, dynamic>.from(json['myClaim'] as Map))
        : null,
    claimedCount: (json['claimedCount'] as num?)?.toInt() ?? 0,
    activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
    canClaimEvent: json['canClaimEvent'] == true,
    rows: ((json['rows'] as List?) ?? const [])
        .map(
          (item) => ClaimRow.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    challengesLeft: (json['myChallengesLeft'] as num?)?.toInt() ?? 2,
    challenge: json['challenge'] is Map
        ? ChallengeView.fromJson(
            Map<String, dynamic>.from(json['challenge'] as Map),
          )
        : null,
    sceneScores: ((json['sceneScores'] as List?) ?? const [])
        .map(
          (item) => SceneScore.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    awards: ((json['awards'] as List?) ?? const [])
        .map(
          (item) => AwardKind.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    myAwardVotes: asStringMap(json['myAwardVotes']),
  );

  MashhadRound copyWith({
    int? number,
    MashhadPhase? phase,
    int? phaseStartedAt,
    int? deadline,
    String? title,
    String? setup,
    String? categoryLabel,
    String? categoryEmoji,
    MyRole? myRole,
    List<SceneMessage>? transcript,
    List<SceneEvent>? myEvents,
    MyClaim? myClaim,
    int? claimedCount,
    int? activeCount,
    bool? canClaimEvent,
    List<ClaimRow>? rows,
    int? challengesLeft,
    ChallengeView? challenge,
    bool clearChallenge = false,
    List<SceneScore>? sceneScores,
    List<AwardKind>? awards,
    Map<String, String>? myAwardVotes,
  }) => MashhadRound(
    number: number ?? this.number,
    phase: phase ?? this.phase,
    phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
    deadline: deadline ?? this.deadline,
    title: title ?? this.title,
    setup: setup ?? this.setup,
    categoryLabel: categoryLabel ?? this.categoryLabel,
    categoryEmoji: categoryEmoji ?? this.categoryEmoji,
    myRole: myRole ?? this.myRole,
    transcript: transcript ?? this.transcript,
    myEvents: myEvents ?? this.myEvents,
    myClaim: myClaim ?? this.myClaim,
    claimedCount: claimedCount ?? this.claimedCount,
    activeCount: activeCount ?? this.activeCount,
    canClaimEvent: canClaimEvent ?? this.canClaimEvent,
    rows: rows ?? this.rows,
    challengesLeft: challengesLeft ?? this.challengesLeft,
    challenge: clearChallenge ? null : (challenge ?? this.challenge),
    sceneScores: sceneScores ?? this.sceneScores,
    awards: awards ?? this.awards,
    myAwardVotes: myAwardVotes ?? this.myAwardVotes,
  );

  @override
  List<Object?> get props => [
    number,
    phase,
    phaseStartedAt,
    deadline,
    title,
    setup,
    categoryLabel,
    categoryEmoji,
    myRole,
    transcript,
    myEvents,
    myClaim,
    claimedCount,
    activeCount,
    canClaimEvent,
    rows,
    challengesLeft,
    challenge,
    sceneScores,
    awards,
    myAwardVotes,
  ];
}

/// النتيجة النهائية.
class MashhadResult extends Equatable {
  const MashhadResult({
    required this.winnerId,
    required this.finalScores,
    required this.awards,
    required this.endedEarly,
    required this.scenesPlayed,
    this.reason,
  });

  final String? winnerId;
  final List<Standing> finalScores;
  final List<AwardResult> awards;
  final bool endedEarly;
  final int scenesPlayed;
  final String? reason;

  Standing? get winner {
    for (final row in finalScores) {
      if (row.userId == winnerId) return row;
    }
    return finalScores.isEmpty ? null : finalScores.first;
  }

  factory MashhadResult.fromJson(Map<String, dynamic> json) => MashhadResult(
    winnerId: json['winnerId'] as String?,
    finalScores: ((json['finalScores'] as List?) ?? const [])
        .map(
          (item) => Standing.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    awards: ((json['awards'] as List?) ?? const [])
        .map(
          (item) =>
              AwardResult.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    endedEarly: json['endedEarly'] == true,
    scenesPlayed: (json['scenesPlayed'] as num?)?.toInt() ?? 0,
    reason: json['reason'] as String?,
  );

  @override
  List<Object?> get props => [
    winnerId,
    finalScores,
    awards,
    endedEarly,
    scenesPlayed,
    reason,
  ];
}

/// لقطة الجلسة كما يراها هذا المستخدم.
class MashhadSnapshot extends Equatable {
  const MashhadSnapshot({
    required this.gameId,
    required this.channelId,
    required this.status,
    required this.config,
    required this.hostId,
    required this.players,
    required this.currentScene,
    required this.totalScenes,
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
  final MashhadConfig config;
  final String hostId;
  final List<MashhadPlayer> players;
  final int currentScene;
  final int totalScenes;
  final List<Standing> standings;
  final int estimatedSeconds;
  final bool canStart;
  final MashhadRole me;
  final MashhadRound? round;
  final MashhadResult? result;

  bool get isLobby => status == 'lobby';

  bool get isPlaying => status == 'playing';

  bool get isFinished => status == 'finished' || status == 'abandoned';

  List<MashhadPlayer> get seatedPlayers =>
      players.where((player) => !player.isSpectator).toList();

  List<MashhadPlayer> get activePlayers =>
      players.where((player) => player.isActive).toList();

  MashhadPlayer? playerById(String? id) {
    if (id == null) return null;

    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  factory MashhadSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => MashhadSnapshot(
    gameId: '${json['gameId']}',
    channelId: '${json['channelId']}',
    status: '${json['status']}',
    config: MashhadConfig.fromJson(
      json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
    ),
    hostId: '${json['hostId']}',
    players: ((json['players'] as List?) ?? const [])
        .map(
          (item) =>
              MashhadPlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    currentScene: (json['currentScene'] as num?)?.toInt() ?? 0,
    totalScenes: (json['totalScenes'] as num?)?.toInt() ?? 0,
    standings: ((json['standings'] as List?) ?? const [])
        .map(
          (item) => Standing.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    estimatedSeconds: (json['estimatedSeconds'] as num?)?.toInt() ?? 0,
    canStart: json['canStart'] == true,
    me: json['me'] is Map
        ? MashhadRole.fromJson(Map<String, dynamic>.from(json['me'] as Map))
        : MashhadRole.spectator,
    round: json['round'] is Map
        ? MashhadRound.fromJson(Map<String, dynamic>.from(json['round'] as Map))
        : null,
    result: json['result'] is Map
        ? MashhadResult.fromJson(
            Map<String, dynamic>.from(json['result'] as Map),
          )
        : null,
  );

  MashhadSnapshot copyWith({
    String? status,
    MashhadConfig? config,
    String? hostId,
    List<MashhadPlayer>? players,
    int? currentScene,
    int? totalScenes,
    List<Standing>? standings,
    int? estimatedSeconds,
    bool? canStart,
    MashhadRole? me,
    MashhadRound? round,
    bool clearRound = false,
    MashhadResult? result,
  }) => MashhadSnapshot(
    gameId: gameId,
    channelId: channelId,
    status: status ?? this.status,
    config: config ?? this.config,
    hostId: hostId ?? this.hostId,
    players: players ?? this.players,
    currentScene: currentScene ?? this.currentScene,
    totalScenes: totalScenes ?? this.totalScenes,
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
    currentScene,
    totalScenes,
    standings,
    estimatedSeconds,
    canStart,
    me,
    round,
    result,
  ];
}
