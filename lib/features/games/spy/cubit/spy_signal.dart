/// إشارات لمرة واحدة: صوت، اهتزاز، رسالة عابرة.
///
/// منفصلة عن الحالة عمداً — "انكشف الجاسوس!" حدث يقع مرة، لا خاصية للشاشة.
/// لو عاش داخل الحالة لأعاد كل بناء تشغيل الصوت من جديد.
sealed class SpySignal {
  const SpySignal();
}

/// انتهى كشف الأدوار وبدأت الأسئلة.
class RoundOpened extends SpySignal {
  const RoundOpened(this.round);

  final int round;
}

/// صار دورك تسأل.
class MyTurnToAsk extends SpySignal {
  const MyTurnToAsk();
}

/// سُئلت أنت — الكل ناطر جوابك.
class QuestionForMe extends SpySignal {
  const QuestionForMe(this.askerUsername);

  final String askerUsername;
}

class QuestionAsked extends SpySignal {
  const QuestionAsked();
}

class VotingOpened extends SpySignal {
  const VotingOpened();
}

class VoteRevealed extends SpySignal {
  const VoteRevealed({required this.caughtSpy, required this.tie});

  final bool caughtSpy;
  final bool tie;
}

/// انكشف الجاسوس وبدأت فرصته الأخيرة.
class SpyGuessOpened extends SpySignal {
  const SpyGuessOpened({required this.isMe});

  final bool isMe;
}

class GameOver extends SpySignal {
  const GameOver({required this.iWon});

  final bool iWon;
}

/// رسالة عابرة تُعرض داخل الشاشة (انضمام، مغادرة، سحب دور).
class GameToast extends SpySignal {
  const GameToast(this.message);

  final String message;
}
