import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/app_log.dart';

/// طباعة كل طلب ورد وخطأ أثناء التطوير.
///
/// أهم رقم هنا هو **المدة**: نصف اللعبة سباق مع مؤقّت، وطلب يأخذ 900 ملّي
/// ثانية يشرح وحده لماذا تأخّرت ضغطة الستوب. ولذلك نطبعها لكل طلب.
class LoggingInterceptor extends Interceptor {
  static const _stopwatchKey = 'startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchKey] = DateTime.now();

    if (kDebugMode) {
      final body = AppLog.body(options.data);
      final query = options.queryParameters.isEmpty
          ? null
          : 'query: ${AppLog.body(options.queryParameters)}';

      AppLog.box('➜ ${options.method} ${options.path}', [?query, ?body]);
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;

    // 202 يعني "وصلت نيّتك" لا "صارت"؛ النتيجة تأتي عبر القناة الحيّة.
    final icon = response.statusCode == 202 ? '📨' : '✅';

    AppLog.net(
      '$icon ${response.statusCode} · ${options.method} ${options.path} · ${_elapsed(options)}',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final status = err.response?.statusCode;

    AppLog.box(
      '🔴 ${status ?? _reason(err)} · ${options.method} ${options.path}',
      [
        'المدة: ${_elapsed(options)}',
        // انقطاع بلا رد يعني عادةً عنواناً خاطئاً لا خطأً في الكود.
        if (status == null) ...[
          'العنوان: ${options.baseUrl}',
          'تلميح: تأكد إن السيرفر شغّال وإن API_HOST صحيح في .env',
        ],
        ?AppLog.body(err.response?.data),
      ],
    );

    handler.next(err);
  }

  static String _elapsed(RequestOptions options) {
    final startedAt = options.extra[_stopwatchKey];

    if (startedAt is! DateTime) return '—';

    return '${DateTime.now().difference(startedAt).inMilliseconds}ms';
  }

  static String _reason(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout => 'انتهت مهلة الاتصال',
    DioExceptionType.sendTimeout => 'انتهت مهلة الإرسال',
    DioExceptionType.receiveTimeout => 'انتهت مهلة الاستقبال',
    DioExceptionType.connectionError => 'ما في اتصال',
    DioExceptionType.cancel => 'أُلغي',
    _ => 'خطأ',
  };
}
