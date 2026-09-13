import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../auth/model/app_user.dart';
import '../../cubit/spy_game_cubit.dart';
import '../../model/spy_models.dart';

/// دورك تسأل: اختر لاعباً، واكتب سؤالاً لا يذكر الكلمة.
class AskTurnCard extends StatefulWidget {
  const AskTurnCard({super.key});

  @override
  State<AskTurnCard> createState() => _AskTurnCardState();
}

class _AskTurnCardState extends State<AskTurnCard> {
  final _controller = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final cubit = context.read<SpyGameCubit>();

    if (_sent || cubit.state.selectedTargetId == null) return;
    if (_controller.text.trim().isEmpty) return;

    setState(() => _sent = true);
    cubit.askQuestion(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpyGameCubit>();
    final state = context.watch<SpyGameCubit>().state;
    final palette = context.palette;
    final targets = cubit.askableTargets;
    final selected = state.selectedTargetId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '🎲 دورك تسأل',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اختار لاعب واسأله سؤال عن الكلمة — بلا ما تقولها.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, height: 1.5),
        ),
        const SizedBox(height: 20),
        SectionTitle('اسأل مين؟'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final player in targets)
              _TargetChip(
                player: player,
                selected: player.id == selected,
                onTap: _sent ? null : () => cubit.selectTarget(player.id),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          enabled: !_sent,
          maxLength: 140,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: const InputDecoration(
            hintText: 'مثلاً: بتلاقيه بحديقة حيوان؟',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _sent || selected == null ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(_sent ? 'انبعت — عم ننطر الجواب' : 'ابعت السؤال'),
        ),
        const SizedBox(height: 10),
        Text(
          'إذا خلص وقتك بلا سؤال، دورك بيروح — والصمت بيلفت النظر.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final SpyPlayer player;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: selected
          ? palette.primary.withValues(alpha: 0.16)
          : palette.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? palette.primary : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerAvatar(
                username: player.username,
                photoUrl: player.photoUrl,
                avatarId: player.avatarId,
                gender: Gender.parse(player.gender),
                size: 30,
              ),
              const SizedBox(width: 8),
              Text(
                player.username,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? palette.primary : palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
