import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

/// الثيم المختار، محفوظ على الجهاز.
///
/// الاختيار تفضيل شخصي لا إعداد حساب: يبقى محلياً ولا يسافر مع المستخدم
/// بين الأجهزة، فلا داعي لرحلة إلى السيرفر عند كل تبديل.
class ThemeCubit extends Cubit<AppPalette> {
  ThemeCubit(this._preferences)
    : super(paletteById(_preferences.getString(_key)));

  static const _key = 'app.theme.id';

  final SharedPreferences _preferences;

  void select(AppPalette palette) {
    if (palette.id == state.id) return;

    _preferences.setString(_key, palette.id);
    emit(palette);
  }
}
