import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../model/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.error,
    this.fieldErrors = const {},
  });

  final AuthStatus status;
  final AppUser? user;
  final bool busy;
  final String? error;
  final Map<String, String> fieldErrors;

  String get userId => user?.id ?? '';

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? busy,
    String? error,
    Map<String, String>? fieldErrors,
    bool clearError = false,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    fieldErrors: clearError ? const {} : (fieldErrors ?? this.fieldErrors),
  );

  @override
  List<Object?> get props => [status, user, busy, error, fieldErrors];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, this._tokens, this._realtime)
    : super(const AuthState());

  final AuthRepository _repository;
  final TokenStore _tokens;
  final RealtimeClient _realtime;

  /// عند الإقلاع: جلسة محفوظة تعني دخولاً مباشراً بلا شاشة تسجيل.
  Future<void> bootstrap() async {
    await _tokens.load();

    if (!_tokens.hasSession) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));

      return;
    }

    try {
      final user = await _repository.me();

      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      await _realtime.connect();
    } on ApiException {
      // توكن غير صالح أو منتهٍ بلا تجديد ممكن.
      await _tokens.clear();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<bool> login({required String phone, required String password}) =>
      _guard(() => _repository.login(phone: phone, password: password));

  Future<bool> register({
    required String phone,
    required String password,
    required String fullName,
    required String username,
    required Gender gender,
    String? avatarId,
    String? recoveryEmail,
  }) => _guard(
    () => _repository.register(
      phone: phone,
      password: password,
      fullName: fullName,
      username: username,
      gender: gender,
      avatarId: avatarId,
      recoveryEmail: recoveryEmail,
    ),
  );

  Future<bool> updateProfile(Map<String, dynamic> changes) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      final user = await _repository.updateProfile(changes);

      emit(state.copyWith(busy: false, user: user));

      return true;
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          busy: false,
          error: error.message,
          fieldErrors: error.fieldErrors,
        ),
      );

      return false;
    }
  }

  Future<void> logout() async {
    await _realtime.disconnect();
    await _repository.logout();

    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// انتهت الجلسة أثناء الاستخدام (فشل تجديد التوكن).
  void sessionExpired() {
    if (state.status != AuthStatus.authenticated) return;

    _realtime.disconnect();
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'انتهت الجلسة — سجّل دخولك من جديد.',
      ),
    );
  }

  /// أوقف المشرف الحساب: يخرج فوراً من أي شاشة، ويرى السبب.
  Future<void> banned(String message) async {
    await _tokens.clear();
    await _realtime.disconnect();

    if (isClosed) return;

    emit(
      AuthState(
        status: AuthStatus.unauthenticated,
        error: message.isEmpty ? 'حسابك موقوف.' : message,
      ),
    );
  }

  void clearError() => emit(state.copyWith(clearError: true));

  Future<bool> _guard(Future<AppUser> Function() action) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      final user = await action();

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          busy: false,
        ),
      );
      await _realtime.connect();

      return true;
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          busy: false,
          error: error.message,
          fieldErrors: error.fieldErrors,
        ),
      );

      return false;
    }
  }
}
