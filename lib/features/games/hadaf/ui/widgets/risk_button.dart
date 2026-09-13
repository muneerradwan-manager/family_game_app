import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../cubit/hadaf_game_cubit.dart';

/// ⚡ الجواب السريع — القرار الوحيد الذي يملكه اللاعب.
///
/// زر يُفعَّل قبل الاختيار لا بعده: المخاطرة يجب أن تكون قراراً واعياً، وسقفها
/// في الجلسة هو ما يجعلها قراراً أصلاً. لو كانت تلقائية لعاقبت السريعَ غصباً
/// عنه، ولو كانت بلا سقف لاستُعملت في كل جولة فما عادت مخاطرة.
///
/// مفعّلاً يمتلئ بلون التنبيه كله: حالة تغيّر معنى الضغطة التالية يجب ألا
/// تُفوَّت بطرف العين.
class RiskButton extends StatelessWidget {
  const RiskButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HadafGameCubit>();
    final state = context.watch<HadafGameCubit>().state;
    final palette = context.palette;
    final left = state.snapshot?.me.risksLeft ?? 0;
    final armed = state.riskArmed;
    final enabled = cubit.canArmRisk || armed;
    final radius = BorderRadius.circular(AppRadius.card);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: armed ? palette.accent : palette.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: armed
                ? palette.accent
                : palette.accent.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: enabled ? cubit.toggleRisk : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: armed
                        ? Colors.white.withValues(alpha: 0.22)
                        : palette.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('⚡', style: TextStyle(fontSize: armed ? 20 : 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        armed ? 'مفعّل — اختار بثقة!' : 'جواب سريع',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: armed ? Colors.white : palette.textPrimary,
                        ),
                      ),
                      Text(
                        armed ? 'صح ×2 · غلط خصم' : 'باقي $left',
                        style: TextStyle(
                          fontSize: 12,
                          color: armed
                              ? Colors.white.withValues(alpha: 0.9)
                              : palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  armed ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
                  size: 34,
                  color: armed ? Colors.white : palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
