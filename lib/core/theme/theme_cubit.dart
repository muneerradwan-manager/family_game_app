import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/json.dart';
import 'app_palette.dart';

/// الثيم المختار، وقائمة الثيمات المتاحة.
class ThemeState {
  const ThemeState({required this.palette, required this.palettes});

  final AppPalette palette;
  final List<AppPalette> palettes;
}

/// الثيمات تأتي من لوحة الإدارة، والمختار منها محفوظ على الجهاز.
///
/// الاختيار تفضيل شخصي لا إعداد حساب: يبقى محلياً ولا يسافر مع المستخدم
/// بين الأجهزة. أما القائمة نفسها فيحدّدها المشرف، وتُحفظ آخر نسخة منها
/// ليفتح التطبيق بألوانها فوراً حتى بلا شبكة. وقبل أول اتصال بالسيرفر
/// (أو إن أفرغ المشرف القائمة) تبقى الثيمات المدمجة في التطبيق.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._preferences) : super(_restore(_preferences));

  static const _selectedKey = 'app.theme.id';
  static const _remoteKey = 'app.theme.remote';

  final SharedPreferences _preferences;

  void select(AppPalette palette) {
    if (palette.id == state.palette.id) return;

    _preferences.setString(_selectedKey, palette.id);
    emit(ThemeState(palette: palette, palettes: state.palettes));
  }

  /// ثيمات اللوحة. الاختيار المحفوظ يبقى إن بقي ثيمه؛ وإن أخفاه المشرف
  /// ينتقل الجهاز للثيم الافتراضي.
  void applyRemote(List<Map<String, dynamic>> themes, String? defaultKey) {
    final palettes = _parse(themes);

    // قائمة فارغة أو كلها ألوان تالفة: لا نترك التطبيق بلا ثيم.
    if (palettes.isEmpty) return;

    _preferences.setString(
      _remoteKey,
      jsonEncode({'themes': themes, 'defaultKey': defaultKey}),
    );

    emit(_resolve(palettes, _preferences.getString(_selectedKey), defaultKey));
  }

  static ThemeState _restore(SharedPreferences preferences) {
    var palettes = appPalettes;
    String? defaultKey;

    final raw = preferences.getString(_remoteKey);

    if (raw != null) {
      try {
        final decoded = asJsonMap(jsonDecode(raw));
        final cached = _parse(asJsonList(decoded['themes'], (item) => item));

        if (cached.isNotEmpty) {
          palettes = cached;
          defaultKey = decoded['defaultKey'] is String
              ? decoded['defaultKey'] as String
              : null;
        }
      } on FormatException {
        // نسخة محفوظة تالفة: الثيمات المدمجة تكفي حتى أول اتصال.
      }
    }

    return _resolve(palettes, preferences.getString(_selectedKey), defaultKey);
  }

  static List<AppPalette> _parse(List<Map<String, dynamic>> themes) =>
      themes.map(AppPalette.fromJson).whereType<AppPalette>().toList();

  static ThemeState _resolve(
    List<AppPalette> palettes,
    String? selectedId,
    String? defaultKey,
  ) {
    AppPalette? find(String? id) =>
        id == null ? null : palettes.where((p) => p.id == id).firstOrNull;

    return ThemeState(
      palette: find(selectedId) ?? find(defaultKey) ?? palettes.first,
      palettes: palettes,
    );
  }
}
