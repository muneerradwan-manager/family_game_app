import 'dart:async';

import 'package:family_game_app/core/realtime/realtime_client.dart';
import 'package:family_game_app/features/games/data/game_repository.dart';
import 'package:family_game_app/features/games/spy/cubit/spy_game_cubit.dart';
import 'package:family_game_app/features/games/spy/cubit/spy_signal.dart';
import 'package:family_game_app/features/games/spy/data/spy_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGameRepository extends Mock implements GameRepository {}

class _MockSpyRepository extends Mock implements SpyRepository {}

class _MockRealtime extends Mock implements RealtimeClient {}

const _me = 'user-me';
const _other = 'user-other';
const _third = 'user-third';
const _gameId = 'game-1';

Map<String, dynamic> _player(String id, String name, {int? outAtRound}) => {
  'id': id,
  'username': name,
  'isSpectator': false,
  'leftAtRound': null,
  'outAtRound': outAtRound,
};

Map<String, dynamic> _snapshotJson({
  String status = 'playing',
  String phase = 'asking',
  bool isSpy = false,
  String? word = 'فيل',
  bool isOut = false,
  Map<String, dynamic>? roundOverrides,
  List<Map<String, dynamic>>? players,
  List<Map<String, dynamic>>? transcript,
}) => {
  'gameId': _gameId,
  'channelId': 'channel-1',
  'status': status,
  'hostId': _me,
  'config': {
    'category': 'animals',
    'turnSeconds': 45,
    'maxRounds': 4,
    'lastGuess': true,
  },
  'players':
      players ??
      [_player(_me, 'me'), _player(_other, 'other'), _player(_third, 'third')],
  'currentRound': 1,
  'maxRounds': 4,
  'categoryLabel': 'حيوانات',
  'categoryEmoji': '🐾',
  'transcript': transcript ?? const <Map<String, dynamic>>[],
  'ejections': const <Map<String, dynamic>>[],
  'estimatedSeconds': 480,
  'canStart': true,
  'me': {
    'isPlayer': true,
    'isSpectator': false,
    'isHost': true,
    'canEndEarly': false,
    'isSpy': isSpy,
    'isOut': isOut,
    'word': isSpy ? null : word,
  },
  'round': {
    'no': 1,
    'phase': phase,
    'phaseStartedAt': 1000,
    'deadline': 46000,
    'currentAskerId': _me,
    'currentAskerUsername': 'me',
    'askQueue': [_other, _third],
    'votedCount': 0,
    'eligibleCount': 3,
    ...?roundOverrides,
  },
};

Map<String, dynamic> _turnJson({
  String id = 'turn-1',
  String askerId = _other,
  String targetId = _me,
  String question = 'بتلاقيه بحديقة حيوان؟',
  String? answer,
}) => {
  'id': id,
  'round': 1,
  'askerId': askerId,
  'askerUsername': askerId == _me ? 'me' : 'other',
  'targetId': targetId,
  'targetUsername': targetId == _me ? 'me' : 'other',
  'question': question,
  'answer': answer,
  'skipped': false,
  'unanswered': false,
};

