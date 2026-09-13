import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/app_version.dart';
import '../diagnostics/app_log.dart';
import '../theme/theme_cubit.dart';
import 'platform_repository.dart';

/// ما يحجب التطبيق كله عن الاستخدام.
enum PlatformBlock { none, maintenance, upgrade }

class PlatformState extends Equatable {
  const PlatformState({
    this.block = PlatformBlock.none,
    this.message = '',
    this.storeUrl,
    this.minVersion,
    this.registrationEnabled = true,
    this.registrationMessage = '',
  });

  final PlatformBlock block;

  /// رسالة المشرف لشاشة الحجب.
  final String message;
  final String? storeUrl;
  final String? minVersion;

  final bool registrationEnabled;
  final String registrationMessage;

  bool get isBlocked => block != PlatformBlock.none;

  PlatformState copyWith({
    PlatformBlock? block,
    String? message,
    String? storeUrl,
    String? minVersion,
  }) => PlatformState(
    block: block ?? this.block,
    message: message ?? this.message,
    storeUrl: storeUrl ?? this.storeUrl,
    minVersion: minVersion ?? this.minVersion,
    registrationEnabled: registrationEnabled,
    registrationMessage: registrationMessage,
  );

  @override
  List<Object?> get props => [
    block,
    message,
    storeUrl,
    minVersion,
    registrationEnabled,
    registrationMessage,
  ];
}

/// مفاتيح لوحة الإدارة على الجهاز: الصيانة، التحديث الإجباري، التسجيل،
/// والثيمات.
///
/// مصدران للحقيقة عمداً: `refresh` يسأل السيرفر عند الإقلاع والعودة للتطبيق،
/// والإشارات (`maintenance`/`upgradeRequired`) تصل من أي طلب رُفض بـ503 أو
/// 426 — فمن كان داخل لعبة حين فعّل المشرف الصيانة يراها مع أول حركة، لا
/// حين يغلق التطبيق ويفتحه.
class PlatformCubit extends Cubit<PlatformState> {
  PlatformCubit(
    this._repository,
    this._themes, {
    this.currentVersion = appVersion,
  }) : super(const PlatformState());

  final PlatformRepository _repository;
  final ThemeCubit _themes;
  final String currentVersion;

  Future<void>? _inFlight;

  Future<void> refresh() => _inFlight ??= _refresh().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _refresh() async {
    try {
      final config = await _repository.fetch();

      if (isClosed) return;

      _themes.applyRemote(config.themes, config.defaultThemeKey);

      final block = config.maintenanceEnabled
          ? PlatformBlock.maintenance
          : config.requiresUpgrade(currentVersion)
          ? PlatformBlock.upgrade
          : PlatformBlock.none;

      emit(
        PlatformState(
          block: block,
          message: block == PlatformBlock.maintenance
              ? config.maintenanceMessage
              : config.upgradeMessage,
          storeUrl: config.storeUrl,
          minVersion: config.minVersion,
          registrationEnabled: config.registrationEnabled,
          registrationMessage: config.registrationMessage,
        ),
      );
    } on Exception catch (error) {
      // فشل الشبكة لا يحجب أحداً: السيرفر نفسه يرفض ما يجب رفضه، والإشارة
      // تصل حينها من الطلب المرفوض.
      AppLog.warn('ما قدرنا نجيب إعدادات التطبيق: $error');
    }
  }

  void maintenance(String message) {
    if (isClosed) return;

    emit(state.copyWith(block: PlatformBlock.maintenance, message: message));
  }

  void upgradeRequired({
    required String message,
    String? storeUrl,
    String? minVersion,
  }) {
    if (isClosed) return;

    emit(
      state.copyWith(
        block: PlatformBlock.upgrade,
        message: message,
        storeUrl: storeUrl,
        minVersion: minVersion,
      ),
    );
  }
}
