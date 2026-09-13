import '../network/api_client.dart';
import 'platform_config.dart';

class PlatformRepository {
  PlatformRepository(this._api);

  final ApiClient _api;

  /// مسار مفتوح بلا توكن، ولا تحجبه الصيانة نفسها — وإلا لما عرف الجهاز
  /// أن هناك صيانة أصلاً.
  Future<PlatformConfig> fetch() async =>
      PlatformConfig.fromJson(await _api.get('/app/config'));
}
