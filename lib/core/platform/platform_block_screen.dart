import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/app_version.dart';
import '../theme/app_theme.dart';
import 'platform_cubit.dart';

/// شاشة تغطي التطبيق كله: صيانة أو تحديث إجباري.
///
/// تُرسم فوق الموجّه لا بدلاً منه، فحين يرفع المشرف الصيانة يعود المستخدم
/// إلى الشاشة التي كان عليها نفسها لا إلى البداية.
class PlatformBlockScreen extends StatefulWidget {
  const PlatformBlockScreen({super.key, required this.state});

  final PlatformState state;

  @override
  State<PlatformBlockScreen> createState() => _PlatformBlockScreenState();
}

class _PlatformBlockScreenState extends State<PlatformBlockScreen> {
  bool _checking = false;
  bool _copied = false;

  Future<void> _retry() async {
    setState(() => _checking = true);

    await context.read<PlatformCubit>().refresh();

    if (mounted) setState(() => _checking = false);
  }

  Future<void> _copyStoreUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));

    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = widget.state;
    final maintenance = state.block == PlatformBlock.maintenance;

    final message = state.message.isNotEmpty
        ? state.message
        : maintenance
        ? 'عم نحسّن التطبيق — ارجعلنا بعد شوي.'
        : 'في نسخة جديدة من التطبيق — حدّثه لتكمل.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: palette.headerGradient,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        maintenance ? '🛠️' : '📲',
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    maintenance ? 'التطبيق بالصيانة' : 'لازم تحدّث التطبيق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 15.5,
                      height: 1.6,
                    ),
                  ),
                  if (!maintenance && state.minVersion != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'نسختك $appVersion · المطلوبة ${state.minVersion} أو أحدث',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  if (!maintenance && state.storeUrl != null) ...[
                    const SizedBox(height: 22),
                    SelectableText(
                      state.storeUrl!,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: palette.primary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _copyStoreUrl(state.storeUrl!),
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                      label: Text(
                        _copied ? 'انتسخ الرابط' : 'انسخ رابط التحديث',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _checking ? null : _retry,
                    child: _checking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(maintenance ? 'جرّب هلق' : 'حدّثته — كمّل'),
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
