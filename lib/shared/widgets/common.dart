import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/model/app_user.dart';
import '../avatars.dart';
import 'responsive.dart';

/// صورة اللاعب: صورة مرفوعة، أو أفاتار مختار، أو أفاتار مشتق من اسمه.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.username,
    this.photoUrl,
    this.avatarId,
    this.gender = Gender.male,
    this.size = 44,
    this.dimmed = false,
  });

  final String username;
  final String? photoUrl;
  final String? avatarId;
  final Gender gender;
  final double size;

  /// للاعب غادر: حاضر في اللوحة لكن ليس في اللعبة.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarById(avatarId) ?? fallbackAvatar(username, gender);

    final child = photoUrl != null && photoUrl!.isNotEmpty
        ? ClipOval(
            child: Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _emoji(avatar),
            ),
          )
        : _emoji(avatar);

    return Opacity(opacity: dimmed ? 0.45 : 1, child: child);
  }

  Widget _emoji(AvatarChoice avatar) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: avatar.color.withValues(alpha: 0.18),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(avatar.emoji, style: TextStyle(fontSize: size * 0.52)),
  );
}

/// ترويسة بتدرّج الثيم — أوضح ما يميّز ثيماً عن آخر.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      // التدرّج يمتد لعرض الشاشة، والمحتوى يتوسّط فوقه: عنوان وحيد على يمين
      // شاشة عريضة يترك نصفها فارغاً ويبدو منسياً.
      child: ContentShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ?leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (child != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: child!),
          ],
        ),
      ),
    );
  }
}

/// البطاقة الأساسية في كل الشاشات.
///
/// مبنية على Material لا على Container ملوّن: ListTile وInkWell يرسمان
/// خلفيتهما وأثر اللمس على أقرب Material فوقهما، فصندوق ملوّن بينهما يخفيهما
/// (وFlutter يرمي تأكيداً على ذلك). ولهذا أيضاً تستقبل البطاقة onTap بنفسها
/// بدل أن تُلَفّ بـ InkWell من الخارج.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(20);

    final content = Padding(
      padding: padding ?? const EdgeInsets.all(18),
      child: child,
    );

    return Material(
      color: color ?? palette.surface,
      // clipBehavior حتى لا يتجاوز أثر اللمس زوايا البطاقة.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.outline),
      ),
      child: SizedBox(
        width: double.infinity,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              message!,
              style: TextStyle(color: context.palette.textMuted),
            ),
          ),
      ],
    ),
  );
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '😕',
            style: TextStyle(fontSize: 44, color: context.palette.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textPrimary, fontSize: 16),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('جرّب مرة ثانية'),
            ),
          ],
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
  });

  final String emoji;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textMuted, height: 1.5),
          ),
        ],
      ],
    ),
  );
}

/// شارة صغيرة (عدد جولات، مستوى صعوبة، حالة).
class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.palette.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// حشوات آمنة أسفل الشاشة.
///
/// من Android 15 صار الرسم من حافة لحافة إجبارياً: التطبيق يرسم **تحت** شريط
/// تنقّل النظام، فآخر عنصر في أي قائمة يختفي وراءه. وشريط الأزرار الثلاثة في
/// النسخ الأقدم يفعل الشيء نفسه.
extension SafeBottomInsets on BuildContext {
  /// ارتفاع شريط التنقّل (أو شريط الإيماءات) الذي يغطّي أسفل الشاشة.
  ///
  /// نستخدم `paddingOf` لا `viewPaddingOf` عن قصد: إن كان في الشجرة SafeArea
  /// استهلك هذه المسافة فعلاً، تعود صفراً هنا فلا تُحسب مرتين.
  double get bottomInset => MediaQuery.paddingOf(this).bottom;

  /// حشوة قائمة: تتخطى شريط التنقّل، وتوسّط المحتوى على الشاشات العريضة.
  ///
  /// نزيد الحشوة بدل قصّ القائمة بـ SafeArea أو لفّها بـ ConstrainedBox: هكذا
  /// يمرّ المحتوى من تحت شريط التنقّل أثناء التمرير — وهو مقصود في التصميم من
  /// حافة لحافة — ويبقى شريط التمرير على حافة الشاشة وإيماءة التمرير تُلتقط
  /// من أي مكان، لا من العمود الأوسط وحده.
  EdgeInsets listPadding({
    double top = 20,
    double bottom = 24,
    double minHorizontal = 20,
    double maxWidth = ContentWidth.standard,
  }) {
    final side = sideGutter(maxWidth: maxWidth, minimum: minHorizontal);

    return EdgeInsets.fromLTRB(side, top, side, bottom + bottomInset);
  }
}

void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        duration: const Duration(seconds: 3),
      ),
    );
}
