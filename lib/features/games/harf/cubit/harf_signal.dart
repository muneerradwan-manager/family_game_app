/// إشارات لمرة واحدة: صوت، اهتزاز، رسالة عابرة.
///
/// منفصلة عن الحالة عمداً — "منير ضغط ستوب!" حدث يقع مرة، لا خاصية للشاشة.
/// لو عاش داخل الحالة لأعاد كل بناء تشغيل الصوت من جديد.
sealed class HarfSignal {
  const HarfSignal();
}

class LetterRevealed extends HarfSignal {
  const LetterRevealed(this.letter);

  final String letter;
}

class StopAnnounced extends HarfSignal {
  const StopAnnounced(this.username, {required this.isMe});

  final String username;
  final bool isMe;
}

class ObjectionOpened extends HarfSignal {
  const ObjectionOpened();
}

class VoteDecided extends HarfSignal {
  const VoteDecided({required this.answerAccepted});

  final bool answerAccepted;
}

class RoundScored extends HarfSignal {
  const RoundScored();
}

class GameOver extends HarfSignal {
  const GameOver();
}

class TiebreakStarted extends HarfSignal {
  const TiebreakStarted();
}

/// رسالة عابرة تُعرض داخل الشاشة (انضمام، مغادرة، اعتراض).
class GameToast extends HarfSignal {
  const GameToast(this.message);

  final String message;
}
