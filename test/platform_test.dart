import 'dart:io';

import 'package:family_game_app/core/config/app_version.dart';
import 'package:family_game_app/core/network/api_exception.dart';
import 'package:family_game_app/core/platform/platform_config.dart';
import 'package:family_game_app/core/platform/platform_cubit.dart';
import 'package:family_game_app/core/platform/platform_repository.dart';
import 'package:family_game_app/core/theme/theme_cubit.dart';
import 'package:family_game_app/features/announcements/cubit/announcements_cubit.dart';
import 'package:family_game_app/features/announcements/data/announcement_repository.dart';
import 'package:family_game_app/features/announcements/model/announcement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPlatformRepository extends Mock implements PlatformRepository {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

Map<String, dynamic> themeJson(String key, {String primary = '#112233'}) => {
  'key': key,
  'name': 'ثيم $key',
  'tagline': 'وصف',
  'isDark': false,
  'colors': {
    'primary': primary,
    'onPrimary': '#FFFFFF',
    'secondary': '#445566',
    'accent': '#FF7043',
    'background': '#F0F0F0',
    'surface': '#FFFFFF',
    'surfaceAlt': '#EEEEEE',
    'textPrimary': '#101010',
    'textMuted': '#777777',
    'outline': '#DDDDDD',
    'gradientStart': '#112233',
    'gradientEnd': '#445566',
  },
};

