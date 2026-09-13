import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../cubit/hadaf_game_cubit.dart';

/// ⚡ الجواب السريع — القرار الوحيد الذي يملكه اللاعب.
///
/// زر يُفعَّل قبل الاختيار لا بعده: المخاطرة يجب أن تكون قراراً واعياً، وسقفها
/// في الجلسة هو ما يجعلها قراراً أصلاً. لو كانت تلقائية لعاقبت السريعَ غصباً
/// عنه، ولو كانت بلا سقف لاستُعملت في كل جولة فما عادت مخاطرة.
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

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: armed ? palette.accent : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? cubit.toggleRisk : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: armed ? palette.accent : palette.outline,
                width: armed ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⚡', style: TextStyle(fontSize: armed ? 20 : 18)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      armed ? 'مفعّل — اختار بثقة!' : 'جواب سريع',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: armed ? Colors.white : palette.textPrimary,
                      ),
                    ),
                    Text(
                      armed ? 'صح ×2 · غلط خصم' : 'باقي $left',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: armed
                            ? Colors.white.withValues(alpha: 0.9)
                            : palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
