import 'dart:convert';

import 'package:flutter/foundation.dart';

/// سجل التطوير.
///
/// يعمل في وضع debug فقط: `kDebugMode` ثابت وقت الترجمة، فتُحذف هذه النداءات
/// كلها من بناء الإصدار — بلا سلاسل نصية تُبنى ولا بيانات مستخدمين تُطبع.
///
/// الشكل صناديق ورموز لا ألوان ANSI: الألوان تظهر حروفاً مشوّهة في logcat
/// وفي نوافذ الـ IDE، والرمز يُقرأ في كل مكان.
class AppLog {
  const AppLog._();

  /// أطول ما نطبعه من جسم الطلب أو الرد.
  static const _maxBody = 700;

  /// حقول لا تُطبع أبداً — حتى في جهاز المطوّر.
  static const _secrets = {
    'password',
    'password_confirmation',
    'access_token',
    'refresh_token',
    'refreshToken',
    'auth',
    'fcmToken',
    'fcm_token',
  };

  static void net(String line) => _write('🌐', line);

  static void live(String line) => _write('⚡', line);

  static void warn(String line) => _write('⚠️', line);

  static void error(String line, [Object? detail]) {
    _write('🔴', line);

    if (detail != null) _write('  ', '$detail');
  }

  /// صندوق متعدد الأسطر — للطلب مع جسمه ورده.
  static void box(String title, List<String> lines) {
    if (!kDebugMode) return;

    debugPrint('┌─ $title');

    for (final line in lines) {
      for (final wrapped in line.split('\n')) {
        debugPrint('│  $wrapped');
      }
    }

    debugPrint('└${'─' * 40}');
  }

  /// يحوّل جسم الطلب إلى نص مقروء، مع إخفاء الحقول الحسّاسة وقصّ الطويل.
  static String? body(Object? data) {
    if (data == null) return null;

    try {
      final redacted = _redact(data);

      if (redacted is String) return _clip(redacted);

      final pretty = const JsonEncoder.withIndent('  ').convert(redacted);

      return _clip(pretty);
    } catch (_) {
      return _clip('$data');
    }
  }

  static Object? _redact(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': _secrets.contains('${entry.key}')
              ? '•••'
              : _redact(entry.value),
      };
    }

    if (value is List) return value.map(_redact).toList();

    return value;
  }

  static String _clip(String text) => text.length <= _maxBody
      ? text
      : '${text.substring(0, _maxBody)}… (+${text.length - _maxBody})';

  static void _write(String icon, String line) {
    if (!kDebugMode) return;

    debugPrint('$icon $line');
  }
}
