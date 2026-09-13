import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// على الويب: محوّل يكتم تحذير الـ preflight.
///
/// كل طلب عندنا يحمل `Authorization` و`Content-Type: application/json`، فكل
/// طلب "غير بسيط" بمعايير CORS ويطبع dio تحذيراً مع stack trace كامل. التحذير
/// صحيح تقنياً لكنه بلا فائدة هنا — السيرفر يجيب على الـ preflight (انظر
/// `config/cors.php`) — وحجمه يغرق سجل التطوير ويخفي الأخطاء الحقيقية.
void configureAdapterForPlatform(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(enableCORSWarning: false);
}
