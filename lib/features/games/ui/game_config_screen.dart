import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/responsive.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/game_repository.dart';

/// شاشة شروط اللعبة.
///
/// تعرّفها كل لعبة لنفسها (configSchema) وتعرضها المنصّة بقالب موحّد:
/// قائمة منسدلة، أو اختيار من عدة، أو مفتاح تشغيل. اللعبة الثانية تحصل على
/// شاشة شروط جاهزة بلا سطر واجهة واحد.
///
/// على الشاشة العريضة: الحقول شبكة من عمودين، وبطاقة ملخّص جانبية فيها زر
/// فتح الغرفة — يبقى في مرمى العين بدل أن يُدفع لأسفل الصفحة.
class GameConfigScreen extends StatefulWidget {
  const GameConfigScreen({
    super.key,
    required this.channelId,
    required this.gameType,
  });

  final String channelId;
  final String gameType;

  @override
  State<GameConfigScreen> createState() => _GameConfigScreenState();
}

class _GameConfigScreenState extends State<GameConfigScreen> {
  late Future<GameCatalogEntry> _entry;
  final _values = <String, Object?>{};
  bool _opening = false;

  static const _splitWidth = 900.0;

  @override
  void initState() {
    super.initState();
    _entry = _loadEntry();
  }

  Future<GameCatalogEntry> _loadEntry() async {
    final games = await context.read<GameRepository>().catalog();
    final entry = games.firstWhere((game) => game.gameType == widget.gameType);

    for (final field in entry.configSchema) {
      _values[field.key] = field.defaultValue;
    }

    return entry;
  }

  Future<void> _openRoom() async {
    setState(() => _opening = true);

    try {
      final gameId = await context.read<GameRepository>().openRoom(
        channelId: widget.channelId,
        gameType: widget.gameType,
        config: Map<String, dynamic>.from(_values),
      );

      // النوع معروف هنا، فنمرّره ونوفّر على اللاعب طلب شبكة قبل أول شاشة.
      if (mounted) {
        context.pushReplacement('/games/$gameId?type=${widget.gameType}');
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final split = MediaQuery.sizeOf(context).width >= _splitWidth;

    return Scaffold(
      body: FutureBuilder<GameCatalogEntry>(
        future: _entry,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              padding: context.pagePadding(),
              children: [
                const PageHeaderSkeleton(),
                const SizedBox(height: 24),
                TwoPane(
                  breakpoint: _splitWidth - 100,
                  main: const FormCardSkeleton(fields: 3),
                  side: const GameCardSkeleton(),
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return AppErrorView(
              message: '${snapshot.error ?? 'ما لقينا هاللعبة.'}',
              onRetry: () => setState(() => _entry = _loadEntry()),
            );
          }

          final entry = snapshot.data!;

          final header = PageHeader(
            leading: const AppBackButton(),
            title: 'شروط ${entry.name}',
            subtitle: 'اضبط الشروط وافتح الغرفة لأهل القناة',
          );

          final fields = [
            for (final field in entry.configSchema)
              _ConfigFieldView(
                field: field,
                value: _values[field.key],
                // الوضع المرن يفرض أعمدته ووقته، فيُخفي ما لا معنى له معه.
                disabled:
                    _values['flexibleMode'] == true &&
                    (field.key == 'sixthColumn' || field.key == 'writeSeconds'),
                onChanged: (value) =>
                    setState(() => _values[field.key] = value),
              ),
          ];

          final openButton = FilledButton.icon(
            onPressed: _opening ? null : _openRoom,
            icon: _opening
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.meeting_room_outlined),
            label: const Text('افتح الغرفة'),
          );

          if (split) {
            return ListView(
              padding: context.pagePadding(),
              children: [
                header,
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ResponsiveGrid(
                        minItemWidth: 300,
                        maxColumns: 2,
                        children: fields,
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 360,
                      child: _SummaryCard(entry: entry, button: openButton),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: context.contentPadding(
                    top: MediaQuery.paddingOf(context).top + 24,
                    bottom: 16,
                    minHorizontal: 16,
                    maxWidth: ContentWidth.wide,
                  ),
                  children: [
                    header,
                    const SizedBox(height: 20),
                    for (final field in fields) ...[
                      field,
                      const SizedBox(height: 14),
                    ],
                    const _DurationNote(),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  border: Border(
                    top: BorderSide(color: context.palette.outline),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: context.contentPadding(
                      top: 12,
                      bottom: 12,
                      minHorizontal: 16,
                    ),
                    child: openButton,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.entry, required this.button});

  final GameCatalogEntry entry;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GradientMark(emoji: entry.icon, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InfoChip(
                      'من ${entry.minPlayers} لـ ${entry.maxPlayers} لاعبين',
                      icon: Icons.people_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            entry.description,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          const _DurationNote(),
          const SizedBox(height: 18),
          button,
        ],
      ),
    );
  }
}

class _ConfigFieldView extends StatelessWidget {
  const _ConfigFieldView({
    required this.field,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final ConfigField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      field.label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (field.type == 'toggle')
                    Switch(value: value == true, onChanged: onChanged),
                ],
              ),
              if (field.hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  field.hint!,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
              if (field.type == 'choice') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final option in field.options) ...[
                      Expanded(
                        child: _ChoiceChip(
                          label: option.label,
                          selected: option.value == value,
                          onTap: () => onChanged(option.value),
                        ),
                      ),
                      if (option != field.options.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
              if (field.type == 'select') ...[
                const SizedBox(height: 12),
                _SelectField(field: field, value: value, onChanged: onChanged),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.control);

    return Material(
      color: selected ? palette.primary : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? palette.primary : palette.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? palette.onPrimary : palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// العمود السادس من قائمة جاهزة لا إدخال حر — يضمن فئات قابلة للحكم.
class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final ConfigField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  static const _levelLabels = {
    'easy': '🟢 سهل',
    'medium': '🟡 متوسط',
    'hard': '🔴 صعب',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.control);

    return InkWell(
      borderRadius: radius,
      onTap: () async {
        final picked = await showModalBottomSheet<Object?>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                for (final option in field.options)
                  ListTile(
                    title: Text(option.label),
                    trailing: option.level == null
                        ? null
                        : Text(
                            _levelLabels[option.level] ?? '',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                    selected: option.value == value,
                    onTap: () => Navigator.of(sheetContext).pop(option.value),
                  ),
              ],
            ),
          ),
        );

        // إغلاق الورقة بلا اختيار يجب ألا يمسح القيمة الحالية.
        if (picked != null || value != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: radius,
          border: Border.all(color: palette.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                field.options
                    .firstWhere(
                      (option) => option.value == value,
                      orElse: () => field.options.first,
                    )
                    .label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Icon(Icons.expand_more, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DurationNote extends StatelessWidget {
  const _DurationNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.palette.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule, size: 20, color: context.palette.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'المدة المتوقعة بتتحسب باللوبي مع كل واحد بينضم — إجمالي الجولات = عدد اللاعبين × الجولات لكل شخص.',
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
