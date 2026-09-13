import 'package:bloc_test/bloc_test.dart';
import 'package:family_game_app/core/theme/app_palette.dart';
import 'package:family_game_app/core/theme/app_theme.dart';
import 'package:family_game_app/features/auth/cubit/auth_cubit.dart';
import 'package:family_game_app/features/auth/model/app_user.dart';
import 'package:family_game_app/features/channels/cubit/channels_cubit.dart';
import 'package:family_game_app/features/channels/model/channel.dart';
import 'package:family_game_app/shared/shell/app_shell.dart';
import 'package:family_game_app/shared/widgets/common.dart';
import 'package:family_game_app/shared/widgets/responsive.dart';
import 'package:family_game_app/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends MockCubit<AuthState> implements AuthCubit {}

class _MockChannels extends MockCubit<ChannelsState> implements ChannelsCubit {}

const _phone = Size(390, 844);
const _tablet = Size(820, 1180);
const _desktop = Size(1440, 900);

/// يضبط مقاس الشاشة الافتراضية للاختبار ويعيده بعده.
void _useSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.from(appPalettes.first),
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void main() {
  group('ResponsiveGrid', () {
    test('عدد الأعمدة من العرض المتاح', () {
      // جوال: بطاقة واحدة بعرض السطر.
      expect(ResponsiveGrid.columnsFor(358, minItemWidth: 290), 1);
      // تابلت بعد الشريط الجانبي: عمودان.
      expect(ResponsiveGrid.columnsFor(700, minItemWidth: 290), 2);
      // شاشة كبيرة: ثلاثة، ولا أكثر من السقف مهما اتسعت.
      expect(ResponsiveGrid.columnsFor(1180, minItemWidth: 290), 3);
      expect(ResponsiveGrid.columnsFor(4000, minItemWidth: 290), 3);
    });

    testWidgets('صفوف متساوية الارتفاع ولا يضيع عنصر من صف ناقص', (
      tester,
    ) async {
      _useSize(tester, _desktop);

      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: ResponsiveGrid(
              minItemWidth: 290,
              children: [
                for (var index = 0; index < 5; index++)
                  SizedBox(
                    height: 40.0 + index * 10,
                    child: Text('بطاقة $index'),
                  ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('بطاقة'), findsNWidgets(5));
      expect(find.byType(IntrinsicHeight), findsNWidgets(2), reason: '3 + 2');
    });
  });

  group('TwoPane', () {
    Future<void> pump(WidgetTester tester, Size size) async {
      _useSize(tester, size);

      await tester.pumpWidget(
        _app(
          const SingleChildScrollView(
            child: TwoPane(
              sideFirstWhenStacked: true,
              main: SizedBox(height: 50, child: Text('رئيسي')),
              side: SizedBox(height: 50, child: Text('جانبي')),
            ),
          ),
        ),
      );
    }

    testWidgets('على الجوال: عمود واحد والجانبي أولاً حين يُطلب', (
      tester,
    ) async {
      await pump(tester, _phone);

      final main = tester.getTopLeft(find.text('رئيسي'));
      final side = tester.getTopLeft(find.text('جانبي'));

      expect(side.dy, lessThan(main.dy));
    });

    testWidgets('على الشاشة الكبيرة: جنباً إلى جنب', (tester) async {
      await pump(tester, _desktop);

      final main = tester.getTopLeft(find.text('رئيسي'));
      final side = tester.getTopLeft(find.text('جانبي'));

      expect(side.dy, main.dy);
      // RTL: الرئيسي على اليمين والجانبي على اليسار.
      expect(side.dx, lessThan(main.dx));
    });
  });

  group('PageHeader', () {
    Future<(Offset, Offset)> pump(WidgetTester tester, Size size) async {
      _useSize(tester, size);

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PageHeader(
                title: 'العنوان',
                actions: [
                  FilledButton(
                    style: AppButtonStyle.compact,
                    onPressed: () {},
                    child: const Text('زر'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      return (
        tester.getCenter(find.text('العنوان')),
        tester.getCenter(find.text('زر')),
      );
    }

    testWidgets('على الجوال: الأزرار تحت العنوان', (tester) async {
      final (title, button) = await pump(tester, _phone);

      expect(button.dy, greaterThan(title.dy + 20));
    });

    testWidgets('على الشاشة العريضة: الأزرار بجانب العنوان', (tester) async {
      final (title, button) = await pump(tester, _desktop);

      expect((button.dy - title.dy).abs(), lessThan(20));
    });
  });

  group('Shimmer', () {
    testWidgets('يلمع', (tester) async {
      await tester.pumpWidget(_app(const Shimmer(child: SkeletonBox())));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('يثبت لمن طلب تقليل الحركة', (tester) async {
      await tester.pumpWidget(
        _app(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Shimmer(child: SkeletonBox()),
          ),
        ),
      );

      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('هيكل التطبيق حسب المقاس', () {
    late _MockAuth auth;
    late _MockChannels channels;

    const user = AppUser(
      id: 'u1',
      username: 'ahmad',
      fullName: 'أحمد علي',
      gender: Gender.male,
    );

    setUp(() {
      auth = _MockAuth();
      channels = _MockChannels();

      when(() => auth.state).thenReturn(
        const AuthState(status: AuthStatus.authenticated, user: user),
      );
      when(() => channels.state).thenReturn(
        const ChannelsState(
          loading: false,
          channels: [
            Channel(
              id: 'c1',
              name: 'عيلة أبو أحمد',
              ownerId: 'u1',
              isOwner: true,
              inviteCode: 'ABC123',
              activeGame: ActiveGame(
                id: 'g1',
                gameType: 'harf',
                status: 'playing',
              ),
            ),
          ],
        ),
      );
    });

    Future<void> pump(WidgetTester tester, Size size, String location) async {
      _useSize(tester, size);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<ChannelsCubit>.value(value: channels),
          ],
          child: _app(
            AppShell(
              location: location,
              child: const Scaffold(body: Text('محتوى')),
            ),
          ),
        ),
      );
    }

    testWidgets('جوال: شريط سفلي في الأقسام الرئيسية', (tester) async {
      await pump(tester, _phone, '/home');

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('قنواتي (1)'), findsNothing);
    });

    testWidgets('جوال: لا شريط سفلي داخل تفاصيل القناة', (tester) async {
      await pump(tester, _phone, '/channels/c1');

      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('تابلت: شريط أيقونات جانبي بلا شريط سفلي', (tester) async {
      await pump(tester, _tablet, '/home');

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byTooltip('عيلة أبو أحمد'), findsOneWidget);
    });

    testWidgets('شاشة كبيرة: شريط جانبي بالأقسام وقائمة القنوات', (
      tester,
    ) async {
      await pump(tester, _desktop, '/channels/c1');

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('قنواتي (1)'), findsOneWidget);
      expect(find.text('عيلة أبو أحمد'), findsOneWidget);
      // لعبة شغّالة في القناة: نقطة حالة بجانبها.
      expect(find.byTooltip('لعبة شغّالة'), findsOneWidget);
    });

    testWidgets('المحتوى يرى عرض منطقته لا عرض الشاشة', (tester) async {
      late double seen;

      _useSize(tester, _desktop);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<ChannelsCubit>.value(value: channels),
          ],
          child: _app(
            AppShell(
              location: '/home',
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.sizeOf(context).width;

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(seen, _desktop.width - AppShell.sidebarWidth);
    });
  });
}
