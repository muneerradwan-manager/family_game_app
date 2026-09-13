import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/photo_picker.dart';
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
    create: (context) => ChannelCubit(
      context.read<ChannelRepository>(),
      context.read<RealtimeClient>(),
      channelId,
    )..load(),
    child: const _ChannelView(),
  );
}

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

          if (state.loading && channel == null) return const AppLoader();

          if (channel == null) {
            return AppErrorView(
              message: state.error ?? 'ما قدرنا نفتح القناة.',
              onRetry: () => context.read<ChannelCubit>().load(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ChannelCubit>().load(),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GradientHeader(
                  title: channel.name,
                  subtitle: '${channel.memberCount} أعضاء',
                  leading: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 4),
                    child: BackButton(color: Colors.white),
                  ),
                  trailing: _ChannelMenu(channel: channel),
                  child: _ChannelAvatar(channel: channel),
                ),
                Padding(
                  padding: context.listPadding(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (channel.activeGame != null)
                        _ActiveGameCard(game: channel.activeGame!)
                      else
                        _StartGameButton(channelId: channel.id),
                      const SizedBox(height: 24),
                      const SectionTitle('سجل الألعاب'),
                      _HistoryList(history: state.history),
                      const SizedBox(height: 24),
                      const SectionTitle('رمز الدعوة'),
                      InviteCodeCard(
                        channel: channel,
                        onRegenerate: channel.isOwner
                            ? () => context
                                  .read<ChannelCubit>()
                                  .regenerateInviteCode()
                            : null,
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle('الأعضاء'),
                      _MembersList(channel: channel),
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

/// البطاقة البارزة أعلى الشاشة حين تكون هناك لعبة جارية.
class _ActiveGameCard extends StatelessWidget {
  const _ActiveGameCard({required this.game});

  final ActiveGame game;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      color: palette.accent.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                GameKind.iconOf(game.gameType),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.isLobby
                          ? 'في غرفة مفتوحة'
                          : '${GameKind.nameOf(game.gameType)} جارية',
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
                          : '${game.playerCount} لاعبين',
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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

class _StartGameButton extends StatelessWidget {
  const _StartGameButton({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: () => context.push('/channels/$channelId/games/new'),
    icon: const Icon(Icons.play_arrow_rounded),
    label: const Text('ابدأ لعبة'),
  );
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history});

  final List<GameRecord> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SectionCard(
        child: EmptyState(
          emoji: '🏆',
          title: 'لسا ما لعبتوا',
          subtitle: 'أول لعبة رح تظهر هون مع اسم الفائز.',
        ),
      );
    }

    final palette = context.palette;
    final formatter = DateFormat('d MMM', 'ar');

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final record in history.take(8))
            ListTile(
              dense: true,
              leading: Text(
                GameKind.iconOf(record.gameType),
                style: const TextStyle(fontSize: 22),
              ),
              title: Text(
                GameKind.nameOf(record.gameType),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              subtitle: Text(
                [
                  ?record.outcome,
                  '${record.playerCount} لاعبين',
                  if (record.endedEarly) 'انتهت مبكراً',
                ].join(' · '),
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
              trailing: Text(
                record.finishedAt == null
                    ? ''
                    : formatter.format(record.finishedAt!.toLocal()),
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final myId = context.select((AuthCubit cubit) => cubit.state.userId);

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final member in channel.members)
            ListTile(
              leading: PlayerAvatar(
                username: member.username,
                photoUrl: member.photoUrl,
                avatarId: member.avatarId,
                gender: member.gender,
              ),
              title: Row(
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
                ],
              ),
              subtitle: Text(
                member.fullName,
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
              ),
              trailing: channel.isOwner && !member.isOwner && member.id != myId
                  ? IconButton(
                      tooltip: 'إزالة',
                      icon: Icon(
                        Icons.person_remove_outlined,
                        color: palette.textMuted,
                        size: 20,
                      ),
                      onPressed: () => _confirmRemove(context, member),
                    )
                  : null,
            ),
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
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, color: Colors.white),
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
        const PopupMenuItem(value: 'rename', child: Text('تعديل اسم القناة')),
        const PopupMenuItem(value: 'photo', child: Text('تغيير صورة القناة')),
      ],
      const PopupMenuItem(value: 'leave', child: Text('مغادرة القناة')),
    ],
  );

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
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('اطلع'),
        ),
      ],
    ),
  );
}

/// صورة القناة في الترويسة — والمالك يضغطها ليغيّرها مباشرة.
class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = channel.photoUrl != null && channel.photoUrl!.isNotEmpty;

    return Center(
      child: GestureDetector(
        onTap: channel.isOwner
            ? () async {
                final cubit = context.read<ChannelCubit>();
                final picked = await pickPhoto(context, allowRemove: hasPhoto);

                if (picked != null) await cubit.updatePhoto(picked.url);
              }
            : null,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
            image: hasPhoto
                ? DecorationImage(
                    image: NetworkImage(channel.photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: hasPhoto
              ? null
              : Text(
                  channel.name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
