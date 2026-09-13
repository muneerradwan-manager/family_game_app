import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../diagnostics/app_log.dart';
import '../storage/token_store.dart';

/// حدث واصل من السيرفر عبر القناة الحيّة.
@immutable
class RealtimeEvent {
  const RealtimeEvent({
    required this.channel,
    required this.name,
    required this.data,
  });

  final String channel;
  final String name;
  final Map<String, dynamic> data;

  /// ختم السيرفر لحظة إطلاق الحدث — كل العدّادات تُحسب منه لا من ساعة الجهاز.
  int get serverTime => (data['serverTime'] as num?)?.toInt() ?? 0;
}

enum RealtimeStatus { disconnected, connecting, connected }

/// القناة الحيّة: WebSocket واحد لكل التطبيق.
///
/// نتكلم بروتوكول Pusher مباشرة لأن Reverb يفهمه، وحزمة Pusher الرسمية لم
/// تعد تسمح بمضيف مخصّص. البروتوكول بسيط (اشتراك · حدث · نبض) وامتلاكه
/// يعطينا تحكماً كاملاً بإعادة الاتصال — وهي أهم من أي ميزة هنا: انقطاع
/// نصف ثانية في منتصف جولة يجب أن يُلتقط ويُعاد بلا تدخل من اللاعب.
///
/// الاتجاه واحد: السيرفر يبثّ والتطبيق يستمع. نوايا اللاعبين تُرسَل عبر REST
/// فتمر بالمصادقة والتحقق، ولا تصل غيره قبل أن يقرّرها السيرفر.
class RealtimeClient {
  RealtimeClient(this._tokens);

  static const _protocol = 7;
  static const _pingInterval = Duration(seconds: 25);
  static const _maxBackoff = Duration(seconds: 15);

  final TokenStore _tokens;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _status = StreamController<RealtimeStatus>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// القنوات المطلوبة وعدد من يطلبها — نعيد الاشتراك بها كلها بعد كل اتصال.
  ///
  /// العدّاد ضروري لأن أكثر من شاشة قد تستمع لنفس القناة في الوقت نفسه:
  /// قائمة القنوات تراقب `channel.{id}` طوال عمر التطبيق، وشاشة القناة
  /// تراقبها كذلك ما دامت مفتوحة. بلا عدّاد، إغلاق الشاشة القصيرة يقطع
  /// اشتراك الشاشة الطويلة معه — فتصمت القائمة عن كل ما يجري في تلك القناة.
  final _desiredChannels = <String, int>{};
  final _subscribed = <String>{};

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _listener;
  Timer? _pingTimer;
  Timer? _retryTimer;
  String? _socketId;
  int _attempt = 0;
  bool _closing = false;
  bool _hadSession = false;

  Stream<RealtimeEvent> get events => _events.stream;

  Stream<RealtimeStatus> get status => _status.stream;

  /// يُطلق بعد استعادة اتصال منقطع: إشارة للشاشات أن تجلب لقطة جديدة،
  /// لأن ما فات أثناء الانقطاع من أحداث لن يصل مرة ثانية.
  Stream<void> get reconnected => _reconnected.stream;

  bool get isConnected => _socketId != null;

  /// عدد الشاشات التي تستمع لهذه القناة الآن — للتشخيص وللاختبار.
  int listenersOn(String channel) => _desiredChannels[channel] ?? 0;

  Future<void> connect() async {
    _closing = false;

    if (_socket != null) return;

    _status.add(RealtimeStatus.connecting);

    final uri = Uri.parse(
      '${AppConfig.websocketUrl}/app/${AppConfig.reverbKey}'
      '?protocol=$_protocol&client=flutter&version=1.0',
    );

    AppLog.live('🔌 عم نتصل بـ ${AppConfig.websocketUrl}');

    try {
      final socket = WebSocketChannel.connect(uri);
      _socket = socket;

      _listener = socket.stream.listen(
        _onMessage,
        onDone: _onClosed,
        onError: (Object error) {
          AppLog.error('السوكت وقع', error);
          _onClosed();
        },
        cancelOnError: true,
      );
    } catch (error) {
      AppLog.error('تعذّر فتح السوكت', error);
      _scheduleRetry();
    }
  }

  Future<void> disconnect() async {
    _closing = true;
    _retryTimer?.cancel();
    _desiredChannels.clear();

    await _teardown();

    _status.add(RealtimeStatus.disconnected);
  }

