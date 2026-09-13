import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/channels_cubit.dart';
import '../model/channel.dart';

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
  }

  Future<void> _joinByCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _JoinByCodeSheet(),
    );

    if (code == null || !mounted) return;

    final channel = await context.read<ChannelsCubit>().joinByCode(code);

    if (!mounted) return;

    if (channel != null) {
      context.push('/channels/${channel.id}');
    } else {
      final error = context.read<ChannelsCubit>().state.error;

      if (error != null) {
        showAppSnack(context, error, isError: true);
        context.read<ChannelsCubit>().clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'أهلاً ${user?.username ?? ''}',
            subtitle: 'قنواتك وألعابك',
            trailing: IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'الإعدادات',
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderAction(
                    icon: Icons.add_circle_outline,
                    label: 'إنشاء قناة',
                    onTap: () => context.push('/channels/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderAction(
                    icon: Icons.vpn_key_outlined,
                    label: 'انضمام برمز',
                    onTap: _joinByCode,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ChannelsCubit, ChannelsState>(
              builder: (context, state) {
                if (state.loading && state.channels.isEmpty) {
                  return const AppLoader(message: 'عم نجيب قنواتك...');
                }

                if (state.error != null && state.channels.isEmpty) {
                  return AppErrorView(
                    message: state.error!,
                    onRetry: () => context.read<ChannelsCubit>().load(),
                  );
                }

                if (state.channels.isEmpty) {
                  return const SingleChildScrollView(
                    child: EmptyState(
                      emoji: '👨‍👩‍👧‍👦',
                      title: 'لسا ما عندك قنوات',
                      subtitle:
                          'القناة هي مجموعة العيلة أو الشباب اللي بتلعبوا فيها.\nأنشئ وحدة وابعت الرمز لأهلك.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => context.read<ChannelsCubit>().load(),
                  child: ListView.separated(
                    padding: context.listPadding(bottom: 32),
                    itemCount: state.channels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _ChannelTile(channel: state.channels[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.18),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = channel.activeGame;
    final hasPhoto = channel.photoUrl != null && channel.photoUrl!.isNotEmpty;

    return SectionCard(
      onTap: () => context.push('/channels/${channel.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: hasPhoto
                      ? null
                      : LinearGradient(colors: palette.headerGradient),
                  borderRadius: BorderRadius.circular(14),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
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
          // بطاقة اللعبة الجارية: تتحدّث لحظياً عبر القناة الحيّة.
          if (active != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_esports, color: palette.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      active.isLobby
                          ? 'في غرفة مفتوحة — انضم!'
                          : 'لعبة جارية — ${active.playerCount} لاعبين',
                      style: TextStyle(
                        color: palette.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
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

class _JoinByCodeSheet extends StatefulWidget {
  const _JoinByCodeSheet();

  @override
  State<_JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<_JoinByCodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    // viewInsets للكيبورد، و bottomInset لشريط تنقّل النظام. الأول يصفّر
    // الثاني حين يفتح الكيبورد، فأخذ الأكبر منهما هو الصحيح لا جمعهما.
    padding: EdgeInsets.only(
      left: 24,
      right: 24,
      top: 24,
      bottom:
          24 +
          (MediaQuery.viewInsetsOf(context).bottom > 0
              ? MediaQuery.viewInsetsOf(context).bottom
              : context.bottomInset),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'انضمام برمز دعوة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اكتب الرمز اللي وصلك من أهل القناة',
          style: TextStyle(color: context.palette.textMuted),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          autofocus: true,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(6),
            TextInputFormatter.withFunction(
              (_, next) => next.copyWith(text: next.text.toUpperCase()),
            ),
          ],
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          decoration: const InputDecoration(hintText: 'ABC123'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('انضم'),
        ),
      ],
    ),
  );
}
