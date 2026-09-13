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

    return SectionCard(
      title: '🎲 دورك تسأل',
      subtitle: 'اختار لاعب واسأله سؤال عن الكلمة — بلا ما تقولها.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('اسأل مين؟'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final player in targets)
                _TargetChip(
                  player: player,
                  selected: player.id == selected,
                  onTap: _sent ? null : () => cubit.selectTarget(player.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 12),
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
      ),
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
    final radius = BorderRadius.circular(999);

    return Material(
      color: selected
          ? palette.primary.withValues(alpha: 0.12)
          : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? palette.primary : palette.outline,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
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
                  fontWeight: FontWeight.w700,
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
