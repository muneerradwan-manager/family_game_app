import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_game_app/core/network/api_client.dart';
import 'package:family_game_app/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

/// محوّل وهمي: يسجّل كل طلب ويرد بما نحدّده، بلا شبكة.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late _MockStorage storage;
  late TokenStore tokens;

  setUp(() async {
    storage = _MockStorage();

    when(
      () => storage.read(key: 'auth.access_token'),
    ).thenAnswer((_) async => 'old-access');
    when(
      () => storage.read(key: 'auth.refresh_token'),
    ).thenAnswer((_) async => 'old-refresh');
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    tokens = TokenStore(storage);
    await tokens.load();
  });

  group('تجديد التوكن عند 401', () {
    test('يجدّد ويعيد المحاولة على /auth/me — لا يطلّع المستخدم', () async {
      final client = ApiClient(tokens);
      var meCalls = 0;

      final adapter = _FakeAdapter((options) {
        if (options.path.endsWith('/auth/refresh')) {
          return _json({
            'tokens': {
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            },
          }, 200);
        }

        meCalls++;

        // التوكن القديم مرفوض، والجديد مقبول.
        return options.headers['Authorization'] == 'Bearer new-access'
            ? _json({
                'user': {'id': 'u1', 'username': 'ahmad', 'gender': 'male'},
              }, 200)
            : _json({'message': 'Unauthenticated.'}, 401);
      });

      client.dio.httpClientAdapter = adapter;

      final result = await client.get('/auth/me');

      expect(result['user']['username'], 'ahmad');
      expect(meCalls, 2, reason: 'مرة سقطت ومرة نجحت بعد التجديد');
      expect(tokens.accessToken, 'new-access');
      expect(
        tokens.refreshToken,
        'new-refresh',
        reason: 'التوكن المُدوَّر انحفظ',
      );
    });

    test('لا يجدّد إن كان 401 من مسار التجديد نفسه', () async {
      final client = ApiClient(tokens);

      final adapter = _FakeAdapter(
        (_) => _json({'message': 'انتهت الجلسة'}, 401),
      );
      client.dio.httpClientAdapter = adapter;

      var expired = 0;
      client.onSessionExpired = () => expired++;

      await expectLater(client.post('/auth/refresh'), throwsA(anything));

      // طلب واحد فقط: لا حلقة تجديد تدور على نفسها.
      expect(adapter.requests, hasLength(1));
      expect(expired, 0);
    });

    test('يستسلم ويُبلغ بانتهاء الجلسة إن فشل التجديد', () async {
      final client = ApiClient(tokens);

      final adapter = _FakeAdapter(
        (options) => options.path.endsWith('/auth/refresh')
            ? _json({'message': 'انتهت الجلسة'}, 401)
            : _json({'message': 'Unauthenticated.'}, 401),
      );

      client.dio.httpClientAdapter = adapter;

      var expired = 0;
      client.onSessionExpired = () => expired++;

      await expectLater(client.get('/channels'), throwsA(anything));

      expect(expired, 1);
      expect(tokens.refreshToken, isNull, reason: 'التوكن الميت انمسح');
    });

    test('لا يعيد المحاولة أكثر من مرة على نفس الطلب', () async {
      final client = ApiClient(tokens);
      var protectedCalls = 0;

      final adapter = _FakeAdapter((options) {
        if (options.path.endsWith('/auth/refresh')) {
          return _json({
            'tokens': {'access_token': 'a', 'refresh_token': 'r'},
          }, 200);
        }

        protectedCalls++;

        // يرفض دائماً: بلا حارس ستدور المحاولات بلا نهاية.
        return _json({'message': 'Unauthenticated.'}, 401);
      });

      client.dio.httpClientAdapter = adapter;

      await expectLater(client.get('/channels'), throwsA(anything));

      expect(protectedCalls, 2, reason: 'الأصلي ثم إعادة واحدة لا أكثر');
    });

    test('طلب بلا توكن لا يشغّل التجديد', () async {
      await tokens.clear();

      final client = ApiClient(tokens);
      final adapter = _FakeAdapter(
        (_) => _json({'message': 'Unauthenticated.'}, 401),
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(client.post('/auth/login'), throwsA(anything));

      expect(adapter.requests, hasLength(1));
    });
  });
}
