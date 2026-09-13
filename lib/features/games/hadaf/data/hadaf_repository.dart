import '../../../../core/network/api_client.dart';

/// نوايا لعبة الهدف.
///
/// نيّة واحدة أثناء اللعب — الإجابة — وترسل رقم الخيار **بلا توقيت**.
/// السيرفر يختم لحظة الوصول، وهذا الختم وحده يرتّب المتسابقين: لو أرسل
/// الجهاز توقيته لفاز أسرع من يعدّل حزمة لا أسرع من يفكّر.
class HadafRepository {
  HadafRepository(this._api);

  final ApiClient _api;

  void answer(String gameId, {required int choice, bool risk = false}) =>
      _api.fireAndForget(
        '/games/$gameId/hadaf/answer',
        body: {'choice': choice, 'risk': risk},
      );

  /// المجموعات والمدد والنقاط — تُقرأ مرة عند الحاجة.
  Future<Map<String, dynamic>> reference() => _api.get('/hadaf/reference');
}