  /// أسماء القنوات بلا بادئة private- : `game.{id}` و`channel.{id}`.
  ///
  /// كل نداء هنا يقابله نداء واحد لـ unsubscribe؛ والاشتراك الفعلي يقع مرة
  /// واحدة مهما تعدّد الطالبون.
  Future<void> subscribe(String channel) async {
    final listeners = (_desiredChannels[channel] ?? 0) + 1;
    _desiredChannels[channel] = listeners;

    if (listeners > 1) return;

    _sendSubscribe(channel);
  }

  Future<void> unsubscribe(String channel) async {
    final listeners = (_desiredChannels[channel] ?? 0) - 1;

    // ما زال أحدهم يستمع: نبقي الاشتراك قائماً.
    if (listeners > 0) {
      _desiredChannels[channel] = listeners;

      return;
    }

    _desiredChannels.remove(channel);

    if (!_subscribed.remove(channel)) return;

    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': 'private-$channel'},
    });
  }

  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    final decoded = jsonDecode('$raw');

    if (decoded is! Map<String, dynamic>) return;

    final event = '${decoded['event']}';
    final data = _asMap(decoded['data']);

    switch (event) {
      case 'pusher:connection_established':
        _onEstablished(data);

      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': {}});

      case 'pusher:pong':
        break;

      case 'pusher_internal:subscription_succeeded':
        final subscribed = '${decoded['channel']}'.replaceFirst('private-', '');
        _subscribed.add(subscribed);
        AppLog.live('📡 اشتركنا في $subscribed');

      case 'pusher:error':
        AppLog.error('رفض السيرفر الاتصال', data['message']);

      default:
        if (event.startsWith('pusher:') ||
            event.startsWith('pusher_internal:')) {
          return;
        }

        final channel = '${decoded['channel']}'.replaceFirst('private-', '');

        AppLog.live('$channel › $event  ${AppLog.body(data) ?? ''}');

        _events.add(RealtimeEvent(channel: channel, name: event, data: data));
    }
  }

  void _onEstablished(Map<String, dynamic> data) {
    _socketId = '${data['socket_id']}';
    _attempt = 0;

    AppLog.live('🟢 متصل · socket $_socketId');
    _status.add(RealtimeStatus.connected);

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      _pingInterval,
      (_) => _send({'event': 'pusher:ping', 'data': {}}),
    );

    for (final channel in _desiredChannels.keys) {
      _sendSubscribe(channel);
    }

    // أول اتصال ليس عودة؛ ما بعده يعني أن أحداثاً فاتت وتحتاج لقطة جديدة.
    if (_hadSession) _reconnected.add(null);
    _hadSession = true;
  }

  void _onClosed() {
    _socketId = null;
    _subscribed.clear();
    _pingTimer?.cancel();
    _listener?.cancel();
    _listener = null;
    _socket = null;

    if (_closing) return;

    AppLog.warn('انقطع الاتصال الحي');
    _status.add(RealtimeStatus.disconnected);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();

    // تراجع أسّي بسقف: انقطاع الشبكة لا يجوز أن يتحول إلى طوفان محاولات.
    final delay = Duration(
      milliseconds: (500 * (1 << _attempt.clamp(0, 5))).clamp(
        500,
        _maxBackoff.inMilliseconds,
      ),
    );
    _attempt++;

    AppLog.live(
      '🔁 محاولة اتصال جديدة بعد ${delay.inMilliseconds}ms (رقم $_attempt)',
    );
    _retryTimer = Timer(delay, connect);
  }

  Future<void> _sendSubscribe(String channel) async {
    if (_socketId == null) return;

    final name = 'private-$channel';

    try {
      final auth = await _authorize(name);

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': name, 'auth': auth},
      });
    } catch (error) {
      AppLog.error('فشل توثيق الاشتراك في $name', error);
    }
  }

  /// توقيع الاشتراك في قناة خاصة — السيرفر هو من يقرّر، لا التطبيق.
  Future<String> _authorize(String channelName) async {
    final response = await Dio().post(
      AppConfig.broadcastAuthUrl,
      data: {'socket_id': _socketId, 'channel_name': channelName},
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_tokens.accessToken}',
          'Accept': 'application/json',
        },
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    return '${_asMap(response.data)['auth']}';
  }

  void _send(Map<String, dynamic> payload) {
    final sink = _socket?.sink;

    if (sink == null) return;

    sink.add(jsonEncode(payload));
  }

  Future<void> _teardown() async {
    _pingTimer?.cancel();
    await _listener?.cancel();
    await _socket?.sink.close();

    _listener = null;
    _socket = null;
    _socketId = null;
    _subscribed.clear();
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();

    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }

    return const {};
  }

  Future<void> dispose() async {
    _closing = true;
    _retryTimer?.cancel();
    await _teardown();
    await _events.close();
    await _status.close();
    await _reconnected.close();
  }
}
