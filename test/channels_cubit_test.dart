import 'dart:async';

import 'package:family_game_app/core/network/api_exception.dart';
import 'package:family_game_app/core/realtime/realtime_client.dart';
import 'package:family_game_app/features/channels/cubit/channels_cubit.dart';
import 'package:family_game_app/features/channels/data/channel_repository.dart';
import 'package:family_game_app/features/channels/model/channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ChannelRepository {}

class _MockRealtime extends Mock implements RealtimeClient {}

Channel _channel(String id, {String name = 'العيلة', ActiveGame? activeGame}) =>
    Channel(
      id: id,
      name: name,
      ownerId: 'owner',
      isOwner: false,
      inviteCode: 'ABC123',
      memberCount: 4,
      activeGame: activeGame,
    );

void main() {
  late _MockRepository repository;
  late _MockRealtime realtime;
  late StreamController<RealtimeEvent> events;

  ChannelsCubit build() => ChannelsCubit(repository, realtime);

  void emit(
    String channelId,
    String name, [
    Map<String, dynamic> data = const {},
  ]) => events.add(
    RealtimeEvent(channel: 'channel.$channelId', name: name, data: data),
  );

  /// انتظار دورة أحداث كافية لأن معالجة الحدث تُطلق طلباً غير منتظَر.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    repository = _MockRepository();
    realtime = _MockRealtime();
    events = StreamController<RealtimeEvent>.broadcast();

    when(() => realtime.events).thenAnswer((_) => events.stream);
    when(() => realtime.subscribe(any())).thenAnswer((_) async {});
    when(() => realtime.unsubscribe(any())).thenAnswer((_) async {});
    when(
      repository.myChannels,
    ).thenAnswer((_) async => [_channel('c1'), _channel('c2')]);
  });

  tearDown(() => events.close());

  test('يشترك في القناة الحيّة لكل قناة عند التحميل', () async {
    final cubit = build();
    await cubit.load();

    verify(() => realtime.subscribe('channel.c1')).called(1);
    verify(() => realtime.subscribe('channel.c2')).called(1);

    await cubit.close();
  });

  group('إزالة العضو', () {
    test('تختفي القناة فوراً من القائمة بلا سحب لتحديثها', () async {
      final cubit = build();
      await cubit.load();

      expect(cubit.state.channels, hasLength(2));

      // بعد الإزالة يرد السيرفر 403 على قناة لم نعد أعضاءها.
      when(
        () => repository.show('c1'),
      ).thenThrow(ApiException('لست عضواً في هذه القناة.', statusCode: 403));

      emit('c1', 'member_removed', {'userId': 'me'});
      await settle();

      expect(cubit.state.channels.map((c) => c.id), ['c2']);
      verify(() => realtime.unsubscribe('channel.c1')).called(1);

      await cubit.close();
    });

    test('القناة المحذوفة (404) تختفي كذلك', () async {
      final cubit = build();
      await cubit.load();

      when(
        () => repository.show('c2'),
      ).thenThrow(ApiException('غير موجودة', statusCode: 404));

      emit('c2', 'member_left');
      await settle();

      expect(cubit.state.channels.map((c) => c.id), ['c1']);

      await cubit.close();
    });

    test('إزالة عضو آخر تحدّث القناة ولا تشطبها', () async {
      final cubit = build();
      await cubit.load();

      when(
        () => repository.show('c1'),
      ).thenAnswer((_) async => _channel('c1', name: 'العيلة الكبيرة'));

      emit('c1', 'member_removed', {'userId': 'someone-else'});
      await settle();

      expect(cubit.state.channels, hasLength(2));
      expect(cubit.state.channels.first.name, 'العيلة الكبيرة');
      verifyNever(() => realtime.unsubscribe('channel.c1'));

      await cubit.close();
    });

    test('عطل شبكة عابر لا يشطب القناة', () async {
      final cubit = build();
      await cubit.load();

      when(
        () => repository.show('c1'),
      ).thenThrow(ApiException('ما في اتصال بالسيرفر.'));

      emit('c1', 'member_joined');
      await settle();

      expect(
        cubit.state.channels,
        hasLength(2),
        reason: 'انقطاع مؤقت ليس إزالة',
      );

      await cubit.close();
    });
  });

  group('بطاقة اللعبة الجارية', () {
    test('تظهر لحظة فتح أحدهم غرفة', () async {
      final cubit = build();
      await cubit.load();

      expect(cubit.state.channels.first.activeGame, isNull);

      emit('c1', 'active_game_changed', {
        'activeGame': {
          'id': 'g1',
          'gameType': 'harf',
          'status': 'lobby',
          'playerCount': 1,
        },
      });
      await settle();

      expect(cubit.state.channels.first.activeGame?.id, 'g1');
      expect(cubit.state.channels.first.activeGame?.isLobby, isTrue);

      await cubit.close();
    });

    test('تختفي عند انتهاء اللعبة', () async {
      when(repository.myChannels).thenAnswer(
        (_) async => [
          _channel(
            'c1',
            activeGame: const ActiveGame(
              id: 'g1',
              gameType: 'harf',
              status: 'playing',
            ),
          ),
        ],
      );

      final cubit = build();
      await cubit.load();

      emit('c1', 'active_game_changed', {'activeGame': null});
      await settle();

      expect(cubit.state.channels.first.activeGame, isNull);

      await cubit.close();
    });
  });
}
