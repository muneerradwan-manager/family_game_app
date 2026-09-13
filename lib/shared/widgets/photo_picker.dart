import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/media/image_upload_service.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'common.dart';

/// يسأل عن المصدر، يرفع الصورة، ويعيد رابطها.
///
/// الصورة اختيارية في كل مكان — الأفاتار الجاهز بديل كافٍ — فيتضمّن الخيار
/// دائماً "احذف الصورة" للعودة إليه.
Future<({bool changed, String? url})?> pickPhoto(
  BuildContext context, {
  bool allowRemove = false,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('من المعرض'),
            onTap: () => Navigator.of(sheetContext).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('صوّر صورة'),
            onTap: () => Navigator.of(sheetContext).pop('camera'),
          ),
          if (allowRemove)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: sheetContext.palette.accent,
              ),
              title: Text(
                'احذف الصورة',
                style: TextStyle(color: sheetContext.palette.accent),
              ),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return null;

  if (choice == 'remove') return (changed: true, url: null);

  final service = context.read<ImageUploadService>();

  try {
    final url = await service.pickAndUpload(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );

    // ألغى المستخدم من داخل المعرض: لا تغيير.
    return url == null ? null : (changed: true, url: url);
  } on ApiException catch (error) {
    if (context.mounted) showAppSnack(context, error.message, isError: true);

    return null;
  } catch (_) {
    if (context.mounted) {
      showAppSnack(context, 'ما قدرنا نفتح الصور.', isError: true);
    }

    return null;
  }
}

/// دائرة صورة القناة القابلة للضغط — تُستخدم في الإنشاء وفي التعديل.
class ChannelPhotoPicker extends StatelessWidget {
  const ChannelPhotoPicker({
    super.key,
    required this.photoUrl,
    required this.onTap,
    this.size = 104,
  });

  final String? photoUrl;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: palette.outline, width: 2),
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: hasPhoto
                ? null
                : Icon(
                    Icons.groups_outlined,
                    size: size * 0.4,
                    color: palette.textMuted,
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
              border: Border.all(color: palette.surface, width: 2),
            ),
            child: Icon(
              hasPhoto ? Icons.edit : Icons.add_a_photo_outlined,
              size: 15,
              color: palette.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// يسأل عن المصدر ويعيد الملف بلا رفع — لشاشة التسجيل حيث لا توكن بعد.
Future<XFile?> pickPhotoFile(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('من المعرض'),
            onTap: () => Navigator.of(sheetContext).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('صوّر صورة'),
            onTap: () => Navigator.of(sheetContext).pop('camera'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return null;

  try {
    return await context.read<ImageUploadService>().pick(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
  } catch (_) {
    if (context.mounted) {
      showAppSnack(context, 'ما قدرنا نفتح الصور.', isError: true);
    }

    return null;
  }
}
