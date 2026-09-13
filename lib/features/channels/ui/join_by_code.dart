import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/responsive.dart';
import '../cubit/channels_cubit.dart';

/// الانضمام لقناة برمز — من الرئيسية أو من الشريط الجانبي.
///
/// على الجوال ورقة من الأسفل حيث الإبهام، وعلى الشاشات الأكبر نافذة في
/// الوسط: ورقة بعرض شاشة كبيرة تبدو شريطاً لا نافذة.
Future<void> joinChannelByCode(BuildContext context) async {
  final code = context.isPhone
      ? await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _JoinByCodeForm(),
        )
      : await showDialog<String>(
          context: context,
          builder: (_) => Dialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: _JoinByCodeForm(inDialog: true),
            ),
          ),
        );

  if (code == null || code.trim().isEmpty || !context.mounted) return;

  final cubit = context.read<ChannelsCubit>();
  final channel = await cubit.joinByCode(code);

  if (!context.mounted) return;

  if (channel != null) {
    context.push('/channels/${channel.id}');

    return;
  }

  final error = cubit.state.error;

  if (error != null) {
    showAppSnack(context, error, isError: true);
    cubit.clearError();
  }
}

class _JoinByCodeForm extends StatefulWidget {
  const _JoinByCodeForm({this.inDialog = false});

  final bool inDialog;

  @override
  State<_JoinByCodeForm> createState() => _JoinByCodeFormState();
}

class _JoinByCodeFormState extends State<_JoinByCodeForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // viewInsets للكيبورد، و bottomInset لشريط تنقّل النظام. الأول يصفّر
    // الثاني حين يفتح الكيبورد، فأخذ الأكبر منهما هو الصحيح لا جمعهما.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final padding = widget.inDialog
        ? const EdgeInsets.all(24)
        : EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + (keyboard > 0 ? keyboard : context.bottomInset),
          );

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GradientMark(icon: Icons.vpn_key_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انضمام برمز دعوة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      'اكتب الرمز اللي وصلك من أهل القناة',
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            style: const TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(hintText: 'ABC123'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('انضم'),
          ),
        ],
      ),
    );
  }
}
