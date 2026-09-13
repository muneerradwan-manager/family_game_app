import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/app_log.dart';
import '../data/announcement_repository.dart';
import '../model/announcement.dart';

/// الإعلانات الظاهرة على الشاشة الرئيسية.
///
/// ما أخفاه المستخدم يبقى مخفياً على هذا الجهاز: إعلان يعود بعد كل فتح
/// للتطبيق يتحوّل من خبر إلى إزعاج.
class AnnouncementsCubit extends Cubit<List<Announcement>> {
  AnnouncementsCubit(this._repository, this._preferences) : super(const []);

  static const _dismissedKey = 'announcements.dismissed';

  /// سقف المحفوظ: المعرّفات القديمة لا تعود أبداً، فلا داعي لتكديسها.
  static const _maxRemembered = 100;

  final AnnouncementRepository _repository;
  final SharedPreferences _preferences;

  List<Announcement> _all = const [];

  Future<void> load() async {
    try {
      _all = await _repository.fetch();

      if (!isClosed) emit(_visible());
    } on Exception catch (error) {
      // الإعلانات تكميلية: فشلها لا يستحق رسالة خطأ على الشاشة الرئيسية.
      AppLog.warn('ما قدرنا نجيب الإعلانات: $error');
    }
  }

  Future<void> dismiss(Announcement announcement) async {
    if (!announcement.dismissible) return;

    final dismissed = [
      ..._dismissed().where((id) => id != '${announcement.id}'),
      '${announcement.id}',
    ];

    await _preferences.setStringList(
      _dismissedKey,
      dismissed.length > _maxRemembered
          ? dismissed.sublist(dismissed.length - _maxRemembered)
          : dismissed,
    );

    if (!isClosed) emit(_visible());
  }

  /// عند الخروج: إعلانات قناة لا تبقى ظاهرة لمن يدخل بعده على نفس الجهاز.
  void clear() {
    _all = const [];
    emit(const []);
  }

  List<String> _dismissed() =>
      _preferences.getStringList(_dismissedKey) ?? const [];

  List<Announcement> _visible() {
    final dismissed = _dismissed();

    return _all
        .where((item) => !item.dismissible || !dismissed.contains('${item.id}'))
        .toList();
  }
}
