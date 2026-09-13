import '../../../../core/network/api_client.dart';

/// نوايا لعبة الحروف.
///
/// كلها إطلاق بلا انتظار: النتيجة لا تصل في ردّ الطلب بل عبر القناة الحيّة
/// للجميع في اللحظة نفسها. لو انتظرنا الردّ لرأى المُرسِل نتيجته قبل غيره،
/// وهذا بالضبط ما تحاول اللعبة تفاديه.
class HarfRepository {
  HarfRepository(this._api);

  final ApiClient _api;

  /// طلب سحب فقط — السيرفر هو من يختار الحرف.
  void drawLetter(String gameId) =>
      _api.fireAndForget('/games/$gameId/harf/draw');

  /// تُرسَل مع كل تغيير: تحمي من انقطاع النت وتمنع الإرسال بعد الإقفال.
  void updateAnswer(String gameId, String column, String text) =>
      _api.fireAndForget(
        '/games/$gameId/harf/answer',
        body: {'column': column, 'text': text},
      );

  void pressStop(String gameId) =>
      _api.fireAndForget('/games/$gameId/harf/stop');

  void raiseObjection(
    String gameId, {
    required String targetUserId,
    required String column,
  }) => _api.fireAndForget(
    '/games/$gameId/harf/objection',
    body: {'targetUserId': targetUserId, 'column': column},
  );

  void castVote(
    String gameId, {
    required String objectionId,
    required bool isValid,
  }) => _api.fireAndForget(
    '/games/$gameId/harf/vote',
    body: {'objectionId': objectionId, 'valid': isValid},
  );

  void submitTiebreak(String gameId, String text) =>
      _api.fireAndForget('/games/$gameId/harf/tiebreak', body: {'text': text});

  /// الحروف والأعمدة والنقاط — تُقرأ مرة عند الإقلاع.
  Future<Map<String, dynamic>> reference() => _api.get('/harf/reference');
}
