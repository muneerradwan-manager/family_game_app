import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/feedback/game_feedback.dart';
import 'core/network/api_client.dart';
import 'core/realtime/realtime_client.dart';
import 'core/storage/token_store.dart';
import 'core/theme/theme_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // قبل أي شيء: بقية التطبيق تقرأ عناوين السيرفر منه.
  await AppConfig.load();

  final preferences = await SharedPreferences.getInstance();

  // التوكنات في تخزين النظام الآمن، والتفضيلات في التخزين العادي.
  final tokens = TokenStore(const FlutterSecureStorage());

  final api = ApiClient(tokens);
  final realtime = RealtimeClient(tokens);
  final feedback = GameFeedback(preferences);

  await feedback.prepare();

  runApp(
    FamilyGamesApp(
      tokens: tokens,
      api: api,
      realtime: realtime,
      feedback: feedback,
      themeCubit: ThemeCubit(preferences),
    ),
  );
}
