import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';

/// خيار في شاشة الشروط — تعرّفه اللعبة ويعرضه التطبيق بقالب موحّد.
class ConfigOption extends Equatable {
  const ConfigOption({required this.value, required this.label, this.level});

  final Object? value;
  final String label;

  /// شارة المستوى للعمود السادس: easy / medium / hard.
  final String? level;

  factory ConfigOption.fromJson(Map<String, dynamic> json) => ConfigOption(
    value: json['value'],
    label: '${json['label']}',
    level: json['level'] as String?,
  );

  @override
  List<Object?> get props => [value, label, level];
}

class ConfigField extends Equatable {
  const ConfigField({
    required this.key,
    required this.type,
    required this.label,
    required this.defaultValue,
    required this.options,
    this.hint,
  });

  final String key;

  /// select | choice | toggle
  final String type;
  final String label;
  final Object? defaultValue;
  final List<ConfigOption> options;
  final String? hint;

  factory ConfigField.fromJson(Map<String, dynamic> json) => ConfigField(
    key: '${json['key']}',
    type: '${json['type']}',
    label: '${json['label']}',
    defaultValue: json['default'],
    hint: json['hint'] as String?,
    options: ((json['options'] as List?) ?? const [])
        .map(
          (item) =>
              ConfigOption.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  @override
  List<Object?> get props => [key, type, label, defaultValue, options, hint];
}

class GameCatalogEntry extends Equatable {
  const GameCatalogEntry({
    required this.gameType,
    required this.name,
    required this.icon,
    required this.description,
    required this.minPlayers,
    required this.maxPlayers,
    required this.configSchema,
  });

  final String gameType;
  final String name;

  /// إيموجي اللعبة — تعرّفه الوحدة على السيرفر فلا يبقى في التطبيق جدول أسماء.
  final String icon;

  final String description;
  final int minPlayers;
  final int maxPlayers;
  final List<ConfigField> configSchema;

  factory GameCatalogEntry.fromJson(Map<String, dynamic> json) =>
      GameCatalogEntry(
        gameType: '${json['gameType']}',
        name: '${json['name']}',
        icon: '${json['icon'] ?? '🎲'}',
        description: '${json['description']}',
        minPlayers: (json['minPlayers'] as num?)?.toInt() ?? 3,
        maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 20,
        configSchema: ((json['configSchema'] as List?) ?? const [])
            .map(
              (item) =>
                  ConfigField.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );

  @override
  List<Object?> get props => [
    gameType,
    name,
    icon,
    description,
    minPlayers,
    maxPlayers,
    configSchema,
  ];
}

/// طبقة المنصّة: فتح الغرفة واللوبي واللقطة — لا منطق لعبة بعينها.
///
/// اللقطة تعود خريطةً خاماً لا نموذجاً مكتوباً عن قصد: شكلها تعرّفه وحدة
/// اللعبة على السيرفر، وكل لعبة تقرؤه بنموذجها. لو عرف هذا الصنف نموذج لعبة
/// واحدة لصار كل ما "لا يعرف الألعاب" ادّعاءً.
class GameRepository {
  GameRepository(this._api);

  final ApiClient _api;

  Future<List<GameCatalogEntry>> catalog() async {
    final data = await _api.get('/games/catalog');

    return ((data['games'] as List?) ?? const [])
        .map(
          (item) =>
              GameCatalogEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  /// "افتح الغرفة" — يعيد معرّف اللعبة الجديدة.
  Future<String> openRoom({
    required String channelId,
    required String gameType,
    required Map<String, dynamic> config,
  }) async {
    final data = await _api.post(
      '/channels/$channelId/games',
      body: {'gameType': gameType, 'config': config},
    );

    return '${(data['game'] as Map)['id']}';
  }

  /// نوع اللعبة وحده — يكفي لتوجيه الشاشة قبل فتح الجلسة.
  Future<String> gameType(String gameId) async {
    final data = await _api.get('/games/$gameId');

    return '${(data['game'] as Map)['gameType']}';
  }

  Future<Map<String, dynamic>> snapshot(String gameId) async {
    final data = await _api.get('/games/$gameId');

    return Map<String, dynamic>.from(data['state'] as Map);
  }

  Future<Map<String, dynamic>> join(String gameId) async {
    final data = await _api.post('/games/$gameId/join');

    return Map<String, dynamic>.from(data['state'] as Map);
  }

  Future<void> leave(String gameId) => _api.post('/games/$gameId/leave');

  Future<void> start(String gameId) => _api.post('/games/$gameId/start');

  Future<void> endEarly(String gameId) => _api.post('/games/$gameId/end-early');
}
