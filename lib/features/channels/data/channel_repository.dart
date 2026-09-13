import '../../../core/network/api_client.dart';
import '../model/channel.dart';

class ChannelRepository {
  ChannelRepository(this._api);

  final ApiClient _api;

  Future<List<Channel>> myChannels() async {
    final data = await _api.get('/channels');

    return ((data['channels'] as List?) ?? const [])
        .map((item) => Channel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Channel> create({required String name, String? photoUrl}) async {
    final data = await _api.post(
      '/channels',
      body: {'name': name, 'photoUrl': ?photoUrl},
    );

    return Channel.fromJson(Map<String, dynamic>.from(data['channel'] as Map));
  }

  Future<Channel> show(String channelId) async {
    final data = await _api.get('/channels/$channelId');

    return Channel.fromJson(Map<String, dynamic>.from(data['channel'] as Map));
  }

  Future<Channel> joinByCode(String inviteCode) async {
    final data = await _api.post(
      '/channels/join',
      body: {'inviteCode': inviteCode},
    );

    return Channel.fromJson(Map<String, dynamic>.from(data['channel'] as Map));
  }

  Future<Channel> rename(String channelId, String name) async {
    final data = await _api.patch('/channels/$channelId', body: {'name': name});

    return Channel.fromJson(Map<String, dynamic>.from(data['channel'] as Map));
  }

  /// نرسل photoUrl صراحةً حتى لو كانت null — هكذا يميّز السيرفر بين
  /// "لا تلمس الصورة" و"احذف الصورة".
  Future<Channel> updatePhoto(String channelId, String? photoUrl) async {
    final data = await _api.patch(
      '/channels/$channelId',
      body: {'photoUrl': photoUrl},
    );

    return Channel.fromJson(Map<String, dynamic>.from(data['channel'] as Map));
  }

  /// إعادة توليد الرمز تُبطل الرابط القديم فوراً.
  Future<String> regenerateInviteCode(String channelId) async {
    final data = await _api.post('/channels/$channelId/invite-code');

    return '${data['inviteCode']}';
  }

  Future<void> removeMember(String channelId, String userId) =>
      _api.delete('/channels/$channelId/members/$userId');

  Future<void> leave(String channelId) =>
      _api.post('/channels/$channelId/leave');

  Future<List<GameRecord>> history(String channelId) async {
    final data = await _api.get('/channels/$channelId/games');

    return ((data['games'] as List?) ?? const [])
        .map(
          (item) => GameRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
