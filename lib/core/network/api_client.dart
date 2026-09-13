import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../diagnostics/app_log.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';
import 'logging_interceptor.dart';
import 'platform_adapter.dart';

/// عميل الشبكة: يرفق التوكن، ويجدّده تلقائياً، ويحوّل أخطاء Dio إلى رسائل.
class ApiClient {
  ApiClient(this._tokens) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    configureAdapterForPlatform(dio);

    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onError: _retryAfterRefresh),
    );

    // آخر واحد في السلسلة: يرى الطلب بعد إرفاق التوكن، والرد بعد إعادة
    // المحاولة — أي ما جرى فعلاً على الشبكة لا ما نوينا إرساله.
    if (kDebugMode) dio.interceptors.add(LoggingInterceptor());
  }

  late final Dio dio;
  final TokenStore _tokens;

  /// يُستدعى حين يفشل التجديد: انتهت الجلسة فعلاً ولا بد من دخول جديد.
  void Function()? onSessionExpired;

  /// تجديد واحد مشترك: عشرة طلبات متزامنة تصطدم بـ401 معاً يجب ألا تُطلق
  /// عشر عمليات تجديد وتُبطل توكن بعضها البعض.
  Future<bool>? _refreshInFlight;

  void _attachToken(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  /// مسار التجديد نفسه: 401 منه يعني أن refresh token مات فعلاً، ومحاولة
  /// تجديده بتجديد آخر تدور على نفسها إلى ما لا نهاية.
  static const _refreshPath = '/auth/refresh';

  /// علامة على طلب أُعيد إرساله مرة — حتى لا يدخل في حلقة إن ردّ 401 ثانية.
  static const _retriedKey = 'retriedAfterRefresh';

  Future<void> _retryAfterRefresh(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;

    // نجدّد لكل طلب حمل توكناً وسقط بـ401 — بما فيه /auth/me. الاستثناء
    // الوحيد هو مسار التجديد ذاته؛ ومسارات الدخول والتسجيل لا تحمل توكناً
    // أصلاً فلا تصل إلى هنا.
    final eligible =
        error.response?.statusCode == 401 &&
        options.path != _refreshPath &&
        options.headers.containsKey('Authorization') &&
        options.extra[_retriedKey] != true &&
        _tokens.refreshToken != null;

    if (!eligible) {
      return handler.next(error);
    }

    AppLog.warn('401 على ${options.path} — عم نجدّد التوكن');

    final refreshed = await _refresh();

    if (!refreshed) {
      onSessionExpired?.call();

      return handler.next(error);
    }

    try {
      options.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
      options.extra[_retriedKey] = true;

      handler.resolve(await dio.fetch(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refresh() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    try {
      // نفس Dio لا نسخة نظيفة: معترض إعادة المحاولة يستثني مسار التجديد
      // صراحةً، فلا يدور على نفسه. وبهذا تبقى المهل والترويسات والسجل
      // معرّفة في مكان واحد، ويبقى العميل قابلاً للاختبار بمحوّل واحد.
      final response = await dio.post(
        _refreshPath,
        data: {'refreshToken': _tokens.refreshToken},
      );

      final tokens = response.data['tokens'] as Map<String, dynamic>;

      await _tokens.save(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String,
      );

      AppLog.net('🔑 تجدّد التوكن');

      return true;
    } on DioException {
      AppLog.error('فشل تجديد التوكن — انتهت الجلسة');
      await _tokens.clear();

      return false;
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => dio.post(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => dio.delete(path));

  /// نوايا اللعب لا تُنتظر نتيجتها: الحقيقة تصل عبر القناة الحيّة لا في الرد.
  /// فشل الإرسال هنا لا يوقف اللعبة — المؤقّت على السيرفر يكمل بلا هذا اللاعب.
  void fireAndForget(String path, {Object? body}) {
    unawaited(
      dio
          .post(path, data: body)
          .catchError(
            (_) => Response(requestOptions: RequestOptions(path: path)),
          ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<Response> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;

      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