void main() {
  test('نسخة التطبيق في الكود تطابق pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(appVersion, declared, reason: 'حدّث app_version.dart مع pubspec');
  });

  group('مقارنة النسخ', () {
    test('بنفس قاعدة السيرفر', () {
      expect(isVersionLower('1.1.9', '1.2.0'), isTrue);
      expect(isVersionLower('1.2.0', '1.2.0'), isFalse);
      expect(
        isVersionLower('1.10.0', '1.9.0'),
        isFalse,
        reason: 'رقمياً لا نصياً',
      );
      expect(
        isVersionLower('1.2', '1.2.0'),
        isFalse,
        reason: 'الخانة الناقصة صفر',
      );
      expect(
        isVersionLower('1.2.0+99', '1.2.1'),
        isTrue,
        reason: 'البناء لا يُحسب',
      );
      expect(isVersionLower('2.0.0+1', '1.9.9'), isFalse);
    });
  });

  group('إعدادات اللوحة', () {
    test('تتحمّل حقولاً فارغة بصيغة PHP', () {
      final config = PlatformConfig.fromJson({
        'maintenance': [],
        'registration': [],
        'minAppVersion': {'version': null},
        'themes': {},
      });

      expect(config.maintenanceEnabled, isFalse);
      expect(config.registrationEnabled, isTrue);
      expect(config.minVersion, isNull);
      expect(config.themes, isEmpty);
      expect(config.requiresUpgrade('0.0.1'), isFalse);
    });
  });

  group('PlatformCubit', () {
    late _MockPlatformRepository repository;
    late ThemeCubit themes;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = _MockPlatformRepository();
      themes = ThemeCubit(await SharedPreferences.getInstance());
    });

    PlatformCubit cubit({String version = '1.2.0+5'}) =>
        PlatformCubit(repository, themes, currentVersion: version);

    test('الصيانة تحجب التطبيق برسالة المشرف', () async {
      when(() => repository.fetch()).thenAnswer(
        (_) async => const PlatformConfig(
          maintenanceEnabled: true,
          maintenanceMessage: 'راجعين بعد ساعة',
        ),
      );

      final platform = cubit();
      await platform.refresh();

      expect(platform.state.block, PlatformBlock.maintenance);
      expect(platform.state.message, 'راجعين بعد ساعة');
    });

    test('النسخة الأقدم من الحد تُطلب تحديثها', () async {
      when(() => repository.fetch()).thenAnswer(
        (_) async => const PlatformConfig(
          minVersion: '1.3.0',
          upgradeMessage: 'حدّث',
          storeUrl: 'https://store.example/app',
        ),
      );

      final platform = cubit();
      await platform.refresh();

      expect(platform.state.block, PlatformBlock.upgrade);
      expect(platform.state.storeUrl, 'https://store.example/app');
    });

    test('النسخة المساوية للحد تمرّ', () async {
      when(
        () => repository.fetch(),
      ).thenAnswer((_) async => const PlatformConfig(minVersion: '1.2.0'));

      final platform = cubit();
      await platform.refresh();

      expect(platform.state.isBlocked, isFalse);
    });

    test('فشل الشبكة لا يحجب أحداً', () async {
      when(
        () => repository.fetch(),
      ).thenThrow(ApiException('ما في اتصال بالسيرفر.'));

      final platform = cubit();
      await platform.refresh();

      expect(platform.state.isBlocked, isFalse);
    });

    test('إشارة من طلب مرفوض تحجب، ورفع الصيانة يُعيد التطبيق', () async {
      final platform = cubit();

      platform.maintenance('صيانة مفاجئة');
      expect(platform.state.block, PlatformBlock.maintenance);

      when(
        () => repository.fetch(),
      ).thenAnswer((_) async => const PlatformConfig());

      await platform.refresh();

      expect(platform.state.isBlocked, isFalse);
    });

    test('إغلاق التسجيل يصل للشاشة', () async {
      when(() => repository.fetch()).thenAnswer(
        (_) async => const PlatformConfig(
          registrationEnabled: false,
          registrationMessage: 'مسكّر مؤقتاً',
        ),
      );

      final platform = cubit();
      await platform.refresh();

      expect(platform.state.registrationEnabled, isFalse);
      expect(platform.state.registrationMessage, 'مسكّر مؤقتاً');
    });

    test('ثيمات اللوحة تستبدل المدمجة', () async {
      when(() => repository.fetch()).thenAnswer(
        (_) async => PlatformConfig(
          themes: [themeJson('ocean'), themeJson('forest')],
          defaultThemeKey: 'forest',
        ),
      );

      await cubit().refresh();

      expect(themes.state.palettes.map((p) => p.id), ['ocean', 'forest']);
      expect(themes.state.palette.id, 'forest');
    });
  });

  group('الإعلانات', () {
    late _MockAnnouncementRepository repository;

    const important = Announcement(
      id: 1,
      title: 'تحديث مهم',
      body: 'اقرأ',
      level: AnnouncementLevel.danger,
      dismissible: false,
    );
    const news = Announcement(id: 2, title: 'لعبة جديدة', body: 'جرّبوها');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = _MockAnnouncementRepository();
      when(
        () => repository.fetch(),
      ).thenAnswer((_) async => const [important, news]);
    });

    test('المخفي يبقى مخفياً بعد إعادة التشغيل', () async {
      final preferences = await SharedPreferences.getInstance();
      final cubit = AnnouncementsCubit(repository, preferences);

      await cubit.load();
      expect(cubit.state, [important, news]);

      await cubit.dismiss(news);
      expect(cubit.state, [important]);

      final restarted = AnnouncementsCubit(repository, preferences);
      await restarted.load();

      expect(restarted.state, [important]);
    });

    test('الإعلان غير القابل للإخفاء لا يُخفى', () async {
      final cubit = AnnouncementsCubit(
        repository,
        await SharedPreferences.getInstance(),
      );

      await cubit.load();
      await cubit.dismiss(important);

      expect(cubit.state, contains(important));
    });

    test('فشل الجلب يُبقي الشاشة كما هي بلا خطأ', () async {
      when(() => repository.fetch()).thenThrow(ApiException('خطأ'));

      final cubit = AnnouncementsCubit(
        repository,
        await SharedPreferences.getInstance(),
      );

      await cubit.load();

      expect(cubit.state, isEmpty);
    });

    test('الإعلان يُقرأ بتساهل', () {
      final parsed = Announcement.fromJson({
        'id': 7,
        'title': 'عنوان',
        'body': null,
        'level': 'unknown',
      });

      expect(parsed.level, AnnouncementLevel.info);
      expect(parsed.body, '');
      expect(parsed.dismissible, isTrue);
    });
  });
}
