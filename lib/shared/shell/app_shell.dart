import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/model/app_user.dart';
import '../../features/channels/cubit/channels_cubit.dart';
import '../../features/channels/model/channel.dart';
import '../../features/channels/ui/join_by_code.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// هيكل التطبيق خارج اللعب — تصميم لكل مقاس لا تصميم واحد مكبّر:
///
/// * **جوال:** المحتوى بعرض الشاشة وشريط تنقّل سفلي.
/// * **تابلت:** شريط أيقونات جانبي، وقنواتك صوراً صغيرة فيه.
/// * **شاشة كبيرة:** شريط جانبي داكن كلوحة الإدارة — أقسام، وقائمة قنواتك
///   بنقطة خضراء لكل قناة فيها لعبة شغّالة.
///
/// الشاشات داخله تُعطى عرض منطقة المحتوى لا عرض الشاشة ([MediaQuery])، فكل
/// حساب عرض فيها (الأعمدة، الهوامش) يرى المساحة التي تُرسم فيها فعلاً.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const sidebarWidth = 264.0;
  static const railWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;

    if (width < Breakpoints.tablet) {
      // الشريط السفلي للأقسام الرئيسية فقط: شاشة القناة والإنشاء تفاصيلٌ
      // يُرجع منها، لا أقسام يُتنقّل بينها.
      final topLevel = location == '/home' || location == '/settings';

      return Scaffold(
        body: child,
        bottomNavigationBar: topLevel ? _BottomNav(location: location) : null,
      );
    }

    final desktop = width >= Breakpoints.desktop;
    final navWidth = desktop ? sidebarWidth : railWidth;

    return ColoredBox(
      color: context.palette.background,
      child: Row(
        children: [
          SizedBox(
            width: navWidth,
            child: desktop
                ? _Sidebar(location: location)
                : _Rail(location: location),
          ),
          Expanded(
            child: MediaQuery(
              data: media.copyWith(
                size: Size(width - navWidth, media.size.height),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isChannel(String location, Channel channel) =>
    location == '/channels/${channel.id}' ||
    location.startsWith('/channels/${channel.id}/');

// =============================================================================
// الجوال
// =============================================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.palette.outline)),
    ),
    child: NavigationBar(
      selectedIndex: location == '/settings' ? 1 : 0,
      onDestinationSelected: (index) =>
          context.go(index == 0 ? '/home' : '/settings'),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard_rounded),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'الإعدادات',
        ),
      ],
    ),
  );
}

// =============================================================================
// الشاشة الكبيرة
// =============================================================================

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final channelsState = context.watch<ChannelsCubit>().state;

    return Material(
      color: palette.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(
                children: [
                  GradientMark(emoji: '🎲', size: 38),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ألعاب العيلة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  const _NavGroup('عام'),
                  _NavItem(
                    icon: Icons.space_dashboard_outlined,
                    label: 'الرئيسية',
                    active: location == '/home',
                    onTap: () => context.go('/home'),
                  ),
                  _NavItem(
                    icon: Icons.add_circle_outline,
                    label: 'قناة جديدة',
                    active: location == '/channels/new',
                    onTap: () => context.go('/channels/new'),
                  ),
                  _NavItem(
                    icon: Icons.vpn_key_outlined,
                    label: 'انضمام برمز',
                    onTap: () => joinChannelByCode(context),
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'الإعدادات',
                    active: location == '/settings',
                    onTap: () => context.go('/settings'),
                  ),
                  _NavGroup('قنواتي (${channelsState.channels.length})'),
                  if (channelsState.loading && channelsState.channels.isEmpty)
                    for (var index = 0; index < 3; index++) const _NavSkeleton()
                  else if (channelsState.channels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'لسا ما في قنوات',
                        style: TextStyle(
                          color: palette.sidebarText.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    for (final channel in channelsState.channels)
                      _NavItem(
                        leading: ChannelAvatar(
                          name: channel.name,
                          photoUrl: channel.photoUrl,
                          size: 26,
                        ),
                        label: channel.name,
                        active: _isChannel(location, channel),
                        trailing: channel.activeGame == null
                            ? null
                            : _LiveDot(lobby: channel.activeGame!.isLobby),
                        onTap: () => context.go('/channels/${channel.id}'),
                      ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (user != null) _UserFooter(user: user),
          ],
        ),
      ),
    );
  }
}

