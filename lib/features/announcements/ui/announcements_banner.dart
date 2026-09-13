import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../cubit/announcements_cubit.dart';
import '../model/announcement.dart';

/// بطاقات الإعلانات أعلى الشاشة الرئيسية.
class AnnouncementsBanner extends StatelessWidget {
  const AnnouncementsBanner({super.key, required this.padding});

  final EdgeInsetsGeometry padding;

  /// أكثر من هذا يدفع القنوات — وهي سبب فتح التطبيق — خارج الشاشة.
  static const _maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final announcements = context.watch<AnnouncementsCubit>().state;

    if (announcements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (final announcement in announcements.take(_maxShown))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AnnouncementCard(announcement: announcement),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (color, icon) = switch (announcement.level) {
      AnnouncementLevel.info => (palette.primary, Icons.campaign_outlined),
      AnnouncementLevel.success => (
        const Color(0xFF2E7D32),
        Icons.celebration_outlined,
      ),
      AnnouncementLevel.warning => (
        const Color(0xFFB26A00),
        Icons.warning_amber_rounded,
      ),
      AnnouncementLevel.danger => (
        const Color(0xFFC62828),
        Icons.priority_high_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (announcement.title.isNotEmpty)
                  Text(
                    announcement.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: palette.textPrimary,
                    ),
                  ),
                if (announcement.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    announcement.body,
                    style: TextStyle(
                      color: palette.textPrimary.withValues(alpha: 0.8),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (announcement.dismissible)
            IconButton(
              tooltip: 'إخفاء',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  context.read<AnnouncementsCubit>().dismiss(announcement),
              icon: Icon(Icons.close, size: 18, color: palette.textMuted),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
