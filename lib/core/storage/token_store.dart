import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// حفظ التوكنات في تخزين الجهاز الآمن (Keystore / Keychain).
///
/// نحتفظ بنسخة في الذاكرة لأن اعتراض الطلبات ومصافحة الـ WebSocket يحتاجان
/// التوكن مراراً وفي مسارات حسّاسة للزمن، والقراءة من التخزين الآمن غير فورية.
class TokenStore {
  TokenStore(this._storage);

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';

  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  bool get hasSession => _refreshToken != null;

  Future<void> load() async {
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;

    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
