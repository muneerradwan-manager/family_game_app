import 'package:equatable/equatable.dart';

enum AnnouncementLevel { info, success, warning, danger }

/// إعلان من لوحة الإدارة.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.level = AnnouncementLevel.info,
    this.dismissible = true,
  });

  final int id;
  final String title;
  final String body;
  final AnnouncementLevel level;

  /// إعلان مهم قد يُمنع إخفاؤه — يبقى حتى يوقفه المشرف أو تنتهي مدته.
  final bool dismissible;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] is String ? json['title'] as String : '',
    body: json['body'] is String ? json['body'] as String : '',
    level: AnnouncementLevel.values.firstWhere(
      (level) => level.name == json['level'],
      orElse: () => AnnouncementLevel.info,
    ),
    dismissible: json['dismissible'] != false,
  );

  @override
  List<Object?> get props => [id, title, body, level, dismissible];
}
