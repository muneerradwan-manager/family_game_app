import '../../../../core/network/api_client.dart';

/// نوايا لعبة المشهد.
///
/// كلها إطلاق بلا انتظار: الرسالة تصل للجميع معاً عبر القناة الحيّة لا في
/// ردّ صاحبها، فلا يسبق المُرسِل غيره برؤيتها.
class MashhadRepository {
  MashhadRepository(this._api);

  final ApiClient _api;

  /// رسالة داخل المشهد.
  void say(String gameId, String text) =>
      _api.fireAndForget('/games/$gameId/mashhad/say', body: {'text': text});

  /// ادّعاء ما حقّقته بعد نهاية المشهد.
  void claim(
    String gameId, {
    required bool main,
    bool bonus = false,
    bool event = false,
  }) => _api.fireAndForget(
    '/games/$gameId/mashhad/claim',
    body: {'main': main, 'bonus': bonus, 'event': event},
  );

  /// اعتراض على ادّعاء لاعب آخر.
  void challenge(
    String gameId, {
    required String targetUserId,
    required String kind,
  }) => _api.fireAndForget(
    '/games/$gameId/mashhad/challenge',
    body: {'targetUserId': targetUserId, 'kind': kind},
  );

  /// تصويت على الاعتراض المعروض.
  void vote(
    String gameId, {
    required String challengeId,
    required bool achieved,
  }) => _api.fireAndForget(
    '/games/$gameId/mashhad/vote',
    body: {'challengeId': challengeId, 'achieved': achieved},
  );

  /// تصويت جائزة نهاية المباراة.
  void award(
    String gameId, {
    required String awardKey,
    required String targetUserId,
  }) => _api.fireAndForget(
    '/games/$gameId/mashhad/award',
    body: {'awardKey': awardKey, 'targetUserId': targetUserId},
  );

  /// المجموعات والجوائز والنقاط — تُقرأ مرة عند الحاجة.
  Future<Map<String, dynamic>> reference() => _api.get('/mashhad/reference');
}
