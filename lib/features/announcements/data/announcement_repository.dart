import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../model/announcement.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._api);

  final ApiClient _api;

  /// السيرفر يصفّي بالوقت والجمهور: الجهاز يعرض ما يصله كما هو.
  Future<List<Announcement>> fetch() async {
    final data = await _api.get('/announcements');

    return asJsonList(data['announcements'], Announcement.fromJson);
  }
}
