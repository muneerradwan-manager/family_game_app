import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/feedback/game_feedback.dart';
import 'core/media/image_upload_service.dart';
import 'core/network/api_client.dart';
import 'core/realtime/realtime_client.dart';
import 'core/router.dart';
import 'core/storage/token_store.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/channels/cubit/channels_cubit.dart';
import 'features/channels/data/channel_repository.dart';
import 'features/games/data/game_repository.dart';
import 'features/games/hadaf/data/hadaf_repository.dart';
import 'features/games/harf/data/harf_repository.dart';
import 'features/games/mashhad/data/mashhad_repository.dart';
import 'features/games/spy/data/spy_repository.dart';

class FamilyGamesApp extends StatefulWidget {
  const FamilyGamesApp({
    super.key,
    required this.tokens,
    required this.api,
    required this.realtime,
    required this.feedback,
    required this.themeCubit,
  });

  final TokenStore tokens;
  final ApiClient api;
  final RealtimeClient realtime;
  final GameFeedback feedback;
  final ThemeCubit themeCubit;

  @override
  State<FamilyGamesApp> createState() => _FamilyGamesAppState();
}

class _FamilyGamesAppState extends State<FamilyGamesApp> {
  late final AuthRepository _authRepository = AuthRepository(
    widget.api,
    widget.tokens,
  );
  late final AuthCubit _authCubit = AuthCubit(
    _authRepository,
    widget.tokens,
    widget.realtime,
  );
  late final GoRouter _router = buildRouter(_authCubit);

  @override
  void initState() {
    super.initState();

    // فشل تجديد التوكن يعني انتهاء الجلسة فعلاً: نخرج المستخدم بدل تركه
    // أمام شاشة تفشل طلباتها بصمت.
    widget.api.onSessionExpired = _authCubit.sessionExpired;

    _authCubit.bootstrap();
  }

  @override
  void dispose() {
    _authCubit.close();
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
          BlocProvider.value(value: _authCubit),
          BlocProvider(
            create: (context) => ChannelsCubit(
              context.read<ChannelRepository>(),
              widget.realtime,
            ),
          ),
        ],
        child: BlocBuilder<ThemeCubit, AppPalette>(
          builder: (context, palette) => MaterialApp.router(
            title: 'ألعاب العيلة',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.from(palette),
            routerConfig: _router,
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
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
