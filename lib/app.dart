import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/feedback/game_feedback.dart';
import 'core/media/image_upload_service.dart';
import 'core/network/api_client.dart';
import 'core/platform/platform_block_screen.dart';
import 'core/platform/platform_cubit.dart';
import 'core/realtime/realtime_client.dart';
import 'core/router.dart';
import 'core/storage/token_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/announcements/cubit/announcements_cubit.dart';
import 'features/announcements/data/announcement_repository.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/channels/cubit/channels_cubit.dart';
import 'features/channels/data/channel_repository.dart';
import 'features/games/data/game_repository.dart';
import 'features/games/hadaf/data/hadaf_repository.dart';
import 'features/games/harf/data/harf_repository.dart';
import 'features/games/mashhad/data/mashhad_repository.dart';
import 'features/games/spy/data/spy_repository.dart';

class _DragWithMouse extends MaterialScrollBehavior {
  const _DragWithMouse();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class FamilyGamesApp extends StatefulWidget {
  const FamilyGamesApp({
    super.key,
    required this.tokens,
    required this.api,
    required this.realtime,
    required this.feedback,
    required this.preferences,
    required this.themeCubit,
    required this.platformCubit,
  });

  final TokenStore tokens;
  final ApiClient api;
  final RealtimeClient realtime;
  final GameFeedback feedback;
  final SharedPreferences preferences;
  final ThemeCubit themeCubit;
  final PlatformCubit platformCubit;

  @override
  State<FamilyGamesApp> createState() => _FamilyGamesAppState();
}

class _FamilyGamesAppState extends State<FamilyGamesApp>
    with WidgetsBindingObserver {
  late final AuthRepository _authRepository = AuthRepository(
    widget.api,
    widget.tokens,
  );
  late final AuthCubit _authCubit = AuthCubit(
    _authRepository,
    widget.tokens,
    widget.realtime,
  );
  late final AnnouncementsCubit _announcementsCubit = AnnouncementsCubit(
    AnnouncementRepository(widget.api),
    widget.preferences,
  );
  late final GoRouter _router = buildRouter(_authCubit);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final api = widget.api;
    final platform = widget.platformCubit;

    // فشل تجديد التوكن يعني انتهاء الجلسة فعلاً: نخرج المستخدم بدل تركه
    // أمام شاشة تفشل طلباتها بصمت.
    api.onSessionExpired = _authCubit.sessionExpired;

    // قرارات المشرف تصل مع أول طلب يرفضه السيرفر، من أي شاشة كان.
    // (جُمل منفصلة لا cascade: سهم الدالة يبتلع `..` التالية له.)
    api.onMaintenance = platform.maintenance;
    api.onUpgradeRequired = (message, storeUrl, minVersion) =>
        platform.upgradeRequired(
          message: message,
          storeUrl: storeUrl,
          minVersion: minVersion,
        );
    api.onBanned = _authCubit.banned;

    _authCubit.bootstrap();
    widget.platformCubit.refresh();
  }

  /// العودة للتطبيق بعد غياب: ربما رفع المشرف الصيانة أو غيّر الثيمات.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.platformCubit.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authCubit.close();
    _announcementsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.tokens),
        RepositoryProvider.value(value: widget.api),
        RepositoryProvider.value(value: widget.realtime),
        RepositoryProvider.value(value: widget.feedback),
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider(create: (_) => ImageUploadService(widget.api)),
        RepositoryProvider(create: (_) => ChannelRepository(widget.api)),
        RepositoryProvider(create: (_) => GameRepository(widget.api)),
        RepositoryProvider(create: (_) => HarfRepository(widget.api)),
        RepositoryProvider(create: (_) => SpyRepository(widget.api)),
        RepositoryProvider(create: (_) => HadafRepository(widget.api)),
        RepositoryProvider(create: (_) => MashhadRepository(widget.api)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: widget.themeCubit),
          BlocProvider.value(value: widget.platformCubit),
          BlocProvider.value(value: _authCubit),
          BlocProvider.value(value: _announcementsCubit),
          BlocProvider(
            create: (context) => ChannelsCubit(
              context.read<ChannelRepository>(),
              widget.realtime,
            ),
          ),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listenWhen: (previous, current) =>
              previous.status == AuthStatus.authenticated &&
              current.status != AuthStatus.authenticated,
          listener: (_, _) => _announcementsCubit.clear(),
          child: BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, theme) => MaterialApp.router(
              title: 'ألعاب العيلة',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.from(theme.palette),
              routerConfig: _router,
              // على سطح المكتب Flutter لا يسحب القوائم بالماوس افتراضياً (اللمس
              // فقط)، فتتجمّد القوائم الأفقية التي لا تتحرك بعجلة الماوس.
              scrollBehavior: const _DragWithMouse(),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // التطبيق عربي بالكامل: نفرض RTL بدل الاعتماد على لغة الجهاز.
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                // شاشة الحجب فوق الموجّه لا مكانه: رفع الصيانة يعيد المستخدم
                // لنفس الشاشة التي كان عليها.
                child: BlocBuilder<PlatformCubit, PlatformState>(
                  builder: (context, platform) => Stack(
                    fit: StackFit.expand,
                    children: [
                      child ?? const SizedBox.shrink(),
                      if (platform.isBlocked)
                        PlatformBlockScreen(state: platform),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
