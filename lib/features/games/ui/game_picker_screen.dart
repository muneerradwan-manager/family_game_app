import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/responsive.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/game_repository.dart';

/// شاشة اختيار اللعبة — تُبنى من سجل الألعاب على السيرفر.
///
/// إضافة لعبة جديدة تظهر هنا وحدها بلا لمس هذا الملف: المنصّة لا تعرف
/// أسماء الألعاب مسبقاً. شبكة بطاقات: عمود على الجوال، وحتى ثلاثة على
/// الشاشة الكبيرة.
class GamePickerScreen extends StatefulWidget {
  const GamePickerScreen({super.key, required this.channelId});

  final String channelId;

  @override
  State<GamePickerScreen> createState() => _GamePickerScreenState();
}

class _GamePickerScreenState extends State<GamePickerScreen> {
  late Future<List<GameCatalogEntry>> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = context.read<GameRepository>().catalog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: context.pagePadding(),
        children: [
          const PageHeader(
            leading: AppBackButton(),
            title: 'اختار لعبة',
            subtitle: 'كل الألعاب بتنلعب لحظياً — كل واحد من جوّاله',
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<GameCatalogEntry>>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return ResponsiveGrid(
                  minItemWidth: 300,
                  children: [
                    for (var index = 0; index < 4; index++)
                      const GameCardSkeleton(),
                  ],
                );
              }

              if (snapshot.hasError) {
                return SectionCard(
                  child: AppErrorView(
                    message: '${snapshot.error}',
                    onRetry: () => setState(
                      () => _catalog = context.read<GameRepository>().catalog(),
                    ),
                  ),
                );
              }

              final games = snapshot.data ?? const <GameCatalogEntry>[];

              if (games.isEmpty) {
                return const SectionCard(
                  child: EmptyState(
                    emoji: '🧩',
                    title: 'ما في ألعاب متاحة هلق',
                    subtitle: 'ارجع بعد شوي.',
                  ),
                );
              }

              return ResponsiveGrid(
                minItemWidth: 300,
                children: [
                  for (final game in games)
                    _GameCard(
                      game: game,
                      onTap: () => context.push(
                        '/channels/${widget.channelId}/games/new/${game.gameType}',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});

  final GameCatalogEntry game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradientMark(emoji: game.icon, size: 56),
                  const Spacer(),
                  InfoChip(
                    'من ${game.minPlayers} لـ ${game.maxPlayers} لاعبين',
                    icon: Icons.people_outline,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                game.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                game.description,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'اختار هاللعبة',
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: palette.primary, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