void main() {
  late _MockGameRepository games;
  late _MockSpyRepository spy;
  late _MockRealtime realtime;
  late StreamController<RealtimeEvent> events;
  late StreamController<RealtimeStatus> status;
  late StreamController<void> reconnects;

  SpyGameCubit build() => SpyGameCubit(
    games: games,
    spy: spy,
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
    spy = _MockSpyRepository();
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

  group('السرّ', () {
    test('اللاعب العادي يشوف الكلمة ولا يعرف إنه جاسوس', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.state.snapshot!.me.word, 'فيل');
      expect(cubit.state.snapshot!.me.isSpy, isFalse);

      await cubit.close();
    });

    test('الجاسوس ما بيشوف الكلمة', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(isSpy: true));

      final cubit = build();
      await cubit.enter();

      expect(cubit.state.snapshot!.me.isSpy, isTrue);
      expect(cubit.state.snapshot!.me.word, isNull);
      // المجموعة معروفة للجميع — ومنها يبني الجاسوس تمثيله.
      expect(cubit.state.snapshot!.categoryLabel, 'حيوانات');

      await cubit.close();
    });

    test('بداية اللعبة تطلب لقطة جديدة لأن الدور السرّي لا يُبَث', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(status: 'lobby'));

      final cubit = build();
      await cubit.enter();

      emit('game_started', {
        'config': {
          'category': 'animals',
          'turnSeconds': 45,
          'maxRounds': 4,
          'lastGuess': true,
        },
        'categoryLabel': 'حيوانات',
        'categoryEmoji': '🐾',
        'players': const <Map<String, dynamic>>[],
      });

      await settle();

      // هذا هو جوهر اللعبة: الكلمة تصل بطلب خاص لا عبر القناة.
      verify(() => games.snapshot(_gameId)).called(1);
      expect(cubit.state.snapshot!.categoryLabel, 'حيوانات');

      await cubit.close();
    });
  });

  group('دورة السؤال والجواب', () {
    test('دوري أسأل حين يصلني turn_started باسمي', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(roundOverrides: {'currentAskerId': _other}),
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.canAsk, isFalse);

      final signals = <SpySignal>[];
      cubit.signals.listen(signals.add);

      emit('turn_started', {
        'askerId': _me,
        'askerUsername': 'me',
        'remaining': 2,
      });
      await settle();

      expect(cubit.canAsk, isTrue);
      expect(signals.whereType<MyTurnToAsk>(), hasLength(1));

      await cubit.close();
    });

    test('ما بقدر أسأل حالي ولا أسأل بلا ما أختار حدا', () async {
      final cubit = build();
      await cubit.enter();

      // بلا اختيار هدف: لا يُرسل شيء.
      cubit.askQuestion('سؤالي');
      verifyNever(
        () => spy.ask(
          any(),
          targetUserId: any(named: 'targetUserId'),
          question: any(named: 'question'),
        ),
      );

      cubit.selectTarget(_other);
      cubit.askQuestion('بتلاقيه بحديقة حيوان؟');

      verify(
        () => spy.ask(
          _gameId,
          targetUserId: _other,
          question: 'بتلاقيه بحديقة حيوان؟',
        ),
      ).called(1);

      // ولا يسأل أحد نفسه: الهدف لا يظهر أصلاً في القائمة المعروضة.
      expect(cubit.askableTargets.map((p) => p.id), isNot(contains(_me)));

      await cubit.close();
    });

    test('السؤال الموجّه لي يفتح لي الجواب ويصلني كإشارة', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'answering'));

      final cubit = build();
      await cubit.enter();

      final signals = <SpySignal>[];
      cubit.signals.listen(signals.add);

      emit('question_asked', _turnJson());
      await settle();

      expect(cubit.canAnswer, isTrue);
      expect(cubit.state.snapshot!.transcript, hasLength(1));
      expect(signals.whereType<QuestionForMe>(), hasLength(1));

      cubit.answerQuestion('أكيد، وبيجذب الناس');
      verify(() => spy.answer(_gameId, 'أكيد، وبيجذب الناس')).called(1);

      await cubit.close();
    });

    test('الجواب يلحق بسؤاله في السجل', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(transcript: [_turnJson()]));

      final cubit = build();
      await cubit.enter();

      emit('answer_given', {
        'turnId': 'turn-1',
        'answer': 'أكيد',
        'unanswered': false,
      });
      await settle();

      expect(cubit.state.snapshot!.transcript.first.answer, 'أكيد');

      await cubit.close();
    });

    test('الصمت يبقى في السجل ظاهراً لا يُمحى', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(transcript: [_turnJson()]));

      final cubit = build();
      await cubit.enter();

      emit('answer_given', {
        'turnId': 'turn-1',
        'answer': null,
        'unanswered': true,
      });
      await settle();

      final turn = cubit.state.snapshot!.transcript.first;

      expect(turn.unanswered, isTrue);
      expect(turn.answer, isNull);

      await cubit.close();
    });

    test('سحب الدور يُسجَّل في السجل', () async {
      final cubit = build();
      await cubit.enter();

      emit('turn_skipped', {'askerId': _other, 'askerUsername': 'other'});
      await settle();

      expect(cubit.state.snapshot!.transcript.first.skipped, isTrue);

      await cubit.close();
    });
  });

  group('التصويت', () {
    test('التصويت يظهر فوراً ولا يتكرر', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'voting'));

      final cubit = build();
      await cubit.enter();

      expect(cubit.canVote, isTrue);

      cubit.vote(_other);

      expect(cubit.state.round!.myVote, _other);
      expect(cubit.canVote, isFalse);

      // ضغطة ثانية لا تُرسل صوتاً ثانياً.
      cubit.vote(_third);

      verify(() => spy.vote(_gameId, _other)).called(1);
      verifyNever(() => spy.vote(_gameId, _third));

      await cubit.close();
    });

    test('ما بصوّت على حالي', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'voting'));

      final cubit = build();
      await cubit.enter();

      cubit.vote(_me);

      verifyNever(() => spy.vote(any(), any()));
      expect(cubit.state.round!.myVote, isNull);
      expect(cubit.suspects.map((p) => p.id), isNot(contains(_me)));

      await cubit.close();
    });

    test('عدّاد التصويت يتحدّث بلا ما يكشف مين صوّت لمين', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'voting'));

      final cubit = build();
      await cubit.enter();

      emit('vote_cast', {'voted': 2, 'eligible': 3});
      await settle();

      expect(cubit.state.round!.votedCount, 2);
      expect(cubit.state.round!.eligibleCount, 3);

      await cubit.close();
    });

    test('من طلع بالتصويت بيوقف يلعب', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'voting'));

      final cubit = build();
      await cubit.enter();

      final signals = <SpySignal>[];
      cubit.signals.listen(signals.add);

      emit('vote_result', {
        'tie': false,
        'ejectedUserId': _me,
        'ejectedUsername': 'me',
        'wasSpy': false,
        'counts': [
          {'userId': _me, 'username': 'me', 'votes': 2},
          {'userId': _other, 'username': 'other', 'votes': 0},
        ],
      });
      await settle();

      expect(cubit.state.snapshot!.me.isOut, isTrue);
      expect(cubit.amActive, isFalse);
      expect(cubit.state.snapshot!.playerById(_me)!.isOut, isTrue);
      expect(signals.whereType<VoteRevealed>().first.caughtSpy, isFalse);

      await cubit.close();
    });

    test('التعادل يوصل كنتيجة بلا مطرود', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'voting'));

      final cubit = build();
      await cubit.enter();

      emit('vote_result', {
        'tie': true,
        'ejectedUserId': null,
        'wasSpy': false,
        'counts': const <Map<String, dynamic>>[],
      });
      await settle();

      expect(cubit.state.round!.voteResult!.tie, isTrue);
      expect(cubit.state.snapshot!.me.isOut, isFalse);

      await cubit.close();
    });
  });

  group('فرصة الجاسوس الأخيرة', () {
    test('الخيارات تظهر للجميع والتخمين للجاسوس وحده', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'spy_guess'));

      final cubit = build();
      await cubit.enter();

      emit('spy_guess_started', {
        'spyUserId': _other,
        'spyUsername': 'other',
        'options': ['فيل', 'أسد', 'نمر'],
      });
      await settle();

      expect(cubit.state.round!.guessOptions, hasLength(3));
      expect(cubit.state.round!.spyUsername, 'other');

      // أنا لست الجاسوس: ضغطي على خيار لا يرسل شيئاً.
      cubit.submitGuess('فيل');
      verifyNever(() => spy.guess(any(), any()));

      await cubit.close();
    });

    test('الجاسوس بيقدر يخمّن', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'spy_guess', isSpy: true));

      final cubit = build();
      await cubit.enter();

      cubit.submitGuess('فيل');

      verify(() => spy.guess(_gameId, 'فيل')).called(1);

      await cubit.close();
    });
  });

  group('النهاية', () {
    test('النتيجة تكشف الكلمة والجاسوس', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <SpySignal>[];
      cubit.signals.listen(signals.add);

      emit('game_finished', {
        'result': {
          'winner': 'players',
          'reason': 'spy_caught',
          'headline': 'انكشف الجاسوس — other!',
          'word': 'فيل',
          'categoryLabel': 'حيوانات',
          'spyUserId': _other,
          'spyUsername': 'other',
          'roundsPlayed': 2,
          'players': [
            {'userId': _me, 'username': 'me', 'wasSpy': false, 'won': true},
            {
              'userId': _other,
              'username': 'other',
              'wasSpy': true,
              'won': false,
            },
          ],
          'ejections': const <Map<String, dynamic>>[],
        },
      });
      await settle();

      final result = cubit.state.snapshot!.result!;

      expect(cubit.state.snapshot!.isFinished, isTrue);
      expect(result.word, 'فيل');
      expect(result.spyUsername, 'other');
      expect(result.playersWon, isTrue);
      expect(signals.whereType<GameOver>().first.iWon, isTrue);

      await cubit.close();
    });
  });

  group('المتانة', () {
    test('إعادة الاتصال تجلب لقطة جديدة لأن ما فات لا يُبَث ثانية', () async {
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
          name: 'turn_skipped',
          data: {'askerId': _other, 'askerUsername': 'other'},
        ),
      );
      await settle();

      expect(cubit.state.snapshot!.transcript, isEmpty);

      await cubit.close();
    });

    test('المتفرّج ما بيقدر يسأل ولا يصوّت', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => {
          ..._snapshotJson(phase: 'voting'),
          'me': {
            'isPlayer': false,
            'isSpectator': true,
            'isHost': false,
            'canEndEarly': false,
            'isSpy': false,
            'isOut': false,
            'word': null,
          },
        },
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.amActive, isFalse);
      expect(cubit.canVote, isFalse);
      expect(cubit.canAsk, isFalse);

      cubit.vote(_other);
      verifyNever(() => spy.vote(any(), any()));

      await cubit.close();
    });
  });

  group('تصحيح فرق الساعة', () {
    test('العدّاد يُصحَّح بفرق ساعة الجهاز عن السيرفر', () async {
      final cubit = build();
      await cubit.enter();

      final ahead = DateTime.now().millisecondsSinceEpoch + 5000;

      // ختم السيرفر يرافق كل حدث داخل حمولته.
      emit('vote_cast', {'voted': 1, 'eligible': 3, 'serverTime': ahead});
      await settle();

      expect(cubit.state.clockSkewMs, greaterThan(4000));

      await cubit.close();
    });
  });
}
