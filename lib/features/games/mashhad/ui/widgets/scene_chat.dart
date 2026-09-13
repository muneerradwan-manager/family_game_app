import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';

/// المشهد الحي: شات الجميع + أحداثي المفاجئة + بطاقة هدفي.
///
/// الهدف يبقى ظاهراً فوق الشات طوال المشهد ولا يُطوى: ثلاث دقائق من الحوار
/// المتسارع كافية لينسى اللاعب ما جاء يفعله.
class SceneChat extends StatefulWidget {
  const SceneChat({super.key, required this.round});

  final MashhadRound round;

  @override
  State<SceneChat> createState() => _SceneChatState();
}

class _SceneChatState extends State<SceneChat> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    context.read<MashhadGameCubit>().say(text);
    _controller.clear();
  }

  /// الرسالة الجديدة تُنزل القائمة — وإلا صار على اللاعب أن يطارد الحوار
  /// بإبهامه بينما الوقت يجري.
  void _stickToBottom() {
    if (widget.round.transcript.length == _lastCount) return;

    _lastCount = widget.round.transcript.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MashhadGameCubit>();
    final palette = context.palette;
    final round = widget.round;

    _stickToBottom();

    return Column(
      children: [
        _GoalStrip(role: round.myRole, events: round.myEvents),
        Expanded(
          child: round.transcript.isEmpty
              ? const Center(
                  child: EmptyState(
                    emoji: '🎬',
                    title: 'المشهد بلّش',
                    subtitle: 'أول واحد يحكي بيحرّك القصة.',
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: context.contentPadding(
                    top: 14,
                    bottom: 14,
                    minHorizontal: 16,
                    maxWidth: ContentWidth.standard,
                  ),
                  itemCount: round.transcript.length,
                  itemBuilder: (context, index) => _Bubble(
                    message: round.transcript[index],
                    isMine: round.transcript[index].userId == cubit.viewerId,
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: context.contentPadding(
              top: 0,
              bottom: 8,
              minHorizontal: 16,
            ),
            child: cubit.canSay
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLength: 300,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'احكي...',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
                  )
                : Text(
                    'إنت عم تتفرّج — بتقدر تقرأ المشهد بس.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
          ),
        ),
      ],
    );
  }
}

/// شريط ثابت: هدفي وأحداثي — لا يراه غيري.
class _GoalStrip extends StatelessWidget {
  const _GoalStrip({required this.role, required this.events});

  final MyRole? role;
  final List<SceneEvent> events;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (role == null && events.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: palette.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ContentShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (role != null)
              Row(
                children: [
                  Text(
                    '🎭 ${role!.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      role!.goal,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            for (final event in events) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: (event.isPrivate ? palette.accent : palette.secondary)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: event.isPrivate
                        ? palette.accent
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      event.isPrivate ? '🤫' : '⚡',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.text,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (event.isPrivate)
                      Text(
                        'إلك وحدك',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final SceneMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              // اسم الشخصية بجانب اسم اللاعب: بعد دقيقتين ينسى الجميع من
              // يمثّل مَن، وهذا يُفقد المشهد نصفه.
              message.role == null
                  ? message.username
                  : '${message.username} · ${message.role}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isMine ? palette.primary : palette.textMuted,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine
                  ? palette.primary.withValues(alpha: 0.14)
                  : palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMine ? Colors.transparent : palette.outline,
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
