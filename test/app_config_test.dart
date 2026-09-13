import 'package:family_game_app/core/config/app_config.dart';
import 'package:family_game_app/core/diagnostics/app_log.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(dotenv.clean);

  group('إعدادات الاتصال', () {
    test('تُقرأ من .env', () {
      dotenv.loadFromString(
        envString:
            'API_HOST=192.168.1.9\nAPI_PORT=9000\nREVERB_PORT=9090\nREVERB_KEY=abc123',
      );

      expect(AppConfig.host, '192.168.1.9');
      expect(AppConfig.apiBaseUrl, 'http://192.168.1.9:9000/api');
      expect(AppConfig.reverbPort, 9090);
      expect(AppConfig.reverbKey, 'abc123');
    });

    test('Reverb يتبع API_HOST ما لم يُحدَّد', () {
      dotenv.loadFromString(envString: 'API_HOST=10.0.0.5\nREVERB_HOST=');

      expect(AppConfig.reverbHost, '10.0.0.5');
      expect(AppConfig.websocketUrl, 'ws://10.0.0.5:8090');
    });

    test('REVERB_HOST يفصل القناة الحيّة عن الـ API حين يُحدَّد', () {
      dotenv.loadFromString(
        envString:
            'API_HOST=10.0.0.5\nREVERB_HOST=ws.example.com\nREVERB_TLS=true',
      );

      expect(AppConfig.reverbHost, 'ws.example.com');
      expect(AppConfig.websocketUrl, 'wss://ws.example.com:8090');
    });

    test('القيم الفارغة في .env لا تطغى على الافتراضي', () {
      dotenv.loadFromString(envString: 'API_HOST=\nAPI_PORT=\nREVERB_KEY=');

      expect(AppConfig.apiPort, '8000');
      expect(AppConfig.reverbKey, isNotEmpty);
      expect(AppConfig.host, isNotEmpty, reason: 'يرجع لافتراضي المنصّة');
    });

    test('المسافات حول القيم تُزال', () {
      dotenv.loadFromString(envString: 'API_HOST=  192.168.1.9  ');

      expect(AppConfig.host, '192.168.1.9');
    });

    test('غياب .env لا يكسر شيئاً', () {
      // لا تحميل هنا إطلاقاً: dotenv غير مهيّأ.
      expect(AppConfig.apiPort, '8000');
      expect(AppConfig.reverbPort, 8090);
      expect(AppConfig.apiBaseUrl, contains(':8000/api'));
    });
  });

  group('سجل التطوير', () {
    test('يخفي كلمة السر والتوكنات', () {
      final printed = AppLog.body({
        'phone': '+962791234567',
        'password': 'secret123',
        'tokens': {'access_token': 'aaa', 'refresh_token': 'bbb'},
      })!;

      expect(printed, contains('+962791234567'), reason: 'ما نخفيه ليس سراً');
      expect(printed, isNot(contains('secret123')));
      expect(printed, isNot(contains('aaa')));
      expect(printed, isNot(contains('bbb')));
      expect(printed, contains('•••'));
    });

    test('يخفي الأسرار داخل القوائم أيضاً', () {
      final printed = AppLog.body([
        {'password': 'one'},
        {'password': 'two'},
      ])!;

      expect(printed, isNot(contains('one')));
      expect(printed, isNot(contains('two')));
    });

    test('يقصّ الأجسام الطويلة بدل إغراق السجل', () {
      final printed = AppLog.body({'answers': 'ا' * 2000})!;

      expect(printed.length, lessThan(900));
      expect(printed, contains('…'));
    });

    test('يتحمّل ما ليس JSON', () {
      expect(AppLog.body(null), isNull);
      expect(AppLog.body('نص عادي'), 'نص عادي');
    });
  });
}
