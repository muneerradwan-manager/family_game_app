import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// مرحلة الادّعاء: هل حقّقت هدفك؟
///
/// تُرسَل وأهدافك ما زالت سرّية عن غيرك — فلا أحد يبني ادّعاءه على ادّعائك،
/// ولا أحد يجاملك لأنه رأى ما كتبت.
class ClaimsCard extends StatefulWidget {
  const ClaimsCard({super.key, required this.round});

  final MashhadRound round;

  @override
  State<ClaimsCard> createState() => _ClaimsCardState();
}

class _ClaimsCardState extends State<ClaimsCard> {
  bool _main = false;
  bool _bonus = false;
  bool _event = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final palette = context.palette;
    final round = widget.round;
    final role = round.myRole;
    final locked = round.hasClaimed || !cubit.amPlaying;

    if (role == null) {
      return SectionCard(
        child: Column(
          children: [
            const Text('👀', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              'اللاعبين عم يقولوا شو حقّقوا',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: '⏰ انتهى المشهد!',
          subtitle: 'قول بصراحة شو حقّقت — الباقيين رح يشوفوا هدفك بعد شوي.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ClaimTile(
                emoji: '✅',
                label: 'هدفك الرئيسي',
                text: role.goal,
                tone: palette.primary,
                value: locked ? (round.myClaim?.main ?? false) : _main,
                locked: locked,
                onChanged: (value) => setState(() => _main = value),
              ),
              if (role.bonus != null) ...[
                const SizedBox(height: 10),
                _ClaimTile(
                  emoji: '⭐',
                  label: 'الهدف الإضافي',
                  text: role.bonus!,
                  tone: palette.secondary,
                  value: locked ? (round.myClaim?.bonus ?? false) : _bonus,
                  locked: locked,
                  onChanged: (value) => setState(() => _bonus = value),
                ),
              ],
              if (round.canClaimEvent) ...[
                const SizedBox(height: 10),
                _ClaimTile(
                  emoji: '⚡',
                  label: 'استغليت الحدث المفاجئ',
                  text: 'وصلك حدث خاص — استفدت منه؟',
                  tone: palette.accent,
                  value: locked ? (round.myClaim?.event ?? false) : _event,
                  locked: locked,
                  onChanged: (value) => setState(() => _event = value),
                ),
              ],
              const SizedBox(height: 18),
              if (locked)
                Column(
                  children: [
                    InfoChip(
                      'ادّعى ${round.claimedCount} من ${round.activeCount}',
                      icon: Icons.how_to_reg_outlined,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'سجّلنا ادّعاءك — عم ننطر الباقيين.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: () =>
                      cubit.claim(main: _main, bonus: _bonus, event: _event),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('أرسل'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'انتبه: إذا ادّعيت شي ما عملته وحدا اعترض وسقط ادّعاؤك — بتخسر نقاط.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// خيار ادّعاء: حدّ رفيع، ويتلوّن بلون الهدف حين يُختار.
class _ClaimTile extends StatelessWidget {
  const _ClaimTile({
    required this.emoji,
    required this.label,
    required this.text,
    required this.tone,
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final String text;
  final Color tone;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.control);

    return Material(
      color: value ? tone.withValues(alpha: 0.08) : palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: value ? tone : palette.outline,
          width: value ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: locked ? null : () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: tone,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                value ? Icons.check_circle : Icons.radio_button_unchecked,
                color: value ? tone : palette.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
