import '../../../../core/network/api_client.dart';

/// نوايا لعبة الجاسوس.
///
/// كلها إطلاق بلا انتظار: النتيجة لا تصل في ردّ الطلب بل عبر القناة الحيّة
/// للجميع في اللحظة نفسها.
///
/// في هذه اللعبة تحديداً للأمر وجه ثانٍ: لو حمل الردّ نتيجة النيّة لاستطاع
/// اللاعب أن يستنتج منه ما لا يحقّ له — أن صوته أغلق الصندوق مثلاً، وهذه
/// معلومة عن تصويت الآخرين.
class SpyRepository {
  SpyRepository(this._api);

  final ApiClient _api;

  /// صاحب الدور يختار لاعباً ويكتب سؤاله.
  void ask(
    String gameId, {
    required String targetUserId,
    required String question,
  }) => _api.fireAndForget(
    '/games/$gameId/spy/ask',
    body: {'targetUserId': targetUserId, 'question': question},
  );

  void answer(String gameId, String text) =>
      _api.fireAndForget('/games/$gameId/spy/answer', body: {'answer': text});

  void vote(String gameId, String suspectUserId) => _api.fireAndForget(
    '/games/$gameId/spy/vote',
    body: {'suspectUserId': suspectUserId},
  );

  /// فرصة الجاسوس الأخيرة — اختيار من كلمات مجموعته.
  void guess(String gameId, String word) =>
      _api.fireAndForget('/games/$gameId/spy/guess', body: {'word': word});

  /// المجموعات والمدد والسقوف — تُقرأ مرة عند الحاجة.
  ///
  /// بنك الكلمات ليس هنا: لا داعي أن يحمله أي جهاز، ومن يحمله يستطيع تضييق
  /// التخمين على نفسه.
  Future<Map<String, dynamic>> reference() => _api.get('/spy/reference');
}
