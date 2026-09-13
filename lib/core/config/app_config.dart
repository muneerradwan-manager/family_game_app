import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../diagnostics/app_log.dart';

/// إعدادات الاتصال بالسيرفر.
///
/// المصدر ملف `.env` في جذر التطبيق (انسخه من `.env.example`)، فتبديل عنوان
/// السيرفر لا يحتاج تعديل كود ولا إعادة بناء كاملة — فقط إعادة تشغيل.
///
/// ترتيب الأولوية:
///   1. `--dart-define` عند البناء — للـ CI وبناء الإصدارات
///   2. `.env` — إعداد المطوّر اليومي
///   3. قيمة افتراضية حسب المنصّة
class AppConfig {
  const AppConfig._();

  /// يجب استدعاؤه قبل runApp.
  ///
  /// isOptional: غياب `.env` لا يوقف التطبيق. القيم الافتراضية تكفي على
  /// المحاكي، ومن نسي نسخ الملف يجب أن يرى التطبيق يعمل لا شاشة سوداء.
  static Future<void> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);

    if (dotenv.env.isEmpty) {
      AppLog.warn(
        'ما في .env — رح نستخدم الإعدادات الافتراضية (انسخ .env.example)',
      );
    }

    // أول ما يُطبع عند الإقلاع: عنوان خاطئ هنا يفسّر كل فشل لاحق في الدخول.
    AppLog.box('⚙️  الإعدادات', ['API : $apiBaseUrl', 'WS  : $websocketUrl']);
  }

  // ---- ما يأتي من البناء (يعلو على كل شيء) ----

  static const _definedHost = String.fromEnvironment('API_HOST');
  static const _definedPort = String.fromEnvironment('API_PORT');
  static const _definedReverbHost = String.fromEnvironment('REVERB_HOST');
  static const _definedReverbPort = String.fromEnvironment('REVERB_PORT');
  static const _definedReverbKey = String.fromEnvironment('REVERB_KEY');

  /// محاكي أندرويد يرى مضيف الجهاز على 10.0.2.2 لا 127.0.0.1.
  static String get _platformHost {
    if (kIsWeb) return 'localhost';

    return Platform.isAndroid ? '10.0.2.2' : 'localhost';
  }

  static String get host => _resolve(_definedHost, 'API_HOST', _platformHost);

  static String get apiPort => _resolve(_definedPort, 'API_PORT', '8000');

  /// يتبع API_HOST ما لم يُحدَّد صراحةً: السيرفران على الجهاز نفسه عادةً.
  static String get reverbHost =>
      _resolve(_definedReverbHost, 'REVERB_HOST', host);

  static int get reverbPort =>
      int.tryParse(_resolve(_definedReverbPort, 'REVERB_PORT', '8090')) ?? 8090;

  /// المفتاح العام لـ Reverb (ليس السر) — يطابق REVERB_APP_KEY في السيرفر.
  static String get reverbKey =>
      _resolve(_definedReverbKey, 'REVERB_KEY', 'rmm5o8e10zeqbgpep91e');

  static bool get reverbUseTls =>
      _read('REVERB_TLS').toLowerCase() == 'true' ||
      const bool.fromEnvironment('REVERB_TLS');

  static String get apiBaseUrl => 'http://$host:$apiPort/api';

  /// نقطة توثيق الاشتراك في القنوات الخاصة — تُوثَّق بنفس توكن الـ JWT.
  static String get broadcastAuthUrl =>
      'http://$host:$apiPort/broadcasting/auth';

  static String get websocketUrl =>
      '${reverbUseTls ? 'wss' : 'ws'}://$reverbHost:$reverbPort';

  static String _resolve(String defined, String key, String fallback) {
    if (defined.isNotEmpty) return defined;

    final value = _read(key);

    return value.isNotEmpty ? value : fallback;
  }

  /// قراءة آمنة: dotenv يرمي استثناءً إن قُرئ قبل التحميل — وهذا يحدث في
  /// الاختبارات التي لا تمرّ بـ main().
  static String _read(String key) =>
      dotenv.isInitialized ? (dotenv.env[key]?.trim() ?? '') : '';
}
