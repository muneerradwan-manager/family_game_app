import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/responsive.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../announcements/cubit/announcements_cubit.dart';
import '../../announcements/ui/announcements_banner.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../games/game_kind.dart';
import '../cubit/channels_cubit.dart';
import '../model/channel.dart';
import 'join_by_code.dart';

/// الرئيسية: لوحة بأسلوب «نظرة عامة» في لوحة الإدارة.
///
/// أرقام سريعة، ثم الألعاب الشغّالة الآن (أهم ما قد يفتح المستخدم التطبيق
/// لأجله)، ثم شبكة القنوات: عمود على الجوال، وحتى ثلاثة على الشاشة الكبيرة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChannelsCubit>().load();
    context.read<AnnouncementsCubit>().load();
  }

  Future<void> _reload() => Future.wait([
    context.read<ChannelsCubit>().load(),
    context.read<AnnouncementsCubit>().load(),
  ]);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final state = context.watch<ChannelsCubit>().state;

    final fullName = user?.fullName.trim() ?? '';
    final firstName = fullName.isNotEmpty
        ? fullName.split(' ').first
        : (user?.username ?? '');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          // التمرير متاح حتى حين يقصر المحتوى: السحب للتحديث يحتاجه.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.pagePadding(),
          children: [
            PageHeader(
              title: 'أهلاً $firstName 👋',
              subtitle: 'قنواتك وألعابك بمكان واحد',
              actions: [
                OutlinedButton.icon(
                  style: AppButtonStyle.compact,
                  onPressed: () => joinChannelByCode(context),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('انضمام برمز'),
                ),
                FilledButton.icon(
                  style: AppButtonStyle.compact,
                  onPressed: () => context.push('/channels/new'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('قناة جديدة'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const AnnouncementsBanner(padding: EdgeInsets.only(bottom: 8)),
            _content(context, state),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ChannelsState state) {
    if (state.loading && state.channels.isEmpty) return const _HomeSkeleton();

    if (state.error != null && state.channels.isEmpty) {
      return SectionCard(
        child: AppErrorView(
          message: state.error!,
          onRetry: () => context.read<ChannelsCubit>().load(),
        ),
      );
    }

    if (state.channels.isEmpty) {
      return SectionCard(
        child: EmptyState(
          emoji: '👨‍👩‍👧‍👦',
          title: 'لسا ما عندك قنوات',
          subtitle:
              'القناة هي مجموعة العيلة أو الشباب اللي بتلعبوا فيها.\nأنشئ وحدة وابعت الرمز لأهلك.',
          action: FilledButton.icon(
            style: AppButtonStyle.compact,
            onPressed: () => context.push('/channels/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('أنشئ أول قناة'),
          ),
        ),
      );
    }

    final palette = context.palette;
    final channels = state.channels;
    final live = channels.where((channel) => channel.activeGame != null);
    final compact = context.isPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: compact ? 96 : 200,
          spacing: compact ? 10 : 16,
          children: [
            StatCard(
              label: 'القنوات',
              value: '${channels.length}',
              icon: Icons.groups_outlined,
              compact: compact,
            ),
            StatCard(
              label: 'شغّالة هلق',
              value: '${live.length}',
              icon: Icons.sports_esports_outlined,
              tone: palette.success,
              compact: compact,
            ),
            StatCard(
              label: 'الأعضاء',
              value:
                  '${channels.fold<int>(0, (sum, channel) => sum + channel.memberCount)}',
              icon: Icons.people_outline,
              tone: palette.accent,
              compact: compact,
            ),
          ],
        ),
        if (live.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionTitle('🎮 شغّالة هلق'),
          ResponsiveGrid(
            minItemWidth: 300,
            children: [
              for (final channel in live) _LiveGameCard(channel: channel),
            ],
          ),
        ],
        const SizedBox(height: 28),
        SectionTitle('قنواتي (${channels.length})'),
        ResponsiveGrid(
          minItemWidth: 290,
          children: [
            for (final channel in channels) _ChannelCard(channel: channel),
          ],
        ),
      ],
    );
  }
}

class _LiveGameCard extends StatelessWidget {
  const _LiveGameCard({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final game = channel.activeGame!;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GradientMark(emoji: GameKind.iconOf(game.gameType), size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GameKind.nameOf(game.gameType),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      game.isLobby
                          ? '${channel.name} · ${game.startedByUsername ?? 'حدا'} فتح غرفة'
                          : '${channel.name} · ${game.playerCount} لاعبين',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InfoChip(
                game.isLobby ? 'لوبي' : 'تلعب',
                color: game.isLobby ? palette.warning : palette.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                context.push('/games/${game.id}?type=${game.gameType}'),
            // المتأخر يتفرّج فقط: القائمة تُقفل لحظة "ابدأ".
            child: Text(game.isLobby ? 'انضم للعبة' : 'تفرّج'),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final game = channel.activeGame;

    final status = game == null
        ? InfoChip(
            'ما في لعبة هلق',
            color: palette.textMuted,
            icon: Icons.bedtime_outlined,
          )
        : game.isLobby
        ? InfoChip(
            'غرفة مفتوحة — انضم',
            color: palette.warning,
            icon: Icons.meeting_room_outlined,
          )
        : InfoChip(
            '${GameKind.nameOf(game.gameType)} · ${game.playerCount} لاعبين',
            color: palette.success,
            icon: Icons.sports_esports_outlined,
          );

    return SectionCard(
      onTap: () => context.push('/channels/${channel.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ChannelAvatar(name: channel.name, photoUrl: channel.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${channel.memberCount} أعضاء',
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textMuted),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(child: status),
                    const Spacer(),
                    if (channel.isOwner)
                      InfoChip('مالك', color: palette.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final compact = context.isPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: compact ? 96 : 200,
          spacing: compact ? 10 : 16,
          children: [
            for (var index = 0; index < 3; index++)
              StatCardSkeleton(compact: compact),
          ],
        ),
        const SizedBox(height: 30),
        const Shimmer(child: SkeletonBox(width: 120, height: 18)),
        const SizedBox(height: 14),
        ResponsiveGrid(
          minItemWidth: 290,
          children: [
            for (var index = 0; index < 6; index++) const ChannelCardSkeleton(),
          ],
        ),
      ],
    );
  }
}
