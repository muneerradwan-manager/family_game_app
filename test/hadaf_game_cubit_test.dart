import 'dart:async';

import 'package:family_game_app/core/realtime/realtime_client.dart';
import 'package:family_game_app/features/games/data/game_repository.dart';
import 'package:family_game_app/features/games/hadaf/cubit/hadaf_game_cubit.dart';
import 'package:family_game_app/features/games/hadaf/cubit/hadaf_signal.dart';
import 'package:family_game_app/features/games/hadaf/data/hadaf_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGameRepository extends Mock implements GameRepository {}

class _MockHadafRepository extends Mock implements HadafRepository {}

class _MockRealtime extends Mock implements RealtimeClient {}

const _me = 'user-me';
const _other = 'user-other';
const _gameId = 'game-1';

Map<String, dynamic> _question({bool teaser = false}) => teaser
    ? {
        'category': 'math',
        'categoryLabel': 'رياضيات',
        'categoryEmoji': '🔢',
        'difficulty': 'easy',
      }
    : {
        'category': 'math',
        'categoryLabel': 'رياضيات',
        'categoryEmoji': '🔢',
        'difficulty': 'easy',
        'prompt': '2 · 4 · 8 · 16 · ؟',
        'choices': ['24', '32', '30', '64'],
      };

Map<String, dynamic> _snapshotJson({
  String status = 'playing',
  String phase = 'question',
  int risksLeft = 3,
  int? myChoice,
  bool isSpectator = false,
  Map<String, dynamic>? roundOverrides,
}) => {
  'gameId': _gameId,
  'channelId': 'channel-1',
  'status': status,
  'hostId': _me,
  'config': {
    'category': 'math',
    'categoryLabel': 'رياضيات',
    'rounds': 8,
    'questionSeconds': 20,
    'flexibleMode': false,
    'risksPerGame': 3,
  },
  'players': [
    {'id': _me, 'username': 'me', 'isSpectator': false},
    {'id': _other, 'username': 'other', 'isSpectator': false},
  ],
  'currentRound': 1,
  'totalRounds': 8,
  'standings': const <Map<String, dynamic>>[],
  'estimatedSeconds': 300,
  'canStart': true,
  'me': {
    'isPlayer': !isSpectator,
    'isSpectator': isSpectator,
    'isHost': true,
    'canEndEarly': false,
    'total': 0,
    'streak': 0,
    'risksLeft': risksLeft,
    'correctCount': 0,
  },
  'round': {
    'no': 1,
    'phase': phase,
    'phaseStartedAt': 1000,
    'deadline': 21000,
    'question': phase == 'ready' ? _question(teaser: true) : _question(),
    'answeredCount': 0,
    'activeCount': 2,
    'myChoice': myChoice,
    'myRisk': false,
    'myCorrect': null,
    'answerIndex': null,
    'rows': const <Map<String, dynamic>>[],
    ...?roundOverrides,
  },
};