class _NavGroup extends StatelessWidget {
  const _NavGroup(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
    child: Text(
      label,
      style: TextStyle(
        color: context.palette.sidebarText.withValues(alpha: 0.55),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.trailing,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? Colors.white : palette.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: leading ?? Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.lobby});

  final bool lobby;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: lobby ? 'غرفة مفتوحة' : 'لعبة شغّالة',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: lobby ? palette.warning : palette.success,
          shape: BoxShape.circle,
          border: Border.all(color: palette.sidebar, width: 1.5),
        ),
      ),
    );
  }
}

class _NavSkeleton extends StatelessWidget {
  const _NavSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Opacity(
      opacity: 0.18,
      child: Shimmer(
        child: Row(
          children: [
            SkeletonBox(width: 26, height: 26, radius: 8),
            SizedBox(width: 12),
            Expanded(child: SkeletonLine(widthFactor: 0.7)),
          ],
        ),
      ),
    ),
  );
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/settings'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              PlayerAvatar(
                username: user.username,
                photoUrl: user.photoUrl,
                avatarId: user.avatarId,
                gender: user.gender,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? user.username : user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: palette.sidebarText.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () => context.read<AuthCubit>().logout(),
                icon: Icon(Icons.logout_rounded, color: palette.sidebarText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// التابلت
// =============================================================================

class _Rail extends StatelessWidget {
  const _Rail({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final channels = context.select(
      (ChannelsCubit cubit) => cubit.state.channels,
    );

    return Material(
      color: palette.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            const GradientMark(emoji: '🎲', size: 42),
            const SizedBox(height: 16),
            _RailButton(
              icon: Icons.space_dashboard_outlined,
              tooltip: 'الرئيسية',
              active: location == '/home',
              onTap: () => context.go('/home'),
            ),
            _RailButton(
              icon: Icons.add_circle_outline,
              tooltip: 'قناة جديدة',
              active: location == '/channels/new',
              onTap: () => context.go('/channels/new'),
            ),
            _RailButton(
              icon: Icons.vpn_key_outlined,
              tooltip: 'انضمام برمز',
              onTap: () => joinChannelByCode(context),
            ),
            _RailButton(
              icon: Icons.settings_outlined,
              tooltip: 'الإعدادات',
              active: location == '/settings',
              onTap: () => context.go('/settings'),
            ),
            Divider(
              color: Colors.white.withValues(alpha: 0.10),
              indent: 20,
              endIndent: 20,
              height: 24,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final channel in channels)
                    _RailChannel(
                      channel: channel,
                      active: _isChannel(location, channel),
                    ),
                ],
              ),
            ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Tooltip(
                  message: user.fullName,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.go('/settings'),
                    child: PlayerAvatar(
                      username: user.username,
                      photoUrl: user.photoUrl,
                      avatarId: user.avatarId,
                      gender: user.gender,
                      size: 40,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 54,
            height: 46,
            child: Icon(
              icon,
              color: active ? Colors.white : context.palette.sidebarText,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RailChannel extends StatelessWidget {
  const _RailChannel({required this.channel, required this.active});

  final Channel channel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final game = channel.activeGame;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Center(
        child: Tooltip(
          message: channel.name,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/channels/${channel.id}'),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ChannelAvatar(
                    name: channel.name,
                    photoUrl: channel.photoUrl,
                    size: 40,
                  ),
                  if (game != null)
                    PositionedDirectional(
                      top: -2,
                      end: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: game.isLobby
                              ? palette.warning
                              : palette.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.sidebar, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
