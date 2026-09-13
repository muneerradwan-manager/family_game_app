import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../network/json.dart';

/// مفاتيح التطبيق كما يضبطها المشرف من لوحة الإدارة (`GET /app/config`).
class PlatformConfig extends Equatable {
  const PlatformConfig({
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.registrationEnabled = true,
    this.registrationMessage = '',
    this.minVersion,
    this.upgradeMessage = '',
    this.storeUrl,
    this.themes = const [],
    this.defaultThemeKey,
  });

  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool registrationEnabled;
  final String registrationMessage;

  /// أدنى نسخة مسموحة — null يعني بلا حد.
  final String? minVersion;
  final String upgradeMessage;
  final String? storeUrl;

  /// الثيمات خاماً كما وصلت: `ThemeCubit` يحوّلها ويحفظها بنفسه.
  final List<Map<String, dynamic>> themes;
  final String? defaultThemeKey;

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    final maintenance = asJsonMap(json['maintenance']);
    final registration = asJsonMap(json['registration']);
    final minimum = asJsonMap(json['minAppVersion']);

    return PlatformConfig(
      maintenanceEnabled: maintenance['enabled'] == true,
      maintenanceMessage: _text(maintenance['message']),
      // غياب الحقل لا يُغلق التسجيل: الإغلاق قرار صريح من المشرف.
      registrationEnabled: registration['enabled'] != false,
      registrationMessage: _text(registration['message']),
      minVersion: _optional(minimum['version']),
      upgradeMessage: _text(minimum['message']),
      storeUrl: _optional(minimum['storeUrl']),
      themes: asJsonList(json['themes'], (item) => item),
      defaultThemeKey: _optional(json['defaultThemeKey']),
    );
  }

  bool requiresUpgrade(String currentVersion) {
    final minimum = minVersion;

    return minimum != null && isVersionLower(currentVersion, minimum);
  }

  @override
  List<Object?> get props => [
    maintenanceEnabled,
    maintenanceMessage,
    registrationEnabled,
    registrationMessage,
    minVersion,
    upgradeMessage,
    storeUrl,
    themes,
    defaultThemeKey,
  ];
}

String _text(Object? value) => value is String ? value : '';

String? _optional(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// هل `current` أقدم من `minimum`؟ بنفس قاعدة السيرفر: رقم البناء بعد `+`
/// لا يدخل في المقارنة، والخانة الناقصة تُعدّ صفراً (1.2 = 1.2.0).
bool isVersionLower(String current, String minimum) {
  final a = _parts(current);
  final b = _parts(minimum);

  for (var index = 0; index < math.max(a.length, b.length); index++) {
    final left = index < a.length ? a[index] : 0;
    final right = index < b.length ? b[index] : 0;

    if (left != right) return left < right;
  }

  return false;
}

List<int> _parts(String version) => version
    .split('+')
    .first
    .trim()
    .split('.')
    .map((part) => int.tryParse(part.trim()) ?? 0)
    .toList();
