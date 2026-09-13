import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../cubit/auth_cubit.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();

    // سبب الخروج (جلسة انتهت، حساب موقوف) يُضبط قبل أن تُفتح هذه الشاشة،
    // فلا يلتقطه المستمع — نعرضه مرة عند الفتح.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final error = mounted ? context.read<AuthCubit>().state.error : null;

      if (error != null) showAppSnack(context, error, isError: true);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    await context.read<AuthCubit>().login(
      phone: _phone.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final split = AuthLayout.isSplit(context);

    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (previous, current) => previous.error != current.error,
        listener: (context, state) {
          if (state.error != null) {
            showAppSnack(context, state.error!, isError: true);
          }
        },
        builder: (context, state) => AuthLayout(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // على الشاشة الكبيرة لوحة التعريف بجانب النموذج، فلا نكرّر
                // الشعار فوقه.
                if (!split) ...[
                  const Center(child: GradientMark(emoji: '🎲', size: 84)),
                  const SizedBox(height: 18),
                  Text(
                    'ألعاب العيلة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'العبوا سوا وانتو بعيدين',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'أهلاً فيك من جديد 👋',
                    style: TextStyle(color: palette.textMuted),
                  ),
                  const SizedBox(height: 28),
                ],
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '07XXXXXXXX',
                    hintTextDirection: TextDirection.ltr,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    errorText: state.fieldErrors['phone'],
                  ),
                  validator: (value) => (value ?? '').trim().length < 7
                      ? 'اكتب رقم هاتف صحيح'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة السر',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    errorText: state.fieldErrors['password'],
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => (value ?? '').length < 6
                      ? 'كلمة السر 6 خانات على الأقل'
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.busy ? null : _submit,
                  child: state.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('دخول'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'ما عندك حساب؟',
                      style: TextStyle(color: palette.textMuted),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('سجّل حساب جديد'),
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
