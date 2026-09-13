/// إشارات لمرة واحدة: صوت، اهتزاز، رسالة عابرة.
sealed class MashhadSignal {
  const MashhadSignal();
}

/// بدأ مشهد جديد.
class SceneOpened extends MashhadSignal {
  const SceneOpened(this.title);

  final String title;
}

/// انفتح الشات — المشهد بلّش.
class SceneLive extends MashhadSignal {
  const SceneLive();
}

/// حدث مفاجئ وصل الجميع.
class PublicEvent extends MashhadSignal {
  const PublicEvent(this.text);

  final String text;
}

/// حدث خاص وصلني أنا وحدي.
class PrivateEvent extends MashhadSignal {
  const PrivateEvent();
}

/// حدث خاص وصل لاعباً آخر — نعرف أنه وصل، لا ماذا كان.
class SomeoneGotSecret extends MashhadSignal {
  const SomeoneGotSecret(this.username);

  final String username;
}

class SceneClosed extends MashhadSignal {
  const SceneClosed();
}

/// انكشفت الأدوار والأهداف والادّعاءات.
class ClaimsRevealed extends MashhadSignal {
  const ClaimsRevealed();
}

class ChallengeRaised extends MashhadSignal {
  const ChallengeRaised({required this.onMe});

  final bool onMe;
}

class VerdictDecided extends MashhadSignal {
  const VerdictDecided({required this.claimStood, required this.aboutMe});

  /// صمد الادّعاء أم سقط.
  final bool claimStood;

  final bool aboutMe;
}

class SceneScored extends MashhadSignal {
  const SceneScored({required this.myPoints});

  final int myPoints;
}

class AwardsOpened extends MashhadSignal {
  const AwardsOpened();
}

class GameOver extends MashhadSignal {
  const GameOver({required this.iWon});

  final bool iWon;
}

/// رسالة عابرة تُعرض داخل الشاشة.
class GameToast extends MashhadSignal {
  const GameToast(this.message);

  final String message;
}
