import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../../../shared/widgets/responsive.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../games/game_kind.dart';
import '../cubit/channel_cubit.dart';
import '../cubit/channels_cubit.dart';
import '../data/channel_repository.dart';
import '../model/channel.dart';
import 'create_channel_screen.dart';

class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    // المفتاح بالمعرّف: التنقّل بين القنوات من الشريط الجانبي يبني الشاشة
    // نفسها بقناة أخرى، ومع مفتاح ثابت كان سيبقى cubit القناة السابقة.
    key: ValueKey(channelId),
    create: (context) => ChannelCubit(
      context.read<ChannelRepository>(),
      context.read<RealtimeClient>(),
      channelId,
    )..load(),
    child: const _ChannelView(),
  );
}

/// صفحة القناة: اللعب والسجل في العمود الرئيسي، والدعوة والأعضاء في العمود
/// الجانبي — يتكدّسان عموداً واحداً على الجوال.
class _ChannelView extends StatelessWidget {
  const _ChannelView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ChannelCubit, ChannelState>(
        listenWhen: (previous, current) =>
            previous.error != current.error ||
            previous.removed != current.removed,
        listener: (context, state) {
          // أزالنا المالك ونحن داخل الشاشة: نخرج فوراً بدل عرض خطأ صلاحيات
          // على قناة لم تعد لنا.
          if (state.removed) {
            showAppSnack(context, 'ما عدت عضواً في هالقناة.');
            context.read<ChannelsCubit>().load();
            context.go('/home');

            return;
          }

          if (state.error != null) {
            showAppSnack(context, state.error!, isError: true);
            context.read<ChannelCubit>().clearError();
          }
        },
        builder: (context, state) {
          final channel = state.channel;

          if (state.loading && channel == null) {
            return ListView(
              padding: context.pagePadding(),
              children: const [_ChannelSkeleton()],
            );
          }

          if (channel == null) {
            return AppErrorView(
              message: state.error ?? 'ما قدرنا نفتح القناة.',
              onRetry: () => context.read<ChannelCubit>().load(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ChannelCubit>().load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.pagePadding(),
              children: [
                PageHeader(
                  leading: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppBackButton(),
                        _ChannelPhoto(channel: channel),
                      ],
                    ),
                  ),
                  title: channel.name,
                  subtitle: channel.isOwner
                      ? '${channel.memberCount} أعضاء · إنت المالك'
                      : '${channel.memberCount} أعضاء',
                  trailing: _ChannelMenu(channel: channel),
                  actions: [
                    if (channel.activeGame == null)
                      FilledButton.icon(
                        style: AppButtonStyle.compact,
                        onPressed: () =>
                            context.push('/channels/${channel.id}/games/new'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('ابدأ لعبة'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TwoPane(
                  sideWidth: 360,
                  main: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (channel.activeGame != null)
                        _ActiveGameCard(game: channel.activeGame!)
                      else
                        _StartGameCard(channelId: channel.id),
                      const SizedBox(height: 20),
                      _HistoryCard(history: state.history),
                    ],
                  ),
                  side: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InviteCodeCard(
                        channel: channel,
                        onRegenerate: channel.isOwner
                            ? () => context
                                  .read<ChannelCubit>()
                                  .regenerateInviteCode()
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _MembersCard(channel: channel),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// البطاقة البارزة حين تكون هناك لعبة جارية.
class _ActiveGameCard extends StatelessWidget {
  const _ActiveGameCard({required this.game});

  final ActiveGame game;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: game.isLobby ? 'غرفة مفتوحة' : 'لعبة شغّالة هلق',
      trailing: InfoChip(
        game.isLobby ? 'لوبي' : 'تلعب',
        color: game.isLobby ? palette.warning : palette.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GradientMark(emoji: GameKind.iconOf(game.gameType), size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GameKind.nameOf(game.gameType),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      game.isLobby
                          ? '${game.startedByUsername ?? 'حدا'} فتح غرفة — لسا ما بلّشت'
                          : '${game.playerCount} لاعبين عم يلعبوا',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
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

class _StartGameCard extends StatelessWidget {
  const _StartGameCard({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GradientMark(emoji: '🎲', size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ما في لعبة شغّالة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'اختاروا لعبة وابدأوا سوا — الباقيين بيوصلهم إشعار.',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/channels/$channelId/games/new'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ابدأ لعبة'),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<GameRecord> history;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (history.isEmpty) {
      return const SectionCard(
        title: 'سجل الألعاب',
        child: EmptyState(
          emoji: '🏆',
          title: 'لسا ما لعبتوا',
          subtitle: 'أول لعبة رح تظهر هون مع اسم الفائز.',
        ),
      );
    }

    final formatter = DateFormat('d MMM', 'ar');
    final shown = history.take(10).toList();

    return SectionCard(
      title: 'سجل الألعاب',
      trailing: InfoChip('${history.length}', color: palette.textMuted),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (index, record) in shown.indexed) ...[
            if (index > 0) const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      GameKind.iconOf(record.gameType),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          GameKind.nameOf(record.gameType),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            record.outcome ?? 'بلا نتيجة',
                            if (record.endedEarly) 'انتهت مبكراً',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record.finishedAt == null
                            ? ''
                            : formatter.format(record.finishedAt!.toLocal()),
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InfoChip(
                        '${record.playerCount} لاعبين',
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final myId = context.select((AuthCubit cubit) => cubit.state.userId);

    return SectionCard(
      title: 'الأعضاء',
      trailing: InfoChip('${channel.members.length}', color: palette.textMuted),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (index, member) in channel.members.indexed) ...[
            if (index > 0) const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
              child: Row(
                children: [
                  PlayerAvatar(
                    username: member.username,
                    photoUrl: member.photoUrl,
                    avatarId: member.avatarId,
                    gender: member.gender,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.username,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            if (member.isOwner) ...[
                              const SizedBox(width: 8),
                              const InfoChip('مالك'),
                            ],
                            if (member.id == myId) ...[
                              const SizedBox(width: 6),
                              InfoChip('إنت', color: palette.textMuted),
                            ],
                          ],
                        ),
                        Text(
                          member.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (channel.isOwner && !member.isOwner && member.id != myId)
                    IconButton(
                      tooltip: 'إزالة',
                      icon: Icon(
                        Icons.person_remove_outlined,
                        color: palette.textMuted,
                        size: 20,
                      ),
                      onPressed: () => _confirmRemove(context, member),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    ChannelMember member,
  ) async {
    final cubit = context.read<ChannelCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إزالة عضو'),
        content: Text('بدك تشيل ${member.username} من القناة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لأ'),
          ),
          FilledButton(
            style: AppButtonStyle.compact,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('شيله'),
          ),
        ],
      ),
    );

    if (confirmed == true) await cubit.removeMember(member.id);
  }
}

class _ChannelMenu extends StatelessWidget {
  const _ChannelMenu({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopupMenuButton<String>(
      tooltip: 'خيارات القناة',
      onSelected: (value) async {
        final cubit = context.read<ChannelCubit>();
        final channels = context.read<ChannelsCubit>();
        final router = GoRouter.of(context);

        switch (value) {
          case 'rename':
            final name = await _askName(context, channel.name);
            if (name != null) await cubit.rename(name);

          case 'photo':
            final picked = await pickPhoto(
              context,
              allowRemove: channel.photoUrl != null,
            );
            if (picked != null) await cubit.updatePhoto(picked.url);

          case 'leave':
            final confirmed = await _confirmLeave(context);

            if (confirmed == true && await cubit.leaveChannel()) {
              await channels.load();
              router.go('/home');
            }
        }
      },
      itemBuilder: (context) => [
        if (channel.isOwner) ...[
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('تعديل اسم القناة'),
            ),
          ),
          const PopupMenuItem(
            value: 'photo',
            child: ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text('تغيير صورة القناة'),
            ),
          ),
        ],
        PopupMenuItem(
          value: 'leave',
          child: ListTile(
            leading: Icon(Icons.logout_rounded, color: palette.danger),
            title: Text(
              'مغادرة القناة',
              style: TextStyle(color: palette.danger),
            ),
          ),
        ),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: palette.outline),
        ),
        child: Icon(Icons.more_horiz_rounded, color: palette.textPrimary),
      ),
    );
  }

  Future<String?> _askName(BuildContext context, String current) {
    final controller = TextEditingController(text: current);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسم القناة'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: AppButtonStyle.compact,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLeave(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('مغادرة القناة'),
      content: Text(
        channel.isOwner
            // مغادرة المالك تنقل الملكية تلقائياً لأقدم عضو.
            ? 'إنت مالك القناة — الملكية رح تنتقل لأقدم عضو. متأكد؟'
            : 'بدك تطلع من «${channel.name}»؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('لأ'),
        ),
        FilledButton(
          style: AppButtonStyle.compact,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('اطلع'),
        ),
      ],
    ),
  );
}

/// صورة القناة في الرأس — والمالك يضغطها ليغيّرها مباشرة.
class _ChannelPhoto extends StatelessWidget {
  const _ChannelPhoto({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasPhoto = channel.photoUrl != null && channel.photoUrl!.isNotEmpty;

    final avatar = ChannelAvatar(
      name: channel.name,
      photoUrl: channel.photoUrl,
      size: 54,
    );

    if (!channel.isOwner) return avatar;

    return Tooltip(
      message: 'غيّر صورة القناة',
      child: GestureDetector(
        onTap: () async {
          final cubit = context.read<ChannelCubit>();
          final picked = await pickPhoto(context, allowRemove: hasPhoto);

          if (picked != null) await cubit.updatePhoto(picked.url);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            PositionedDirectional(
              bottom: -4,
              end: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.background, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera,
                  size: 11,
                  color: palette.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSkeleton extends StatelessWidget {
  const _ChannelSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeaderSkeleton(avatar: true),
      SizedBox(height: 24),
      TwoPane(
        sideWidth: 360,
        main: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListCardSkeleton(rows: 1, avatar: false),
            SizedBox(height: 20),
            ListCardSkeleton(rows: 5, avatar: false),
          ],
        ),
        side: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormCardSkeleton(fields: 1),
            SizedBox(height: 20),
            ListCardSkeleton(rows: 4),
          ],
        ),
      ),
    ],
  );
}
