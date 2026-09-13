import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../model/app_user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<AppUser> register({
    required String phone,
    required String password,
    required String fullName,
    required String username,
    required Gender gender,
    String? avatarId,
    String? recoveryEmail,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'username': username,
        'gender': gender.value,
        'avatarId': ?avatarId,
        if (recoveryEmail != null && recoveryEmail.isNotEmpty)
          'recoveryEmail': recoveryEmail,
      },
    );

    return _persist(data);
  }

  Future<AppUser> login({
    required String phone,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      body: {'phone': phone, 'password': password},
    );

    return _persist(data);
  }

  Future<AppUser> me() async {
    final data = await _api.get('/auth/me');

    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<AppUser> updateProfile(Map<String, dynamic> changes) async {
    final data = await _api.patch('/profile', body: changes);

    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  /// فحص لحظي أثناء الكتابة في شاشة البروفايل.
  Future<({bool available, String message})> checkUsername(
    String username,
  ) async {
    final data = await _api.get(
      '/profile/username-check',
      query: {'username': username},
    );

    return (
      available: data['available'] == true,
      message: '${data['message']}',
    );
  }

  Future<void> logout() async {
    try {
      await _api.post(
        '/auth/logout',
        body: {'refreshToken': _tokens.refreshToken},
      );
    } catch (_) {
      // الخروج محلي أولاً: فشل إبلاغ السيرفر لا يبقي المستخدم داخلاً.
    }

    await _tokens.clear();
  }

  Future<AppUser> _persist(Map<String, dynamic> data) async {
    final tokens = Map<String, dynamic>.from(data['tokens'] as Map);

    await _tokens.save(
      accessToken: '${tokens['access_token']}',
      refreshToken: '${tokens['refresh_token']}',
    );

    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }
}
