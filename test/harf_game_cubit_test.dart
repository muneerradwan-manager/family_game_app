import 'dart:async';

import 'package:family_game_app/core/realtime/realtime_client.dart';
import 'package:family_game_app/features/games/data/game_repository.dart';
import 'package:family_game_app/features/games/harf/cubit/harf_game_cubit.dart';
import 'package:family_game_app/features/games/harf/cubit/harf_signal.dart';
import 'package:family_game_app/features/games/harf/data/harf_repository.dart';
import 'package:family_game_app/features/games/harf/model/harf_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGameRepository extends Mock implements GameRepository {}

class _MockHarfRepository extends Mock implements HarfRepository {}

class _MockRealtime extends Mock implements RealtimeClient {}

const _me = 'user-me';
const _other = 'user-other';
const _gameId = 'game-1';

Map<String, dynamic> _snapshotJson({
  String status = 'playing',
  String phase = 'writing',
  Map<String, dynamic>? roundOverrides,
}) => {
  'gameId': _gameId,
  'channelId': 'channel-1',
  'status': status,
  'hostId': _me,
  'config': {
    'columns': ['name', 'animal', 'food'],
    'columnLabels': {'name': 'اسم', 'animal': 'حيوان', 'food': 'طعام'},
    'roundsPerPlayer': 1,
    'writeSeconds': 90,
    'flexibleMode': true,
  },
  'players': [
    {'id': _me, 'username': 'me', 'isSpectator': false, 'total': 0},
    {'id': _other, 'username': 'other', 'isSpectator': false, 'total': 0},
  ],
  'order': [_me, _other],
  'currentRound': 1,
  'totalRounds': 2,
  'standings': const [],
  'estimatedSeconds': 300,
  'canStart': true,
  'me': {
    'isPlayer': true,
    'isSpectator': false,
    'isHost': true,
    'canEndEarly': false,
    'total': 0,
  },
  'round': {
    'no': 1,
    'phase': phase,
    'phaseStartedAt': 1000,
    'deadline': 91000,
    'drawerUserId': _me,
    'letter': 'ب',
    'myAnswers': const <String, String>{},
    'myObjectionsLeft': 3,
    'rows': const [],
    ...?roundOverrides,
  },
};

