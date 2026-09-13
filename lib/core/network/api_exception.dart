import 'package:dio/dio.dart';

/// خطأ جاهز للعرض على المستخدم.
///
/// السيرفر يرد برسائل عربية مفهومة، فنعرضها كما هي؛ وما عداها نترجمه هنا
/// إلى جملة يفهمها الناس لا رمز HTTP.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;

  /// أخطاء التحقق مفرّقة على الحقول، لعرض كل رسالة تحت حقلها.
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  bool get isConflict => statusCode == 409;

  /// على مورد كان في متناولنا قبل قليل: 403 يعني أننا خرجنا منه (أُزلنا من
  /// القناة)، و404 يعني أنه حُذف. الحالتان تعنيان الشيء نفسه للواجهة:
  /// اشطبه من القائمة بدل إبقائه معروضاً وهو غير موجود.
  bool get isGone => statusCode == 403 || statusCode == 404;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;

    if (response == null) {
      // بلا رد أصلاً: المشكلة في العنوان أو الشبكة لا في البيانات. نذكر
      // العنوان الذي جُرّب — هذا يوفّر جولة كاملة من التخمين على المستخدم.
      final address =
          Uri.tryParse(error.requestOptions.baseUrl)?.authority ?? '';
      final at = address.isEmpty ? '' : '\n($address)';

      return ApiException(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'ما قدرنا نوصل للسيرفر — تأكد من الشبكة.$at',
        DioExceptionType.connectionError => 'ما في اتصال بالسيرفر.$at',
        _ => 'صار خطأ غير متوقع.',
      });
    }

    final data = response.data;
    final fieldErrors = <String, String>{};
    var message = 'صار خطأ غير متوقع.';

    if (data is Map) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        message = data['message'] as String;
      }

      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          final value = entry.value;
          final text = value is List && value.isNotEmpty
              ? '${value.first}'
              : '$value';
          fieldErrors['${entry.key}'] = text;
        }

        if (fieldErrors.isNotEmpty) message = fieldErrors.values.first;
      }
    }

    return ApiException(
      message,
      statusCode: response.statusCode,
      fieldErrors: fieldErrors,
    );
  }

  @override
  String toString() => message;
}
