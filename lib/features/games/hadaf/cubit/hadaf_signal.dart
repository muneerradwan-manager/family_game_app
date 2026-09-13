/// إشارات لمرة واحدة: صوت، اهتزاز، رسالة عابرة.
///
/// منفصلة عن الحالة عمداً — "صح!" حدث يقع مرة، لا خاصية للشاشة.
sealed class HadafSignal {
  const HadafSignal();
}

/// بدأ العدّ التنازلي لسؤال جديد.
class RoundReady extends HadafSignal {
  const RoundReady(this.round);

  final int round;
}

/// انفتح السؤال — انطلقوا!
class QuestionOpened extends HadafSignal {
  const QuestionOpened();
}

/// أرسلتُ إجابتي.
class AnswerLocked extends HadafSignal {
  const AnswerLocked({required this.usedRisk});

  final bool usedRisk;
}

/// انكشف الجواب.
class AnswerRevealed extends HadafSignal {
  const AnswerRevealed({
    required this.iWasCorrect,
    required this.points,
    required this.rank,
  });

  final bool iWasCorrect;
  final int points;

  /// ترتيبي بين المصيبين — 0 يعني لم أصب.
  final int rank;
}

/// وصلت سلسلتي إلى حدّ المكافأة.
class StreakHit extends HadafSignal {
  const StreakHit(this.streak);

  final int streak;
}

class TiebreakStarted extends HadafSignal {
  const TiebreakStarted({required this.amTied});

  final bool amTied;
}

class GameOver extends HadafSignal {
  const GameOver({required this.iWon});

  final bool iWon;
}

/// رسالة عابرة تُعرض داخل الشاشة.
class GameToast extends HadafSignal {
  const GameToast(this.message);

  final String message;
}
