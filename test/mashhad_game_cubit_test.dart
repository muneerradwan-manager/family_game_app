import 'dart:async';

import 'package:family_game_app/core/realtime/realtime_client.dart';
import 'package:family_game_app/features/games/data/game_repository.dart';
import 'package:family_game_app/features/games/mashhad/cubit/mashhad_game_cubit.dart';
import 'package:family_game_app/features/games/mashhad/cubit/mashhad_signal.dart';
import 'package:family_game_app/features/games/mashhad/data/mashhad_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGameRepository extends Mock implements GameRepository {}

class _MockMashhadRepository extends Mock implements MashhadRepository {}

class _MockRealtime extends Mock implements RealtimeClient {}

const _me = 'user-me';
const _other = 'user-other';
const _third = 'user-third';
const _gameId = 'game-1';

Map<String, dynamic> _myRole({String? bonus, String? secret}) => {
  'name': 'الأب',
  'goal': 'شغّل الكهربا قبل ما يخلص المشهد',
  'difficulty': 'hard',
  'filler': false,
  'bonus': bonus,
  'secret': secret,
};

Map<String, dynamic> _snapshotJson({
  String status = 'playing',
  String phase = 'scene',
  bool isSpectator = false,
  bool withRole = true,
  int challengesLeft = 2,
  Map<String, dynamic>? roundOverrides,
}) => {
  'gameId': _gameId,
  'channelId': 'channel-1',
  'status': status,
  'hostId': _me,
  'config': {
    'category': 'daily',
    'categoryLabel': 'مواقف يومية',
    'scenes': 2,
    'sceneSeconds': 180,
    'familyMode': false,
    'challengesPerPlayer': 2,
  },
  'players': [
    {'id': _me, 'username': 'me', 'isSpectator': isSpectator},
    {'id': _other, 'username': 'other', 'isSpectator': false},
    {'id': _third, 'username': 'third', 'isSpectator': false},
  ],
  'currentScene': 1,
  'totalScenes': 2,
  'standings': const <Map<String, dynamic>>[],
  'estimatedSeconds': 600,
  'canStart': true,
  'me': {
    'isPlayer': !isSpectator,
    'isSpectator': isSpectator,
    'isHost': true,
    'canEndEarly': true,
    'total': 0,
    'goalsAchieved': 0,
  },
  'round': {
    'no': 1,
    'phase': phase,
    'phaseStartedAt': 1000,
    'deadline': 181000,
    'title': 'انقطعت الكهرباء',
    'setup': 'الكل بالبيت وفجأة راحت الكهربا',
    'categoryLabel': 'مواقف يومية',
    'categoryEmoji': '🏠',
    'myRole': withRole && !isSpectator ? _myRole() : null,
    'transcript': const <Map<String, dynamic>>[],
    'myEvents': const <Map<String, dynamic>>[],
    'myClaim': null,
    'claimedCount': 0,
    'activeCount': 3,
    'canClaimEvent': false,
    'rows': const <Map<String, dynamic>>[],
    'myChallengesLeft': challengesLeft,
    'challenge': null,
    'sceneScores': const <Map<String, dynamic>>[],
    'awards': const <Map<String, dynamic>>[],
    'myAwardVotes': const <String, String>{},
    ...?roundOverrides,
  },
};

Map<String, dynamic> _claimRow(
  String userId,
  String username, {
  bool claimedMain = true,
}) => {
  'userId': userId,
  'username': username,
  'roleName': 'الجار',
  'goal': 'خلّي الكل يعرف إنك حليت المشكلة',
  'difficulty': 'medium',
  'claimedMain': claimedMain,
  'claimedBonus': false,
  'claimedEvent': false,
  'messageCount': 4,
};

