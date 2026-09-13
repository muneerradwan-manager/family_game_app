import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/responsive.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(created == null ? 'قناة جديدة' : 'جاهزة!')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.listPadding(
            top: 16,
            bottom: 32,
            minHorizontal: 24,
            maxWidth: ContentWidth.form,
          ),
          child: created == null ? _form() : _invite(created),
        ),
      ),
    );
  }

  Widget _form() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'شو بدك تسمّي القناة؟',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'مثلاً: عيلة أبو أحمد · أولاد العم · الشباب',
          style: TextStyle(color: context.palette.textMuted),
        ),
        const SizedBox(height: 24),
        Center(
          child: ChannelPhotoPicker(photoUrl: _photoUrl, onTap: _pickPhoto),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم القناة',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          validator: (value) =>
              (value ?? '').trim().length < 2 ? 'اكتب اسم القناة' : null,
          onFieldSubmitted: (_) => _create(),
        ),
        const SizedBox(height: 26),
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

  Widget _invite(Channel channel) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(child: Text('🎉', style: const TextStyle(fontSize: 54))),
        const SizedBox(height: 14),
        Text(
          'تم إنشاء «${channel.name}»',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ابعت الرمز لأهل العيلة حتى ينضموا',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted),
        ),
        const SizedBox(height: 26),
        InviteCodeCard(channel: channel),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => context.pushReplacement('/channels/${channel.id}'),
          child: const Text('روح على القناة'),
        ),
      ],
    );
  }
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
      child: Column(
        children: [
          Text(
            'رمز الدعوة',
            style: TextStyle(color: palette.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            channel.inviteCode,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 16),
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
                  icon: const Icon(Icons.copy, size: 18),
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
                  icon: const Icon(Icons.share, size: 18),
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
