import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../data/game_repository.dart';

/// شاشة اختيار اللعبة — تُبنى من سجل الألعاب على السيرفر.
///
/// إضافة لعبة جديدة تظهر هنا وحدها بلا لمس هذا الملف: المنصّة لا تعرف
/// أسماء الألعاب مسبقاً.
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
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('اختار لعبة')),
      body: FutureBuilder<List<GameCatalogEntry>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoader();
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(
                () => _catalog = context.read<GameRepository>().catalog(),
              ),
            );
          }

          final games = snapshot.data ?? const <GameCatalogEntry>[];

          return ListView.separated(
            padding: context.listPadding(bottom: 32),
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final game = games[index];

              return SectionCard(
                onTap: () => context.push(
                  '/channels/${widget.channelId}/games/new/${game.gameType}',
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: palette.headerGradient,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        game.icon,
                        style: const TextStyle(fontSize: 27),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.description,
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InfoChip(
                            'من ${game.minPlayers} لـ ${game.maxPlayers} لاعبين',
                            icon: Icons.people_outline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
