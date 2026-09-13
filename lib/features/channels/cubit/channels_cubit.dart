import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_client.dart';
import '../data/channel_repository.dart';
import '../model/channel.dart';

class ChannelsState extends Equatable {
  const ChannelsState({
    this.channels = const [],
    this.loading = true,
    this.error,
  });

  final List<Channel> channels;
  final bool loading;
  final String? error;

  ChannelsState copyWith({
    List<Channel>? channels,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => ChannelsState(
    channels: channels ?? this.channels,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [channels, loading, error];
}

/// قائمة قنوات المستخدم في الشاشة الرئيسية.
///
/// تشترك في القناة الحيّة لكل قناة يملكها المستخدم، فتتحدّث بطاقة "لعبة
/// جارية" لحظة فتح أحدهم غرفة بلا سحب لتحديث القائمة.
class ChannelsCubit extends Cubit<ChannelsState> {
  ChannelsCubit(this._repository, this._realtime)
    : super(const ChannelsState()) {
    _events = _realtime.events.listen(_onRealtimeEvent);
  }

  final ChannelRepository _repository;
  final RealtimeClient _realtime;

  late final StreamSubscription<RealtimeEvent> _events;
  final _watched = <String>{};

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    try {
      final channels = await _repository.myChannels();

      emit(state.copyWith(channels: channels, loading: false));
      await _watchAll(channels);
    } on ApiException catch (error) {
      emit(state.copyWith(loading: false, error: error.message));
    }
  }

  Future<Channel?> create({required String name, String? photoUrl}) async {
    try {
      final channel = await _repository.create(name: name, photoUrl: photoUrl);

      emit(state.copyWith(channels: [channel, ...state.channels]));
      await _watchAll([channel]);

      return channel;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return null;
    }
  }

  Future<Channel?> joinByCode(String code) async {
    try {
      final channel = await _repository.joinByCode(code.trim().toUpperCase());

      final exists = state.channels.any((item) => item.id == channel.id);

      if (!exists) {
        emit(state.copyWith(channels: [channel, ...state.channels]));
        await _watchAll([channel]);
      }

      return channel;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return null;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  Future<void> _watchAll(List<Channel> channels) async {
    for (final channel in channels) {
      if (_watched.add(channel.id)) {
        await _realtime.subscribe('channel.${channel.id}');
      }
    }
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!event.channel.startsWith('channel.')) return;

    final channelId = event.channel.substring('channel.'.length);

    switch (event.name) {
      case 'active_game_changed':
        final raw = event.data['activeGame'];
        final active = raw is Map
            ? ActiveGame.fromJson(Map<String, dynamic>.from(raw))
            : null;

        emit(
          state.copyWith(
            channels: [
              for (final channel in state.channels)
                if (channel.id == channelId)
                  channel.copyWith(
                    activeGame: active,
                    clearActiveGame: active == null,
                  )
                else
                  channel,
            ],
          ),
        );

      case 'channel_updated':
        emit(
          state.copyWith(
            channels: [
              for (final channel in state.channels)
                if (channel.id == channelId)
                  channel.copyWith(name: '${event.data['name']}')
                else
                  channel,
            ],
          ),
        );

      case 'member_joined' || 'member_left' || 'member_removed':
        // عدد الأعضاء تغيّر: أرخص من إعادة تحميل القائمة كلها أن نجلب القناة وحدها.
        unawaited(_refreshOne(channelId));
    }
  }

  Future<void> _refreshOne(String channelId) async {
    try {
      final fresh = await _repository.show(channelId);

      emit(
        state.copyWith(
          channels: [
            for (final channel in state.channels)
              if (channel.id == channelId) fresh else channel,
          ],
        ),
      );
    } on ApiException catch (error) {
      // خرجنا من القناة (أزالنا المالك) أو حُذفت: تختفي من القائمة فوراً بدل
      // أن تبقى معروضة حتى يسحب المستخدم لتحديثها.
      if (error.isGone) {
        await _forget(channelId);

        return;
      }

      // ما عدا ذلك تحديث تجميلي: فشله لا يستحق رسالة خطأ للمستخدم.
    }
  }

  Future<void> _forget(String channelId) async {
    _watched.remove(channelId);
    await _realtime.unsubscribe('channel.$channelId');

    emit(
      state.copyWith(
        channels: state.channels
            .where((channel) => channel.id != channelId)
            .toList(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _events.cancel();

    return super.close();
  }
}
