import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/image_upload_service.dart';
import '../../../core/platform/platform_cubit.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/avatars.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../cubit/auth_cubit.dart';
import '../data/auth_repository.dart';
import '../model/app_user.dart';
import 'auth_layout.dart';

/// التسجيل على خطوتين: الحساب أولاً ثم البروفايل.
///
/// خطوة واحدة طويلة تُنفّر، والسيرفر ينشئ الحساب بطلب واحد على أي حال، فنجمع
/// كل شيء ثم نرسله دفعة واحدة عند نهاية الخطوة الثانية.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _accountKey = GlobalKey<FormState>();
  final _profileKey = GlobalKey<FormState>();

  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _recoveryEmail = TextEditingController();

  int _step = 0;
  bool _obscure = true;
  Gender _gender = Gender.male;
  String? _avatarId;

  /// الصورة تُختار الآن وتُرفع بعد إنشاء الحساب: لا توكن قبله.
  XFile? _photo;

  Timer? _usernameDebounce;
  String? _usernameHint;
  bool? _usernameAvailable;

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _phone.dispose();
    _password.dispose();
    _fullName.dispose();
    _username.dispose();
    _recoveryEmail.dispose();
    super.dispose();
  }

  /// فحص لحظي بدل اكتشاف أن الاسم محجوز بعد ملء النموذج كله.
  void _onUsernameChanged() {
    _usernameDebounce?.cancel();

    final value = _username.text.trim();

    if (value.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _usernameHint = null;
      });

      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await context.read<AuthRepository>().checkUsername(
          value,
        );

        if (!mounted) return;

        setState(() {
          _usernameAvailable = result.available;
          _usernameHint = result.message;
        });
      } catch (_) {
        // فحص تجميلي: التحقق الحقيقي يجري عند الإرسال.
      }
    });
  }

  void _next() {
    if (!_accountKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!_profileKey.currentState!.validate()) return;
    if (_usernameAvailable == false) return;

    FocusScope.of(context).unfocus();

    final auth = context.read<AuthCubit>();
    final uploads = context.read<ImageUploadService>();

    final created = await auth.register(
      phone: _phone.text.trim(),
      password: _password.text,
      fullName: _fullName.text.trim(),
      username: _username.text.trim(),
      gender: _gender,
      avatarId: _avatarId,
      recoveryEmail: _recoveryEmail.text.trim(),
    );

    // الصورة بعد الحساب: فشل رفعها لا يُبطل تسجيلاً نجح — الأفاتار جاهز بديلاً.
    if (created && _photo != null) {
      try {
        await auth.updateProfile({'photoUrl': await uploads.upload(_photo!)});
      } catch (_) {
        if (mounted) showAppSnack(context, 'انحفظ حسابك، بس الصورة ما انرفعت.');
      }
    }

    if (!created && mounted) {
      final errors = context.read<AuthCubit>().state.fieldErrors;

      // خطأ في بيانات الخطوة الأولى: نرجع المستخدم إليها بدل رسالة غامضة.
      if (errors.containsKey('phone') || errors.containsKey('password')) {
        setState(() => _step = 0);
      }
    }
  }

  void _back() =>
      _step == 1 ? setState(() => _step = 0) : Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (previous, current) => previous.error != current.error,
        listener: (context, state) {
          if (state.error != null) {
            showAppSnack(context, state.error!, isError: true);
          }
        },
        builder: (context, state) => AuthLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppBackButton(onPressed: _back),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 0 ? 'حساب جديد' : 'عرّفنا عليك',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          'الخطوة ${_step + 1} من 2',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _StepBar(step: _step),
              const SizedBox(height: 16),
              _step == 0 ? _accountStep(state) : _profileStep(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountStep(AuthState state) {
    final platform = context.watch<PlatformCubit>().state;

    return Form(
      key: _accountKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // المشرف أغلق التسجيل: نقولها قبل أن يملأ المستخدم النموذج لا بعده.
          if (!platform.registrationEnabled) ...[
            SectionCard(
              color: context.palette.accent.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: context.palette.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      platform.registrationMessage.isNotEmpty
                          ? platform.registrationMessage
                          : 'التسجيل مسكّر حالياً.',
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
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
            validator: (value) =>
                (value ?? '').trim().length < 7 ? 'اكتب رقم هاتف صحيح' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              helperText: '6 خانات على الأقل',
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
            validator: (value) =>
                (value ?? '').length < 6 ? 'كلمة السر 6 خانات على الأقل' : null,
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: platform.registrationEnabled ? _next : null,
            child: const Text('التالي'),
          ),
        ],
      ),
    );
  }

  Widget _photoCircle(AppPalette palette) => GestureDetector(
    onTap: () async {
      final picked = await pickPhotoFile(context);

      if (picked != null && mounted) setState(() => _photo = picked);
    },
    child: Stack(
      alignment: AlignmentDirectional.bottomEnd,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: palette.outline, width: 2),
            image: _photo == null
                ? null
                : DecorationImage(
                    image: FileImage(File(_photo!.path)),
                    fit: BoxFit.cover,
                  ),
          ),
          alignment: Alignment.center,
          child: _photo != null
              ? null
              : Icon(
                  Icons.add_a_photo_outlined,
                  size: 32,
                  color: palette.textMuted,
                ),
        ),
        if (_photo != null)
          GestureDetector(
            onTap: () => setState(() => _photo = null),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 2),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
      ],
    ),
  );

  Widget _profileStep(AuthState state) {
    final palette = context.palette;
    final options = avatarsFor(_gender);

    return Form(
      key: _profileKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'الاسم الثلاثي',
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: state.fieldErrors['fullName'],
            ),
            validator: (value) =>
                (value ?? '').trim().length < 3 ? 'اكتب اسمك الثلاثي' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _username,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              labelText: 'اسم المستخدم',
              // إنجليزي فقط حتى لا يلتبس التشكيل والتشابه العربي عند البحث والدعوة.
              helperText: _usernameHint ?? 'أحرف إنجليزية صغيرة وأرقام و _ فقط',
              helperStyle: TextStyle(
                color: switch (_usernameAvailable) {
                  true => const Color(0xFF2E7D32),
                  false => Theme.of(context).colorScheme.error,
                  null => palette.textMuted,
                },
              ),
              prefixIcon: const Icon(Icons.alternate_email),
              suffixIcon: switch (_usernameAvailable) {
                true => const Icon(
                  Icons.check_circle,
                  color: Color(0xFF2E7D32),
                ),
                false => Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                null => null,
              },
              errorText: state.fieldErrors['username'],
            ),
            validator: (value) => (value ?? '').trim().length < 3
                ? 'اسم المستخدم 3 خانات على الأقل'
                : null,
          ),
          const SizedBox(height: 18),
          Text(
            'الجنس',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<Gender>(
            segments: const [
              ButtonSegment(
                value: Gender.male,
                label: Text('ذكر'),
                icon: Icon(Icons.man),
              ),
              ButtonSegment(
                value: Gender.female,
                label: Text('أنثى'),
                icon: Icon(Icons.woman),
              ),
            ],
            selected: {_gender},
            onSelectionChanged: (selection) => setState(() {
              _gender = selection.first;
              // الأفاتار المختار قد لا يناسب الجنس الجديد.
              if (avatarById(_avatarId)?.gender != null) _avatarId = null;
            }),
          ),
          const SizedBox(height: 22),
          Center(child: _photoCircle(palette)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: palette.outline, endIndent: 12)),
              Text(
                'أو اختار أفاتار',
                style: TextStyle(color: palette.textMuted, fontSize: 13),
              ),
              Expanded(child: Divider(color: palette.outline, indent: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final avatar in options)
                GestureDetector(
                  onTap: () => setState(() {
                    _avatarId = avatar.id;
                    _photo = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _avatarId == avatar.id
                            ? palette.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: avatar.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 27),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _recoveryEmail,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'إيميل الاستعادة (اختياري)',
              // بلا تحقق SMS، هذا هو السبيل الوحيد لاستعادة حساب نُسيت كلمة سره.
              helperText: 'لاستعادة الحساب لو نسيت كلمة السر',
              prefixIcon: const Icon(Icons.mail_outline),
              errorText: state.fieldErrors['recoveryEmail'],
            ),
            validator: (value) {
              final text = (value ?? '').trim();

              if (text.isEmpty) return null;

              return text.contains('@') && text.contains('.')
                  ? null
                  : 'إيميل غير صحيح';
            },
          ),
          const SizedBox(height: 26),
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
                : const Text('يلا نبلّش'),
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          for (var index = 0; index < 2; index++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  color: index <= step ? palette.primary : palette.outline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (index == 0) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
