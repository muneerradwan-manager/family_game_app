import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_game_app/core/config/app_version.dart';
import 'package:family_game_app/core/network/api_client.dart';
import 'package:family_game_app/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

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
  late TokenStore tokens;

  setUp(() async {
    final storage = _MockStorage();

    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => 'token');
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

  ApiClient client(ResponseBody Function(RequestOptions) respond) {
    final api = ApiClient(tokens);
    api.dio.httpClientAdapter = _FakeAdapter(respond);

    return api;
  }

  test('كل طلب يحمل نسخة التطبيق', () async {
    final adapter = _FakeAdapter((_) => _json({'ok': true}, 200));
    final api = ApiClient(tokens)..dio.httpClientAdapter = adapter;

    await api.get('/channels');

    expect(adapter.requests.single.headers['X-App-Version'], appVersion);
  });

  test('503 الصيانة يُبلغ برسالة المشرف', () async {
    String? received;
    final api = client(
      (_) => _json({'message': 'صيانة', 'maintenance': true}, 503),
    )..onMaintenance = (message) => received = message;

    await expectLater(api.get('/channels'), throwsA(anything));

    expect(received, 'صيانة');
  });

  test('503 بلا علامة الصيانة ليس صيانة', () async {
    var calls = 0;
    final api = client((_) => _json({'message': 'Service Unavailable'}, 503))
      ..onMaintenance = (_) => calls++;

    await expectLater(api.get('/channels'), throwsA(anything));

    expect(calls, 0, reason: 'سيرفر متعطّل لا يعرض شاشة صيانة كاذبة');
  });

  test('426 يُبلغ بالتحديث الإجباري ورابطه', () async {
    List<String?>? received;
    final api =
        client(
            (_) => _json({
              'message': 'حدّث',
              'upgradeRequired': true,
              'minVersion': '2.0.0',
              'storeUrl': 'https://store.example',
            }, 426),
          )
          ..onUpgradeRequired = (message, url, version) =>
              received = [message, url, version];

    await expectLater(api.get('/channels'), throwsA(anything));

    expect(received, ['حدّث', 'https://store.example', '2.0.0']);
  });

  test('403 الإيقاف يُبلغ، و403 العادي لا', () async {
    final messages = <String>[];

    final banned = client(
      (_) => _json({'message': 'حسابك موقوف: مخالفة', 'banned': true}, 403),
    )..onBanned = messages.add;

    await expectLater(banned.get('/channels'), throwsA(anything));

    final notMember = client(
      (_) => _json({'message': 'لست عضواً في هذه القناة.'}, 403),
    )..onBanned = messages.add;

    await expectLater(notMember.get('/channels/x'), throwsA(anything));

    expect(messages, ['حسابك موقوف: مخالفة']);
  });
}