void main() {
  late _MockGameRepository games;
  late _MockMashhadRepository mashhad;
  late _MockRealtime realtime;
  late StreamController<RealtimeEvent> events;
  late StreamController<RealtimeStatus> status;
  late StreamController<void> reconnects;

  MashhadGameCubit build() => MashhadGameCubit(
    games: games,
    mashhad: mashhad,
    realtime: realtime,
    gameId: _gameId,
    viewerId: _me,
  );

  void emit(String name, Map<String, dynamic> data) => events.add(
    RealtimeEvent(channel: 'game.$_gameId', name: name, data: data),
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  setUp(() {
    games = _MockGameRepository();
    mashhad = _MockMashhadRepository();
    realtime = _MockRealtime();
    events = StreamController<RealtimeEvent>.broadcast();
    status = StreamController<RealtimeStatus>.broadcast();
    reconnects = StreamController<void>.broadcast();

    when(() => realtime.events).thenAnswer((_) => events.stream);
    when(() => realtime.status).thenAnswer((_) => status.stream);
    when(() => realtime.reconnected).thenAnswer((_) => reconnects.stream);
    when(() => realtime.subscribe(any())).thenAnswer((_) async {});
    when(() => realtime.unsubscribe(any())).thenAnswer((_) async {});

    when(() => games.join(any())).thenAnswer((_) async => _snapshotJson());
    when(() => games.snapshot(any())).thenAnswer((_) async => _snapshotJson());
  });

  tearDown(() async {
    await events.close();
    await status.close();
    await reconnects.close();
  });

  group('الدور السرّي', () {
    test('دوري يصلني كاملاً ولا يصل غيري', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(
          phase: 'role_reveal',
          roundOverrides: {
            'myRole': _myRole(bonus: 'خلّي حدا غيرك يطلع', secret: 'إنت فصلته'),
          },
        ),
      );

      final cubit = build();
      await cubit.enter();

      final role = cubit.state.round!.myRole!;

      expect(role.name, 'الأب');
      expect(role.bonus, 'خلّي حدا غيرك يطلع');
      expect(role.secret, 'إنت فصلته');
      // قبل الكشف ما في أي سطر عن أهداف الباقيين.
      expect(cubit.state.round!.rows, isEmpty);

      await cubit.close();
    });

    test('بداية مشهد جديد تطلب لقطة لأن الدور لا يُبَث', () async {
      final cubit = build();
      await cubit.enter();

      // اللقطة التالية تحمل المشهد الجديد بدوره — كما يفعل السيرفر.
      when(() => games.snapshot(any())).thenAnswer(
        (_) async => _snapshotJson(
          phase: 'role_reveal',
          roundOverrides: {
            'no': 2,
            'title': 'ضاع المفتاح',
            'myRole': _myRole(secret: 'إنت شفت المفتاح'),
          },
        ),
      );

      emit('scene_started', {
        'scene': 2,
        'totalScenes': 2,
        'title': 'ضاع المفتاح',
        'setup': 'الكل جاهز للخروج',
        'category': 'daily',
        'categoryLabel': 'مواقف يومية',
        'categoryEmoji': '🏠',
      });
      await settle();

      // الحبكة وصلت بالحدث؛ الدور والسرّ جاءا بطلب خاص.
      expect(cubit.state.round!.title, 'ضاع المفتاح');
      expect(cubit.state.round!.myRole!.secret, 'إنت شفت المفتاح');
      verify(() => games.snapshot(_gameId)).called(1);

      await cubit.close();
    });

    test('المتفرّج ما إله دور ولا بيقدر يحكي', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(isSpectator: true));

      final cubit = build();
      await cubit.enter();

      expect(cubit.state.round!.myRole, isNull);
      expect(cubit.canSay, isFalse);

      cubit.say('بدي احكي');
      verifyNever(() => mashhad.say(any(), any()));

      await cubit.close();
    });
  });

  group('المشهد والشات', () {
    test('الرسالة تنضاف للسجل باسم الشخصية', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.canSay, isTrue);

      cubit.say('المشكلة من القاطع');
      verify(() => mashhad.say(_gameId, 'المشكلة من القاطع')).called(1);

      emit('said', {
        'id': 'msg-1',
        'userId': _other,
        'username': 'other',
        'role': 'الابن',
        'text': 'لا، شفت الكهربا شغالة',
        'at': 1500,
      });
      await settle();

      final message = cubit.state.round!.transcript.single;

      expect(message.text, 'لا، شفت الكهربا شغالة');
      expect(message.role, 'الابن');

      await cubit.close();
    });

    test('ما بترسل رسالة فاضية ولا خارج المشهد', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'claims'));

      final cubit = build();
      await cubit.enter();

      expect(cubit.canSay, isFalse);

      cubit.say('متأخرة');
      verifyNever(() => mashhad.say(any(), any()));

      await cubit.close();
    });

    test('الحدث العام يوصل الجميع بنصّه', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <MashhadSignal>[];
      cubit.signals.listen(signals.add);

      emit('scene_event', {'text': '🚪 حدا عم يدق عالباب!', 'scope': 'all'});
      await settle();

      expect(cubit.state.round!.myEvents.single.text, '🚪 حدا عم يدق عالباب!');
      expect(cubit.state.round!.myEvents.single.isPrivate, isFalse);
      expect(signals.whereType<PublicEvent>().single.text, contains('الباب'));

      await cubit.close();
    });

    test('الحدث الخاص يصل صاحبه بنصّه وغيره باسمه فقط', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <MashhadSignal>[];
      cubit.signals.listen(signals.add);

      // وصل لاعب آخر: نعرف أنه وصله، لا ماذا كان.
      emit('private_event_sent', {'userId': _other});
      await settle();

      expect(signals.whereType<SomeoneGotSecret>().single.username, 'other');
      expect(cubit.state.round!.myEvents, isEmpty);

      // وصلني أنا: نطلب لقطة لنقرأ نصّه.
      emit('private_event_sent', {'userId': _me});
      await settle();

      expect(signals.whereType<PrivateEvent>(), hasLength(1));
      verify(() => games.snapshot(_gameId)).called(1);

      await cubit.close();
    });
  });

  group('الادّعاء', () {
    test('الادّعاء يُرسل مرة وحدة ويظهر فوراً', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'claims'));

      final cubit = build();
      await cubit.enter();

      expect(cubit.canClaim, isTrue);

      cubit.claim(main: true, bonus: true);

      expect(cubit.state.round!.myClaim!.main, isTrue);
      expect(cubit.canClaim, isFalse);

      cubit.claim(main: false);

      verify(
        () => mashhad.claim(_gameId, main: true, bonus: true, event: false),
      ).called(1);
      verifyNever(
        () => mashhad.claim(_gameId, main: false, bonus: false, event: false),
      );

      await cubit.close();
    });

    test('عدّاد الادّعاءات يتحدّث', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'claims'));

      final cubit = build();
      await cubit.enter();

      emit('claim_locked', {'claimed': 2, 'total': 3});
      await settle();

      expect(cubit.state.round!.claimedCount, 2);

      await cubit.close();
    });
  });

  group('الكشف والاعتراض', () {
    test('الكشف يجلب أدوار الجميع وأهدافهم', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'challenge'));

      final cubit = build();
      await cubit.enter();

      final signals = <MashhadSignal>[];
      cubit.signals.listen(signals.add);

      emit('claims_revealed', {
        'rows': [_claimRow(_me, 'me'), _claimRow(_other, 'other')],
      });
      await settle();

      expect(cubit.state.round!.rows, hasLength(2));
      expect(signals.whereType<ClaimsRevealed>(), hasLength(1));

      await cubit.close();
    });

    test('الاعتراض ينقص الرصيد ولا يتكرر ولا يطال النفس', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'challenge'));

      final cubit = build();
      await cubit.enter();

      expect(cubit.canChallenge, isTrue);

      cubit.challenge(targetUserId: _other, kind: 'main');

      expect(cubit.hasChallenged(_other, 'main'), isTrue);
      expect(cubit.state.round!.challengesLeft, 1);

      // نفس الخانة مرة ثانية: لا شيء.
      cubit.challenge(targetUserId: _other, kind: 'main');
      // على نفسي: لا شيء.
      cubit.challenge(targetUserId: _me, kind: 'main');

      verify(
        () => mashhad.challenge(_gameId, targetUserId: _other, kind: 'main'),
      ).called(1);
      verifyNever(
        () => mashhad.challenge(_gameId, targetUserId: _me, kind: 'main'),
      );

      await cubit.close();
    });

    test('ما بقدر اعترض إذا خلص رصيدي', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(phase: 'challenge', challengesLeft: 0),
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.canChallenge, isFalse);

      cubit.challenge(targetUserId: _other, kind: 'main');

      verifyNever(
        () => mashhad.challenge(
          any(),
          targetUserId: any(named: 'targetUserId'),
          kind: any(named: 'kind'),
        ),
      );

      await cubit.close();
    });
  });

  group('الحكم', () {
    test('طرف الاعتراض ما بيصوّت', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(
          phase: 'verdict',
          roundOverrides: {
            'challenge': {
              'challengeId': 'ch-1',
              'byUsername': 'other',
              'targetUserId': _me,
              'targetUsername': 'me',
              'kind': 'main',
              'roleName': 'الأب',
              'goal': 'شغّل الكهربا',
              'isParty': true,
              'hasVoted': false,
            },
          },
        ),
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.canVote, isFalse);

      cubit.vote(achieved: true);

      verifyNever(
        () => mashhad.vote(
          any(),
          challengeId: any(named: 'challengeId'),
          achieved: any(named: 'achieved'),
        ),
      );

      await cubit.close();
    });

    test('المحايد يصوّت مرة وحدة', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(
          phase: 'verdict',
          roundOverrides: {
            'challenge': {
              'challengeId': 'ch-1',
              'byUsername': 'other',
              'targetUserId': _third,
              'targetUsername': 'third',
              'kind': 'main',
              'roleName': 'الجار',
              'goal': 'خلّي الكل يعرف',
              'isParty': false,
              'hasVoted': false,
            },
          },
        ),
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.canVote, isTrue);

      cubit.vote(achieved: false);

      expect(cubit.canVote, isFalse);

      cubit.vote(achieved: true);

      verify(
        () => mashhad.vote(_gameId, challengeId: 'ch-1', achieved: false),
      ).called(1);

      await cubit.close();
    });

    test('نتيجة الحكم تصل كإشارة وتميّز إن كانت عنّي', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <MashhadSignal>[];
      cubit.signals.listen(signals.add);

      emit('verdict_result', {
        'challengeId': 'ch-1',
        'targetUserId': _me,
        'kind': 'main',
        'verdict': 'rejected',
      });
      await settle();

      final verdict = signals.whereType<VerdictDecided>().single;

      expect(verdict.aboutMe, isTrue);
      expect(verdict.claimStood, isFalse);

      await cubit.close();
    });
  });

  group('الجوائز والنهاية', () {
    test('صوت الجائزة مرة وحدة ولا يكون لنفسي', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(
          phase: 'awards',
          roundOverrides: {
            'awards': [
              {'key': 'chaos', 'emoji': '😂', 'label': 'أكثر واحد عمل فوضى'},
            ],
          },
        ),
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.awardCandidates.map((p) => p.id), isNot(contains(_me)));

      cubit.voteAward(awardKey: 'chaos', targetUserId: _me);
      verifyNever(
        () => mashhad.award(
          any(),
          awardKey: any(named: 'awardKey'),
          targetUserId: any(named: 'targetUserId'),
        ),
      );

      cubit.voteAward(awardKey: 'chaos', targetUserId: _other);
      cubit.voteAward(awardKey: 'chaos', targetUserId: _third);

      verify(
        () => mashhad.award(_gameId, awardKey: 'chaos', targetUserId: _other),
      ).called(1);
      verifyNever(
        () => mashhad.award(_gameId, awardKey: 'chaos', targetUserId: _third),
      );

      await cubit.close();
    });

    test('النتيجة تصل بالجوائز والترتيب', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <MashhadSignal>[];
      cubit.signals.listen(signals.add);

      emit('game_finished', {
        'result': {
          'winnerId': _me,
          'finalScores': [
            {
              'userId': _me,
              'username': 'me',
              'total': 75,
              'goalsAchieved': 2,
              'messageCount': 12,
              'awards': ['chaos'],
            },
            {
              'userId': _other,
              'username': 'other',
              'total': 40,
              'goalsAchieved': 1,
              'messageCount': 8,
            },
          ],
          'awards': [
            {
              'key': 'chaos',
              'emoji': '😂',
              'label': 'أكثر واحد عمل فوضى',
              'votes': 2,
              'winners': [
                {'userId': _me, 'username': 'me'},
              ],
            },
          ],
          'endedEarly': false,
          'scenesPlayed': 2,
        },
      });
      await settle();

      final result = cubit.state.snapshot!.result!;

      expect(cubit.state.snapshot!.isFinished, isTrue);
      expect(result.winner!.username, 'me');
      expect(result.awards.single.winners, ['me']);
      expect(signals.whereType<GameOver>().single.iWon, isTrue);

      await cubit.close();
    });
  });

  group('المتانة', () {
    test('إعادة الاتصال تجلب لقطة جديدة', () async {
      final cubit = build();
      await cubit.enter();

      reconnects.add(null);
      await settle();

      verify(() => games.snapshot(_gameId)).called(1);

      await cubit.close();
    });

    test('أحداث لعبة ثانية تُتجاهل', () async {
      final cubit = build();
      await cubit.enter();

      events.add(
        const RealtimeEvent(
          channel: 'game.other-game',
          name: 'said',
          data: {
            'id': 'x',
            'userId': _other,
            'username': 'other',
            'text': 'دخيلة',
            'at': 1,
          },
        ),
      );
      await settle();

      expect(cubit.state.round!.transcript, isEmpty);

      await cubit.close();
    });

    test('العدّاد يُصحَّح بفرق ساعة الجهاز عن السيرفر', () async {
      final cubit = build();
      await cubit.enter();

      emit('claim_locked', {
        'claimed': 1,
        'total': 3,
        'serverTime': DateTime.now().millisecondsSinceEpoch + 5000,
      });
      await settle();

      expect(cubit.state.clockSkewMs, greaterThan(4000));

      await cubit.close();
    });
  });
}
