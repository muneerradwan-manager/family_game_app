import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_client.dart';
import '../data/channel_repository.dart';
import '../model/channel.dart';

class ChannelState extends Equatable {
  const ChannelState({
    this.channel,
    this.history = const [],
    this.loading = true,
    this.error,
    this.removed = false,
  });

  final Channel? channel;
  final List<GameRecord> history;
  final bool loading;
  final String? error;

  /// أُزلنا من القناة أو حُذفت ونحن داخلها — الشاشة تخرج بدل أن تعرض خطأً.
  final bool removed;

  ChannelState copyWith({
    Channel? channel,
    List<GameRecord>? history,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? removed,
  }) => ChannelState(
    channel: channel ?? this.channel,
    history: history ?? this.history,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    removed: removed ?? this.removed,
  );

  @override
  List<Object?> get props => [channel, history, loading, error, removed];
}

/// شاشة قناة واحدة: البطاقة البارزة، سجل الألعاب، الأعضاء، رمز الدعوة.
class ChannelCubit extends Cubit<ChannelState> {
  ChannelCubit(this._repository, this._realtime, this.channelId)
    : super(const ChannelState()) {
    _events = _realtime.events.listen(_onRealtimeEvent);
    _realtime.subscribe('channel.$channelId');
  }

  final ChannelRepository _repository;
  final RealtimeClient _realtime;
  final String channelId;

  late final StreamSubscription<RealtimeEvent> _events;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    try {
      final results = await Future.wait([
        _repository.show(channelId),
        _repository.history(channelId),
      ]);

      emit(
        state.copyWith(
          channel: results[0] as Channel,
          history: results[1] as List<GameRecord>,
          loading: false,
        ),
      );
    } on ApiException catch (error) {
      // 403/404 على قناة كنا داخلها: أُزلنا منها أو حُذفت.
      emit(
        state.copyWith(
          loading: false,
          removed: error.isGone,
          error: error.isGone ? null : error.message,
        ),
      );
    }
  }

  Future<String?> regenerateInviteCode() async {
    try {
      final code = await _repository.regenerateInviteCode(channelId);

      emit(state.copyWith(channel: state.channel?.copyWith(inviteCode: code)));

      return code;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return null;
    }
  }

  Future<bool> rename(String name) async {
    try {
      emit(state.copyWith(channel: await _repository.rename(channelId, name)));

      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return false;
    }
  }

  Future<bool> updatePhoto(String? photoUrl) async {
    try {
      emit(
        state.copyWith(
          channel: await _repository.updatePhoto(channelId, photoUrl),
        ),
      );

      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return false;
    }
  }

  Future<bool> removeMember(String userId) async {
    try {
      await _repository.removeMember(channelId, userId);
      await load();

      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return false;
    }
  }

  Future<bool> leaveChannel() async {
    try {
      await _repository.leave(channelId);

      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));

      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void _onRealtimeEvent(RealtimeEvent event) {
    if (event.channel != 'channel.$channelId') return;

    switch (event.name) {
      case 'active_game_changed':
        final raw = event.data['activeGame'];
        final active = raw is Map
            ? ActiveGame.fromJson(Map<String, dynamic>.from(raw))
            : null;

        emit(
          state.copyWith(
            channel: state.channel?.copyWith(
              activeGame: active,
              clearActiveGame: active == null,
            ),
          ),
        );

        // انتهت لعبة: سجل القناة صار فيه سطر جديد.
        if (active == null) unawaited(_refreshHistory());

      case 'channel_updated' ||
          'member_joined' ||
          'member_left' ||
          'member_removed':
        unawaited(load());
    }
  }

  Future<void> _refreshHistory() async {
    try {
      emit(state.copyWith(history: await _repository.history(channelId)));
    } on ApiException {
      // تحديث تجميلي.
    }
  }

  @override
  Future<void> close() async {
    await _events.cancel();
    await _realtime.unsubscribe('channel.$channelId');

    return super.close();
  }
}
