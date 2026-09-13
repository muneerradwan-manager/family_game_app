import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/common.dart';
import '../../../../../shared/widgets/responsive.dart';
import '../../../../auth/model/app_user.dart';
import '../../cubit/mashhad_game_cubit.dart';
import '../../model/mashhad_models.dart';
import 'mashhad_layout.dart';

/// المشهد الحي: شات الجميع + أحداثي المفاجئة + بطاقة هدفي.
///
/// الهدف يبقى ظاهراً فوق الشات طوال المشهد ولا يُطوى: ثلاث دقائق من الحوار
/// المتسارع كافية لينسى اللاعب ما جاء يفعله. على الشاشة العريضة ([split])
/// ينتقل الهدف والأحداث إلى العمود الجانبي، ويأخذ الشات العمود كله.
class SceneChat extends StatefulWidget {
  const SceneChat({super.key, required this.round, this.split = false});

  final MashhadRound round;
  final bool split;

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
    final snapshot = cubit.state.snapshot;
    final palette = context.palette;
    final round = widget.round;
    final transcript = round.transcript;

    _stickToBottom();

    // حقل الكتابة ومحتوى الرسائل بعرض واحد: العين لا تقفز بين عمودين.
    EdgeInsets padding({required double top, required double bottom}) =>
        mashhadMainPadding(
          context,
          split: widget.split,
          top: top,
          bottom: bottom,
          maxWidth: ContentWidth.standard,
          // الشريط السفلي يحجز شريط التنقّل بنفسه.
          reserveInset: false,
        );

    return Column(
      children: [
        if (!widget.split)
          _GoalStrip(role: round.myRole, events: round.myEvents),
        Expanded(
          child: transcript.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      emoji: '🎬',
                      title: 'المشهد بلّش',
                      subtitle: 'أول واحد يحكي بيحرّك القصة.',
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final bubbleWidth = math.min(
                      520.0,
                      constraints.maxWidth * 0.75,
                    );

                    return ListView.builder(
                      controller: _scroll,
                      padding: padding(top: 16, bottom: 12),
                      itemCount: transcript.length,
                      itemBuilder: (context, index) {
                        final message = transcript[index];

                        // رسائل متتالية من الشخص نفسه كتلة واحدة: الاسم
                        // والصورة مرة واحدة يكفيان ويوفّران مساحة الحوار.
                        final firstOfGroup =
                            index == 0 ||
                            transcript[index - 1].userId != message.userId;

                        return _Bubble(
                          message: message,
                          isMine: message.userId == cubit.viewerId,
                          player: snapshot?.playerById(message.userId),
                          showName: firstOfGroup,
                          maxWidth: bubbleWidth,
                        );
                      },
                    );
                  },
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.outline)),
          ),
          // SafeArea دائماً: تحجز شريط تنقّل النظام حين تكون لوحة المفاتيح
          // مغلقة، وتعود صفراً حين تفتح لأن Scaffold يقلّص المساحة.
          child: SafeArea(
            top: false,
            child: Padding(
              padding: padding(top: 10, bottom: 10),
              child: cubit.canSay
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLength: 300,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'احكي...',
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: palette.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: _inputBorder(palette.outline),
                              enabledBorder: _inputBorder(palette.outline),
                              focusedBorder: _inputBorder(palette.primary),
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
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'إنت عم تتفرّج — بتقدر تقرأ المشهد بس.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(color: color),
  );
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
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ContentShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (role != null)
              Row(
                children: [
                  Flexible(flex: 0, child: InfoChip('🎭 ${role!.name}')),
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
            for (final (index, event) in events.indexed) ...[
              if (role != null || index > 0) const SizedBox(height: 8),
              SceneEventTile(event: event),
            ],
          ],
        ),
      ),
    );
  }
}

/// حدث مفاجئ — الخاص منه بحدّ ولون التنبيه، فلا يُخلط بالعام.
class SceneEventTile extends StatelessWidget {
  const SceneEventTile({super.key, required this.event});

  final SceneEvent event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = event.isPrivate ? palette.accent : palette.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: event.isPrivate
              ? palette.accent.withValues(alpha: 0.6)
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
          if (event.isPrivate) ...[
            const SizedBox(width: 8),
            Text(
              'إلك وحدك',
              style: TextStyle(
                color: palette.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    required this.player,
    required this.showName,
    required this.maxWidth,
  });

  final SceneMessage message;
  final bool isMine;
  final MashhadPlayer? player;
  final bool showName;
  final double maxWidth;

  static const _avatarSize = 30.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // الزاوية المدبّبة جهة المتكلّم: تُقرأ الفقاعة «خارجة» منه.
    final radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(16),
      topEnd: const Radius.circular(16),
      bottomStart: Radius.circular(isMine ? 16 : 4),
      bottomEnd: Radius.circular(isMine ? 4 : 16),
    );

    final bubble = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
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
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? palette.primary : palette.surface,
            borderRadius: radius,
            border: Border.all(
              color: isMine ? palette.primary : palette.outline,
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: isMine ? palette.onPrimary : palette.textPrimary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: showName ? 10 : 3),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            SizedBox(
              width: _avatarSize,
              child: showName
                  ? PlayerAvatar(
                      username: message.username,
                      photoUrl: player?.photoUrl,
                      avatarId: player?.avatarId,
                      gender: Gender.parse(player?.gender),
                      size: _avatarSize,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