void main() {
  late _MockGameRepository games;
  late _MockHadafRepository hadaf;
  late _MockRealtime realtime;
  late StreamController<RealtimeEvent> events;
  late StreamController<RealtimeStatus> status;
  late StreamController<void> reconnects;

  HadafGameCubit build() => HadafGameCubit(
    games: games,
    hadaf: hadaf,
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
    hadaf = _MockHadafRepository();
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

  group('سرّية الجواب', () {
    test('مرحلة الاستعداد ما فيها نصّ سؤال ولا خيارات', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'ready'));

      final cubit = build();
      await cubit.enter();

      final question = cubit.state.round!.question!;

      expect(question.isTeaser, isTrue);
      expect(question.prompt, isNull);
      expect(question.choices, isEmpty);
      // المجموعة والصعوبة تُعلَنان — تشويق بلا تسريب.
      expect(question.categoryLabel, 'رياضيات');

      await cubit.close();
    });

    test('موقع الجواب لا يصل قبل الكشف', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.state.round!.answerIndex, isNull);
      expect(cubit.state.round!.myCorrect, isNull);

      await cubit.close();
    });

    test('الكشف يجلب الجواب ونتيجتي', () async {
      final cubit = build();
      await cubit.enter();

      emit('question_closed', {
        'round': 1,
        'answerIndex': 3,
        'answer': '64',
        'rows': [
          {
            'userId': _me,
            'username': 'me',
            'correct': true,
            'usedRisk': false,
            'rank': 1,
            'points': 20,
            'streak': 1,
            'choice': 3,
          },
        ],
        'standings': const <Map<String, dynamic>>[],
      });
      await settle();

      expect(cubit.state.round!.answerIndex, 3);
      expect(cubit.state.round!.myCorrect, isTrue);

      await cubit.close();
    });
  });

  group('السباق', () {
    test('الإجابة تُرسل مرة وحدة ولا تُبدَّل', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.canAnswer, isTrue);

      cubit.answer(2);

      expect(cubit.state.round!.myChoice, 2);
      expect(cubit.canAnswer, isFalse);

      cubit.answer(0);

      verify(() => hadaf.answer(_gameId, choice: 2, risk: false)).called(1);
      verifyNever(() => hadaf.answer(_gameId, choice: 0, risk: false));

      await cubit.close();
    });

    test('عدّاد من أجاب يتحدّث بلا ما يكشف مين أصاب', () async {
      final cubit = build();
      await cubit.enter();

      emit('answer_locked', {
        'answered': 2,
        'total': 3,
        'userId': _other,
        'usedRisk': false,
      });
      await settle();

      expect(cubit.state.round!.answeredCount, 2);
      expect(cubit.state.round!.activeCount, 3);
      // لا شيء في الحمولة يقول إن الآخر أصاب.
      expect(cubit.state.round!.answerIndex, isNull);

      await cubit.close();
    });

    test('المتفرّج ما بيقدر يجاوب', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(isSpectator: true));

      final cubit = build();
      await cubit.enter();

      expect(cubit.amRacing, isFalse);
      expect(cubit.canAnswer, isFalse);

      cubit.answer(1);

      verifyNever(
        () => hadaf.answer(
          any(),
          choice: any(named: 'choice'),
          risk: any(named: 'risk'),
        ),
      );

      await cubit.close();
    });

    test('ما في إجابة قبل ما يُفتح السؤال', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'ready'));

      final cubit = build();
      await cubit.enter();

      expect(cubit.canAnswer, isFalse);

      cubit.answer(1);

      verifyNever(
        () => hadaf.answer(
          any(),
          choice: any(named: 'choice'),
          risk: any(named: 'risk'),
        ),
      );

      await cubit.close();
    });
  });

  group('⚡ المخاطرة', () {
    test('تُفعَّل قبل الاختيار وتُرسل مع الإجابة وتنقص الرصيد', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.canArmRisk, isTrue);

      cubit.toggleRisk();
      expect(cubit.state.riskArmed, isTrue);

      cubit.answer(1);

      verify(() => hadaf.answer(_gameId, choice: 1, risk: true)).called(1);
      expect(cubit.state.riskArmed, isFalse);
      expect(cubit.state.snapshot!.me.risksLeft, 2);
      expect(cubit.state.round!.myRisk, isTrue);

      await cubit.close();
    });

    test('ما بتنفعّل إذا خلص الرصيد', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(risksLeft: 0));

      final cubit = build();
      await cubit.enter();

      expect(cubit.canArmRisk, isFalse);

      cubit.toggleRisk();

      expect(cubit.state.riskArmed, isFalse);

      cubit.answer(1);
      verify(() => hadaf.answer(_gameId, choice: 1, risk: false)).called(1);

      await cubit.close();
    });
  });

  group('السلسلة والإشارات', () {
    test('السلسلة الثالثة تطلق إشارتها', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <HadafSignal>[];
      cubit.signals.listen(signals.add);

      emit('question_closed', {
        'round': 1,
        'answerIndex': 0,
        'rows': [
          {
            'userId': _me,
            'username': 'me',
            'correct': true,
            'usedRisk': false,
            'rank': 1,
            'points': 25,
            'streak': 3,
            'choice': 0,
          },
        ],
        'standings': const <Map<String, dynamic>>[],
      });
      await settle();

      final revealed = signals.whereType<AnswerRevealed>().first;

      expect(revealed.iWasCorrect, isTrue);
      expect(revealed.rank, 1);
      expect(revealed.points, 25);
      expect(signals.whereType<StreakHit>().single.streak, 3);
      expect(cubit.state.snapshot!.me.streak, 3);

      await cubit.close();
    });

    test('فتح السؤال يطلق إشارة الانطلاق', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'ready'));

      final cubit = build();
      await cubit.enter();

      final signals = <HadafSignal>[];
      cubit.signals.listen(signals.add);

      emit('question_opened', {'round': 1, 'question': _question()});
      await settle();

      expect(signals.whereType<QuestionOpened>(), hasLength(1));
      expect(cubit.state.round!.question!.prompt, '2 · 4 · 8 · 16 · ؟');
      expect(cubit.state.round!.question!.choices, hasLength(4));

      await cubit.close();
    });
  });

  group('جولة الحسم', () {
    test('المتعادلون وحدهم يتسابقون', () async {
      when(
        () => games.join(any()),
      ).thenAnswer((_) async => _snapshotJson(phase: 'tiebreak'));

      final cubit = build();
      await cubit.enter();

      final signals = <HadafSignal>[];
      cubit.signals.listen(signals.add);

      // تعادل لا يشملني: أتفرّج ولا أجيب.
      emit('tiebreak_started', {
        'tiedPlayers': [_other],
      });
      await settle();

      expect(signals.whereType<TiebreakStarted>().single.amTied, isFalse);
      expect(cubit.amRacing, isFalse);

      cubit.answer(0);
      verifyNever(
        () => hadaf.answer(
          any(),
          choice: any(named: 'choice'),
          risk: any(named: 'risk'),
        ),
      );

      // ثم تعادل يشملني.
      emit('tiebreak_started', {
        'tiedPlayers': [_me, _other],
      });
      await settle();

      expect(cubit.amRacing, isTrue);
      expect(cubit.canAnswer, isTrue);

      await cubit.close();
    });
  });

  group('النهاية والمتانة', () {
    test('النتيجة تصل وتعلن الفائز', () async {
      final cubit = build();
      await cubit.enter();

      final signals = <HadafSignal>[];
      cubit.signals.listen(signals.add);

      emit('game_finished', {
        'result': {
          'winnerId': _me,
          'finalScores': [
            {'userId': _me, 'username': 'me', 'total': 62, 'correctCount': 4},
            {
              'userId': _other,
              'username': 'other',
              'total': 30,
              'correctCount': 2,
            },
          ],
          'endedEarly': false,
          'decidedByTiebreak': false,
          'roundsPlayed': 8,
        },
      });
      await settle();

      expect(cubit.state.snapshot!.isFinished, isTrue);
      expect(cubit.state.snapshot!.result!.winner!.username, 'me');
      expect(signals.whereType<GameOver>().single.iWon, isTrue);

      await cubit.close();
    });

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
          name: 'answer_locked',
          data: {'answered': 9, 'total': 9},
        ),
      );
      await settle();

      expect(cubit.state.round!.answeredCount, 0);

      await cubit.close();
    });

    test('العدّاد يُصحَّح بفرق ساعة الجهاز عن السيرفر', () async {
      final cubit = build();
      await cubit.enter();

      emit('answer_locked', {
        'answered': 1,
        'total': 2,
        'serverTime': DateTime.now().millisecondsSinceEpoch + 5000,
      });
      await settle();

      expect(cubit.state.clockSkewMs, greaterThan(4000));

      await cubit.close();
    });
  });
}