void main() {
  late _MockGameRepository games;
  late _MockHarfRepository harf;
  late _MockRealtime realtime;
  late StreamController<RealtimeEvent> events;
  late StreamController<RealtimeStatus> status;
  late StreamController<void> reconnects;

  HarfGameCubit build() => HarfGameCubit(
    games: games,
    harf: harf,
    realtime: realtime,
    gameId: _gameId,
    viewerId: _me,
  );

  void emit(String name, Map<String, dynamic> data) => events.add(
    RealtimeEvent(channel: 'game.$_gameId', name: name, data: data),
  );

  setUp(() {
    games = _MockGameRepository();
    harf = _MockHarfRepository();
    realtime = _MockRealtime();
    events = StreamController<RealtimeEvent>.broadcast();
    status = StreamController<RealtimeStatus>.broadcast();
    reconnects = StreamController<void>.broadcast();

    when(() => realtime.events).thenAnswer((_) => events.stream);
    when(() => realtime.status).thenAnswer((_) => status.stream);
    when(() => realtime.reconnected).thenAnswer((_) => reconnects.stream);
    when(() => realtime.subscribe(any())).thenAnswer((_) async {});
    when(() => realtime.unsubscribe(any())).thenAnswer((_) async {});

    // المستودع صار محايداً عن الألعاب: يعيد الخريطة الخام والوحدة تقرؤها.
    when(() => games.join(any())).thenAnswer((_) async => _snapshotJson());
    when(() => games.snapshot(any())).thenAnswer((_) async => _snapshotJson());
  });

  tearDown(() async {
    await events.close();
    await status.close();
    await reconnects.close();
  });

  group('الدخول للجلسة', () {
    test('يشترك في غرفة اللعبة ويحمّل اللقطة', () async {
      final cubit = build();
      await cubit.enter();

      verify(() => realtime.subscribe('game.$_gameId')).called(1);
      expect(cubit.state.snapshot?.gameId, _gameId);
      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });
  });

  group('قاعدة الستوب', () {
    test('الزر مقفول حتى تمتلئ كل الخانات', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.canPressStop, isFalse);

      cubit.setAnswer('name', 'باسم');
      cubit.setAnswer('animal', 'بطة');
      expect(cubit.canPressStop, isFalse, reason: 'ما زالت خانة فارغة');

      cubit.setAnswer('food', 'بندورة');
      expect(cubit.canPressStop, isTrue);

      await cubit.close();
    });

    test('مسافات بيضاء لا تُحتسب خانة ممتلئة', () async {
      final cubit = build();
      await cubit.enter();

      cubit.setAnswer('name', 'باسم');
      cubit.setAnswer('animal', '   ');
      cubit.setAnswer('food', 'بندورة');

      expect(cubit.canPressStop, isFalse);

      await cubit.close();
    });

    test('الزر مقفول بعد أن يضغط غيرك ستوب', () async {
      final cubit = build();
      await cubit.enter();

      for (final column in ['name', 'animal', 'food']) {
        cubit.setAnswer(column, 'ب$column');
      }
      expect(cubit.canPressStop, isTrue);

      emit('stop_pressed', {'byUserId': _other, 'byUsername': 'other'});
      await Future<void>.delayed(Duration.zero);

      expect(cubit.canPressStop, isFalse);

      await cubit.close();
    });
  });

  group('أحداث القناة الحيّة', () {
    test('phase_changed ينقل المرحلة والموعد النهائي', () async {
      final cubit = build();
      await cubit.enter();

      emit('phase_changed', {
        'round': 1,
        'totalRounds': 2,
        'phase': 'objection',
        'phaseStartedAt': 5000,
        'deadline': 25000,
        'drawerUserId': _me,
        'letter': 'ب',
      });
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, HarfPhase.objection);
      expect(cubit.state.round?.deadline, 25000);

      await cubit.close();
    });

    test('answers_revealed يكشف إجابات الجميع', () async {
      final cubit = build();
      await cubit.enter();

      expect(cubit.state.round?.rows, isEmpty);

      emit('answers_revealed', {
        'letter': 'ب',
        'stopBy': _other,
        'rows': [
          {
            'userId': _me,
            'username': 'me',
            'answers': {'name': 'باسم'},
          },
          {
            'userId': _other,
            'username': 'other',
            'answers': {'name': 'بشار'},
          },
        ],
      });
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.round?.rows, hasLength(2));
      expect(cubit.state.round?.stopBy, _other);

      await cubit.close();
    });

    test('game_finished يخزّن النتيجة ويطلق إشارة النهاية', () async {
      final cubit = build();
      await cubit.enter();

      final signal = expectLater(cubit.signals, emits(isA<GameOver>()));

      emit('game_finished', {
        'result': {
          'winnerId': _other,
          'finalScores': [
            {'userId': _other, 'username': 'other', 'total': 40},
            {'userId': _me, 'username': 'me', 'total': 25},
          ],
          'endedEarly': false,
          'decidedByTiebreak': false,
          'roundsPlayed': 2,
        },
      });
      await signal;

      expect(cubit.state.snapshot?.isFinished, isTrue);
      expect(cubit.state.snapshot?.result?.winner?.username, 'other');

      await cubit.close();
    });

    test('يتجاهل أحداث جلسة أخرى', () async {
      final cubit = build();
      await cubit.enter();

      events.add(
        const RealtimeEvent(
          channel: 'game.some-other-game',
          name: 'phase_changed',
          data: {'phase': 'voting'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, HarfPhase.writing);

      await cubit.close();
    });

    test('إعادة الاتصال تجلب لقطة جديدة لأن ما فات لا يُبَث ثانية', () async {
      final cubit = build();
      await cubit.enter();

      reconnects.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => games.snapshot(_gameId)).called(1);

      await cubit.close();
    });
  });

  group('تصحيح فرق الساعة', () {
    test('يضبط العدّاد على ساعة السيرفر لا ساعة الجهاز', () async {
      final cubit = build();
      await cubit.enter();

      // جهاز متأخر عشر ثوانٍ عن السيرفر.
      final serverTime = DateTime.now().millisecondsSinceEpoch + 10000;
      emit('phase_changed', {
        'round': 1,
        'phase': 'writing',
        'phaseStartedAt': serverTime,
        'deadline': serverTime + 30000,
        'drawerUserId': _me,
        'serverTime': serverTime,
      });
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.clockSkewMs, closeTo(10000, 400));

      final remaining = cubit.state.remainingMs(cubit.state.round!.deadline);
      expect(
        remaining,
        closeTo(30000, 600),
        reason: 'المتبقي 30 ثانية رغم انحراف الساعة',
      );

      await cubit.close();
    });
  });

  group('الاعتراض والتصويت', () {
    test('لا يعترض اللاعب على نفس الخانة مرتين', () async {
      final cubit = build();
      await cubit.enter();

      cubit.raiseObjection(targetUserId: _other, column: 'name');
      cubit.raiseObjection(targetUserId: _other, column: 'name');

      verify(
        () =>
            harf.raiseObjection(_gameId, targetUserId: _other, column: 'name'),
      ).called(1);
      expect(cubit.hasObjectedTo(_other, 'name'), isTrue);

      await cubit.close();
    });

    test('طرف الاعتراض لا يصوّت', () async {
      when(() => games.join(any())).thenAnswer(
        (_) async => _snapshotJson(
          phase: 'voting',
          roundOverrides: {
            'objection': {
              'objectionId': 'obj-1',
              'byUsername': 'me',
              'targetUserId': _other,
              'targetUsername': 'other',
              'column': 'name',
              'columnLabel': 'اسم',
              'answer': 'بشار',
              'parties': [_me, _other],
            },
          },
        ),
      );

      final cubit = build();
      await cubit.enter();

      expect(cubit.state.round?.objection?.isParty, isTrue);

      cubit.castVote(answerIsValid: false);

      verifyNever(
        () => harf.castVote(
          any(),
          objectionId: any(named: 'objectionId'),
          isValid: any(named: 'isValid'),
        ),
      );

      await cubit.close();
    });
  });
}
