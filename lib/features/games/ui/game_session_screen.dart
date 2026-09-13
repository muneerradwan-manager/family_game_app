import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/common.dart';
import '../data/game_repository.dart';
import '../hadaf/ui/hadaf_session_screen.dart';
import '../harf/ui/harf_session_screen.dart';
import '../mashhad/ui/mashhad_session_screen.dart';
import '../spy/ui/spy_session_screen.dart';

/// موزّع الجلسات: مسار واحد `/games/:id` لكل الألعاب.
///
/// المسار لا يحمل نوع اللعبة لأن الرابط قد يصل من إشعار أو من بطاقة "لعبة
/// جارية" أو من إعادة فتح التطبيق — ولا نريد رابطاً يكذب إن تغيّر النوع.
/// فنسأل السيرفر مرة، ثم نسلّم الشاشة لوحدة اللعبة.
///
/// النوع يُمرَّر من الشاشة السابقة حين تعرفه، فلا ينتظر اللاعب طلب شبكة قبل
/// أن يرى شيئاً.
class GameSessionScreen extends StatefulWidget {
  const GameSessionScreen({super.key, required this.gameId, this.gameType});

  final String gameId;

  /// معروفاً من قبل: بطاقة القناة تعرف النوع، وفتح الغرفة كذلك.
  final String? gameType;

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen> {
  Future<String>? _type;

  @override
  void initState() {
    super.initState();

    if (widget.gameType == null) {
      _type = context.read<GameRepository>().gameType(widget.gameId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final known = widget.gameType;

    if (known != null) return _sessionFor(known);

    return FutureBuilder<String>(
      future: _type,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: AppLoader(message: 'عم نفتح اللعبة...'));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: AppErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(() {
                _type = context.read<GameRepository>().gameType(widget.gameId);
              }),
            ),
          );
        }

        return _sessionFor(snapshot.data ?? '');
      },
    );
  }

  Widget _sessionFor(String gameType) => switch (gameType) {
    'spy' => SpySessionScreen(gameId: widget.gameId),
    'hadaf' => HadafSessionScreen(gameId: widget.gameId),
    'mashhad' => MashhadSessionScreen(gameId: widget.gameId),
    _ => HarfSessionScreen(gameId: widget.gameId),
  };
}
