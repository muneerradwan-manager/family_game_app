import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/channels/ui/channel_screen.dart';
import '../features/channels/ui/create_channel_screen.dart';
import '../features/channels/ui/home_screen.dart';
import '../features/games/ui/game_config_screen.dart';
import '../features/games/ui/game_picker_screen.dart';
import '../features/games/ui/game_session_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../shared/widgets/common.dart';

/// يعيد بناء التوجيه كلما تغيّرت حالة الدخول.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter buildRouter(AuthCubit auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(auth.stream),
    redirect: (context, state) {
      final status = auth.state.status;
      final path = state.matchedLocation;

      // ما زلنا نتحقق من جلسة محفوظة: نبقى على شاشة الإقلاع.
      if (status == AuthStatus.unknown) return path == '/' ? null : '/';

      final onAuthScreens = path == '/login' || path == '/register';

      if (status == AuthStatus.unauthenticated) {
        return onAuthScreens ? null : '/login';
      }

      return onAuthScreens || path == '/' ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/channels/new',
        builder: (_, _) => const CreateChannelScreen(),
      ),
      GoRoute(
        path: '/channels/:channelId',
        builder: (_, state) =>
            ChannelScreen(channelId: state.pathParameters['channelId']!),
        routes: [
          GoRoute(
            path: 'games/new',
            builder: (_, state) =>
                GamePickerScreen(channelId: state.pathParameters['channelId']!),
          ),
          GoRoute(
            path: 'games/new/:gameType',
            builder: (_, state) => GameConfigScreen(
              channelId: state.pathParameters['channelId']!,
              gameType: state.pathParameters['gameType']!,
            ),
          ),
        ],
      ),
      // شاشة واحدة للجلسة كلها: اللوبي واللعب والنتيجة مراحل من حالة واحدة،
      // وفصلها لمسارات يفتح باب سباقات تنقّل عند تغيّر المرحلة لحظياً.
      //
      // والمسار واحد لكل الألعاب: الموزّع يقرأ نوع اللعبة ويسلّم الشاشة
      // لوحدتها، فإضافة لعبة لا تضيف مساراً.
      GoRoute(
        path: '/games/:gameId',
        builder: (_, state) => GameSessionScreen(
          gameId: state.pathParameters['gameId']!,
          gameType: state.uri.queryParameters['type'],
        ),
      ),
    ],
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: AppLoader());
}
