import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../shared/avatars.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../../../shared/widgets/responsive.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/model/app_user.dart';

/// الإعدادات: الحساب والصوت في عمود جانبي، والثيمات شبكة في العمود الرئيسي.
///
/// الثيمات شبكة لا شريط أفقي: كلها ظاهرة معاً للمقارنة، ولا تمرير أفقي
/// يتعطّل بالماوس على سطح المكتب.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _soundEnabled = context.read<GameFeedback>().soundEnabled;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final palette = context.palette;

    return Scaffold(
      body: ListView(
        padding: context.pagePadding(),
        children: [
          const PageHeader(
            leading: AppBackButton(),
            title: 'الإعدادات',
            subtitle: 'حسابك وشكل التطبيق',
          ),
          const SizedBox(height: 24),
          TwoPane(
            sideWidth: 380,
            sideFirstWhenStacked: true,
            main: const _ThemesCard(),
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (user != null) ...[
                  _ProfileCard(user: user),
                  const SizedBox(height: 20),
                ],
                SectionCard(
                  title: 'الصوت',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _soundEnabled,
                    title: Text(
                      'أصوات اللعبة',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'تكّة العدّاد وصوت الستوب',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    onChanged: (value) async {
                      await context.read<GameFeedback>().setSoundEnabled(value);

                      if (mounted) setState(() => _soundEnabled = value);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.danger,
                    side: BorderSide(
                      color: palette.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  onPressed: () => context.read<AuthCubit>().logout(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      title: 'حسابي',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tooltip(
                message: 'غيّر الصورة',
                child: GestureDetector(
                  onTap: () => _changePhoto(context, user),
                  child: Stack(
                    alignment: AlignmentDirectional.bottomEnd,
                    children: [
                      PlayerAvatar(
                        username: user.username,
                        photoUrl: user.photoUrl,
                        avatarId: user.avatarId,
                        gender: user.gender,
                        size: 60,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.photo_camera,
                          size: 11,
                          color: palette.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                    if (user.phone != null)
                      Text(
                        user.phone!,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _editAvatar(context, user),
            icon: const Icon(Icons.face_retouching_natural, size: 18),
            label: const Text('غيّر الأفاتار'),
          ),
        ],
      ),
    );
  }

  /// الصورة تعلو الأفاتار في العرض، والأفاتار يبقى محفوظاً كما هو — فحذف
  /// الصورة يعيده بدل أن يترك المستخدم أمام دائرة فارغة.
  Future<void> _changePhoto(BuildContext context, AppUser user) async {
    final cubit = context.read<AuthCubit>();
    final picked = await pickPhoto(context, allowRemove: user.photoUrl != null);

    if (picked == null) return;

    await cubit.updateProfile({'photoUrl': picked.url});
  }

  Future<void> _editAvatar(BuildContext context, AppUser user) async {
    final cubit = context.read<AuthCubit>();

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'غيّر الأفاتار',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: sheetContext.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final avatar in avatarsFor(user.gender))
                    GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(avatar.id),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: avatar.color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatar.id == user.avatarId
                                ? sheetContext.palette.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          avatar.emoji,
                          style: const TextStyle(fontSize: 27),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (picked != null) await cubit.updateProfile({'avatarId': picked});
  }
}

/// اختيار الثيم — تفضيل شخصي محفوظ على الجهاز، يتغيّر التطبيق كله فوراً.
class _ThemesCard extends StatelessWidget {
  const _ThemesCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ThemeCubit>().state;

    return SectionCard(
      title: 'شكل التطبيق',
      subtitle: 'بيتغيّر التطبيق كله فوراً',
      child: ResponsiveGrid(
        minItemWidth: 150,
        maxColumns: 4,
        spacing: 12,
        children: [
          for (final palette in state.palettes)
            _ThemeTile(
              palette: palette,
              selected: palette.id == state.palette.id,
              current: state.palette,
            ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.palette,
    required this.selected,
    required this.current,
  });

  /// ثيم البطاقة نفسها — تُرسم بألوانها لتكون معاينة.
  final AppPalette palette;

  /// الثيم المفعّل — منه لون الحدّ.
  final AppPalette current;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? current.primary : current.outline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.read<ThemeCubit>().select(palette),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: palette.headerGradient),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                palette.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                palette.tagline,
                maxLines: 2,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Dot(color: palette.primary),
                  const SizedBox(width: 4),
                  _Dot(color: palette.secondary),
                  const SizedBox(width: 4),
                  _Dot(color: palette.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
