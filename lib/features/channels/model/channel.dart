import 'package:equatable/equatable.dart';

import '../../auth/model/app_user.dart';

class ChannelMember extends Equatable {
  const ChannelMember({
    required this.id,
    required this.username,
    required this.fullName,
    required this.gender,
    required this.isOwner,
    this.photoUrl,
    this.avatarId,
  });

  final String id;
  final String username;
  final String fullName;
  final Gender gender;
  final bool isOwner;
  final String? photoUrl;
  final String? avatarId;

  factory ChannelMember.fromJson(Map<String, dynamic> json) => ChannelMember(
    id: '${json['id']}',
    username: '${json['username']}',
    fullName: '${json['fullName'] ?? ''}',
    gender: Gender.parse(json['gender']),
    isOwner: '${json['role']}' == 'owner',
    photoUrl: json['photoUrl'] as String?,
    avatarId: json['avatarId'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    gender,
    isOwner,
    photoUrl,
    avatarId,
  ];
}

/// اللعبة الجارية في القناة — مصدر البطاقة البارزة أعلى شاشة القناة.
class ActiveGame extends Equatable {
  const ActiveGame({
    required this.id,
    required this.gameType,
    required this.status,
    this.playerCount = 0,
    this.startedByUsername,
  });

  final String id;
  final String gameType;
  final String status;
  final int playerCount;
  final String? startedByUsername;

  /// في اللوبي ينضم الداخل لاعباً؛ بعد البدء يتفرّج فقط.
  bool get isLobby => status == 'lobby';

  factory ActiveGame.fromJson(Map<String, dynamic> json) => ActiveGame(
    id: '${json['id']}',
    gameType: '${json['gameType']}',
    status: '${json['status']}',
    playerCount: (json['playerCount'] as num?)?.toInt() ?? 0,
    startedByUsername: json['startedByUsername'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    gameType,
    status,
    playerCount,
    startedByUsername,
  ];
}

class Channel extends Equatable {
  const Channel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.isOwner,
    required this.inviteCode,
    this.photoUrl,
    this.memberCount = 0,
    this.members = const [],
    this.activeGame,
  });

  final String id;
  final String name;
  final String ownerId;
  final bool isOwner;
  final String inviteCode;
  final String? photoUrl;
  final int memberCount;
  final List<ChannelMember> members;
  final ActiveGame? activeGame;

  String get inviteLink => 'https://family-games.app/join/$inviteCode';

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    id: '${json['id']}',
    name: '${json['name']}',
    ownerId: '${json['ownerId']}',
    isOwner: json['isOwner'] == true,
    inviteCode: '${json['inviteCode']}',
    photoUrl: json['photoUrl'] as String?,
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    members:
        (json['members'] as List?)
            ?.map(
              (item) => ChannelMember.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList() ??
        const [],
    activeGame: json['activeGame'] is Map
        ? ActiveGame.fromJson(
            Map<String, dynamic>.from(json['activeGame'] as Map),
          )
        : null,
  );

  Channel copyWith({
    ActiveGame? activeGame,
    bool clearActiveGame = false,
    String? name,
    String? photoUrl,
    String? inviteCode,
  }) => Channel(
    id: id,
    name: name ?? this.name,
    ownerId: ownerId,
    isOwner: isOwner,
    inviteCode: inviteCode ?? this.inviteCode,
    photoUrl: photoUrl ?? this.photoUrl,
    memberCount: memberCount,
    members: members,
    activeGame: clearActiveGame ? null : (activeGame ?? this.activeGame),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    ownerId,
    isOwner,
    inviteCode,
    photoUrl,
    memberCount,
    members,
    activeGame,
  ];
}

/// سطر في سجل الألعاب.
class GameRecord extends Equatable {
  const GameRecord({
    required this.id,
    required this.gameType,
    required this.playerCount,
    required this.finishedAt,
    this.outcome,
    this.endedEarly = false,
  });

  final String id;
  final String gameType;
  final int playerCount;
  final DateTime? finishedAt;

  /// سطر النتيجة كما تكتبه اللعبة نفسها.
  ///
  /// لكل لعبة معنى مختلف للفوز: الحروف لها فائز واحد بأعلى نقاط، والجاسوس
  /// له فريقان. فبدل أن يخمّن السجل، تكتب كل وحدة `headline` في نتيجتها —
  /// ونعود لاسم صاحب أعلى نتيجة لمن لم يكتبه.
  final String? outcome;

  final bool endedEarly;

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : const <String, dynamic>{};

    final scores = (result['finalScores'] as List?) ?? const [];
    final winnerId = result['winnerId'];

    String? outcome = result['headline'] as String?;

    if (outcome == null) {
      for (final row in scores) {
        final map = Map<String, dynamic>.from(row as Map);
        if ('${map['userId']}' == '$winnerId') {
          outcome = 'الفائز: ${map['username']}';
        }
      }
    }

    return GameRecord(
      id: '${json['id']}',
      gameType: '${json['gameType']}',
      playerCount:
          (json['playerCount'] as num?)?.toInt() ??
          ((result['players'] as List?)?.length ?? scores.length),
      finishedAt: DateTime.tryParse('${json['finishedAt']}'),
      outcome: outcome,
      endedEarly: result['endedEarly'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    gameType,
    playerCount,
    finishedAt,
    outcome,
    endedEarly,
  ];
}
