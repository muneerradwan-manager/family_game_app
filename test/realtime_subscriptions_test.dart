import 'package:family_game_app/core/realtime/realtime_client.dart';
import 'package:family_game_app/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late RealtimeClient realtime;

  setUp(() {
    final storage = _MockStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);

    // بلا اتصال: نختبر دفاتر الاشتراك لا السوكت نفسه.
    realtime = RealtimeClient(TokenStore(storage));
  });

  group('عدّ المستمعين على القناة الحيّة', () {
    test('شاشتان على نفس القناة، وإغلاق واحدة لا يُسكت الأخرى', () async {
      // قائمة القنوات تشترك، ثم يفتح المستخدم شاشة القناة فتشترك كذلك.
      await realtime.subscribe('channel.c1');
      await realtime.subscribe('channel.c1');

      expect(realtime.listenersOn('channel.c1'), 2);

      // خرج من شاشة القناة: القائمة ما زالت تستمع.
      await realtime.unsubscribe('channel.c1');

      expect(
        realtime.listenersOn('channel.c1'),
        1,
        reason: 'هذا هو الباگ الذي كان يجعل عضواً قديماً لا يرى المنضمّ الجديد',
      );
    });

    test('آخر مستمع يغادر فيسقط الاشتراك', () async {
      await realtime.subscribe('channel.c1');
      await realtime.subscribe('channel.c1');
      await realtime.unsubscribe('channel.c1');
      await realtime.unsubscribe('channel.c1');

      expect(realtime.listenersOn('channel.c1'), 0);
    });

    test('فكّ اشتراك زائد لا ينزل تحت الصفر', () async {
      await realtime.subscribe('channel.c1');
      await realtime.unsubscribe('channel.c1');
      await realtime.unsubscribe('channel.c1');
      await realtime.unsubscribe('channel.c1');

      expect(realtime.listenersOn('channel.c1'), 0);

      // ويبقى الاشتراك من جديد ممكناً بعدها.
      await realtime.subscribe('channel.c1');
      expect(realtime.listenersOn('channel.c1'), 1);
    });

    test('القنوات مستقلة عن بعضها', () async {
      await realtime.subscribe('channel.c1');
      await realtime.subscribe('game.g1');
      await realtime.unsubscribe('channel.c1');

      expect(realtime.listenersOn('channel.c1'), 0);
      expect(realtime.listenersOn('game.g1'), 1);
    });

    test('قطع الاتصال ينسى كل الاشتراكات', () async {
      await realtime.subscribe('channel.c1');
      await realtime.subscribe('game.g1');

      await realtime.disconnect();

      expect(realtime.listenersOn('channel.c1'), 0);
      expect(realtime.listenersOn('game.g1'), 0);
    });
  });
}
