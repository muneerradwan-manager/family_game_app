import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/model/app_user.dart';
import '../avatars.dart';
import 'responsive.dart';

/// أزرار بعرض محتواها — لرأس الصفحة وأي صف أزرار.
///
/// أزرار الثيم تملأ سطرها افتراضياً (شاشات اللعب مبنية على ذلك)، وزر بعرض
/// غير محدود داخل صف يُسقط التخطيط.
class AppButtonStyle {
  const AppButtonStyle._();

  static const compact = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 42)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
  );
}

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

/// مربّع بتدرّج الثيم — «علامة» اللعبة أو القسم، كشعار لوحة الإدارة.
///
/// التدرّج صار لمسة في مربّع صغير لا ترويسة بعرض الشاشة: يبقى الثيم مميّزاً
/// والمحتوى هو ما يلفت النظر.
class GradientMark extends StatelessWidget {
  const GradientMark({
    super.key,
    this.emoji,
    this.icon,
    this.size = 44,
    this.radius,
  });

  final String? emoji;
  final IconData? icon;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: context.palette.headerGradient,
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
      borderRadius: BorderRadius.circular(radius ?? size * 0.28),
    ),
    alignment: Alignment.center,
    child: emoji != null
        ? Text(emoji!, style: TextStyle(fontSize: size * 0.5, height: 1.1))
        : Icon(
            icon ?? Icons.casino_outlined,
            color: Colors.white,
            size: size * 0.5,
          ),
  );
}

/// صورة القناة، أو أول حرف من اسمها على تدرّج الثيم.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first;

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.palette.headerGradient,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (photoUrl == null || photoUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// زر رجوع مربّع بحدّ — يظهر فقط حين يوجد ما يُرجع إليه.
///
/// صفحة فُتحت من الشريط الجانبي على الشاشة الكبيرة لا رجوع لها، وزر لا يفعل
/// شيئاً أسوأ من غيابه.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null && !Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: palette.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Tooltip(
              message: 'رجوع',
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// رأس الصفحة بأسلوب لوحة الإدارة: عنوان كبير، سطر وصف، وأزرار الصفحة.
///
/// على العرض الضيق تنزل الأزرار تحت العنوان وتتقاسم السطر، و[trailing]
/// (قائمة الخيارات مثلاً) يبقى بجانب العنوان في الحالتين.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;

        // mainAxisSize.min: الرأس يُوضع أحياناً في مساحة محدودة الارتفاع (جسم
        // Scaffold مباشرة)، وعمود بأقصى ارتفاع حينها يُنزل الأزرار لمنتصف
        // الشاشة بعيداً عن العنوان.
        final titles = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: narrow ? 21 : 25,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: palette.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: narrow ? 13.5 : 14.5,
                  height: 1.45,
                ),
              ),
            ],
          ],
        );

        final head = Row(
          children: [
            ?leading,
            Expanded(child: titles),
            if (!narrow && actions.isNotEmpty) ...[
              const SizedBox(width: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        );

        if (!narrow || actions.isEmpty) return head;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            head,
            const SizedBox(height: 14),
            Row(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(child: actions[index]),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// ترويسة بتدرّج الثيم.
///
/// الأسلوب القديم — لم تعد تُستخدم في الشاشات الجديدة (انظر [PageHeader]
/// و`SessionHeader`)، وتبقى حتى تنتقل كل شاشات الألعاب.
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
      ),
      child: ContentShell(
        maxWidth: ContentWidth.wide,
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

/// البطاقة الأساسية في كل الشاشات — كبطاقات لوحة الإدارة: سطح أبيض، حدّ
/// رفيع، ظل خفيف، ورأس اختياري بعنوان وزر مفصول بخط.
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
    this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  /// رأس البطاقة (`card-head` في لوحة الإدارة).
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.card);

    final body = Padding(
      padding: padding ?? const EdgeInsets.all(18),
      child: child,
    );

    final content = title == null
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              const Divider(height: 1),
              body,
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // البطاقة الملوّنة (تنبيه، ملاحظة) مسطّحة: الظل يليق بالسطح فقط.
        boxShadow: color == null ? AppShadows.card(palette) : null,
      ),
      child: Material(
        color: color ?? palette.surface,
        // clipBehavior حتى لا يتجاوز أثر اللمس زوايا البطاقة.
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: palette.outline),
        ),
        child: SizedBox(
          width: double.infinity,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, child: content),
        ),
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
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16.5,
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

/// بطاقة رقم — كبطاقات «نظرة عامة» في لوحة الإدارة.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.icon,
    this.tone,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? note;
  final IconData? icon;
  final Color? tone;

  /// ثلاث بطاقات في سطر جوال: بلا أيقونة وبرقم أصغر.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = tone ?? palette.primary;

    return SectionCard(
      padding: EdgeInsets.all(compact ? 12 : 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: compact ? 12 : 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFontFamily,
                    fontSize: compact ? 22 : 28,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                if (note != null && !compact)
                  Text(
                    note!,
                    style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          if (icon != null && !compact)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: palette.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15.5,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: AppButtonStyle.compact,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('جرّب مرة ثانية'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? action;

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
            fontWeight: FontWeight.w800,
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
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

/// شارة (عدد جولات، مستوى صعوبة، حالة) — كشارات لوحة الإدارة.
class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.palette.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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

  /// حشوة صفحة من صفحات اللوحة: هامش يكبر مع الشاشة، وعرض حتى
  /// [ContentWidth.wide] تملؤه الشبكات والأعمدة الجانبية.
  ///
  /// [top] يُضاف إلى ارتفاع شريط الحالة: الصفحات بلا AppBar.
  EdgeInsets pagePadding({double top = 24, double bottom = 32}) {
    final gutter = switch (formFactor) {
      FormFactor.desktop => 32.0,
      FormFactor.tablet => 24.0,
      FormFactor.phone => 16.0,
    };

    return listPadding(
      top: top + MediaQuery.paddingOf(this).top,
      bottom: bottom,
      minHorizontal: gutter,
      maxWidth: ContentWidth.wide,
    );
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
