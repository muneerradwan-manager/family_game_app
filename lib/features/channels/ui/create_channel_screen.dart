import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../cubit/channels_cubit.dart';
import '../model/channel.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  bool _busy = false;
  Channel? _created;
  String? _photoUrl;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await pickPhoto(context, allowRemove: _photoUrl != null);

    if (picked != null && mounted) setState(() => _photoUrl = picked.url);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final channel = await context.read<ChannelsCubit>().create(
      name: _name.text.trim(),
      photoUrl: _photoUrl,
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      _created = channel;
    });

    if (channel == null) {
      final error = context.read<ChannelsCubit>().state.error;

      if (error != null) {
        showAppSnack(context, error, isError: true);
        context.read<ChannelsCubit>().clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    // على الشاشة العريضة: النموذج وبجانبه شرح القنوات، بدل نموذج وحيد تائه.
    final split = MediaQuery.sizeOf(context).width >= 860;

    final main = created == null
        ? SectionCard(padding: const EdgeInsets.all(24), child: _form())
        : _invite(created);

    return Scaffold(
      body: ListView(
        padding: context.pagePadding(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    leading: const AppBackButton(),
                    title: created == null ? 'قناة جديدة' : 'القناة جاهزة 🎉',
                    subtitle: created == null
                        ? 'القناة هي مجموعة العيلة أو الشباب اللي بتلعبوا فيها'
                        : 'ابعت الرمز لأهل العيلة حتى ينضموا',
                  ),
                  const SizedBox(height: 24),
                  if (split)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: main),
                        const SizedBox(width: 20),
                        const Expanded(flex: 5, child: _HowItWorks()),
                      ],
                    )
                  else
                    main,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ChannelPhotoPicker(
            photoUrl: _photoUrl,
            onTap: _pickPhoto,
            size: 96,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'صورة القناة (اختياري)',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم القناة',
            hintText: 'مثلاً: عيلة أبو أحمد',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          validator: (value) =>
              (value ?? '').trim().length < 2 ? 'اكتب اسم القناة' : null,
          onFieldSubmitted: (_) => _create(),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('أنشئ القناة'),
        ),
      ],
    ),
  );

  Widget _invite(Channel channel) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InviteCodeCard(channel: channel),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => context.pushReplacement('/channels/${channel.id}'),
        child: const Text('روح على القناة'),
      ),
    ],
  );
}

/// شرح القنوات بجانب النموذج على الشاشة العريضة.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: context.palette.headerGradient,
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🎲', style: TextStyle(fontSize: 40)),
        SizedBox(height: 10),
        Text(
          'كيف بتشتغل القنوات؟',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 20),
        _Step(number: 1, title: 'أنشئ القناة', subtitle: 'اسم وصورة — بثواني'),
        _Step(
          number: 2,
          title: 'ابعت الرمز',
          subtitle: 'كل واحد بينضم برمز من 6 خانات',
        ),
        _Step(
          number: 3,
          title: 'العبوا سوا',
          subtitle: 'أي حدا بيفتح غرفة والباقيين بينضموا لحظياً',
        ),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// رمز الدعوة مع نسخ ومشاركة — طريق الانضمام الوحيد في النسخة الأولى.
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({super.key, required this.channel, this.onRegenerate});

  final Channel channel;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: 'رمز الدعوة',
      subtitle: 'ابعته لأهل القناة حتى ينضموا',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: palette.outline),
            ),
            alignment: Alignment.center,
            child: SelectableText(
              channel.inviteCode,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
                color: palette.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: channel.inviteCode),
                    );

                    if (context.mounted) showAppSnack(context, 'انتسخ الرمز');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          'انضم لقناة «${channel.name}» بتطبيق ألعاب العيلة!\n'
                          'الرمز: ${channel.inviteCode}\n${channel.inviteLink}',
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('مشاركة'),
                ),
              ),
            ],
          ),
          if (onRegenerate != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              // إعادة التوليد تبطل الرابط القديم فوراً إن تسرّب.
              label: const Text('توليد رمز جديد'),
            ),
          ],
        ],
      ),
    );
  }
}
