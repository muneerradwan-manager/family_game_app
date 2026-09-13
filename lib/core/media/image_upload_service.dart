import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

/// اختيار صورة ورفعها.
///
/// التصغير يجري على الجهاز قبل الرفع: صورة كاميرا حديثة تتجاوز 5 ميغا،
/// ورفعها كما هي يعني انتظاراً طويلاً على شبكة الجوال مقابل صورة تُعرض
/// بحجم 96 بكسل. والسيرفر يرفض ما تجاوز سقفه على أي حال.
class ImageUploadService {
  ImageUploadService(this._api);

  static const _maxDimension = 1024.0;
  static const _quality = 82;

  final ApiClient _api;
  final _picker = ImagePicker();

  /// يعيد رابط الصورة المرفوعة، أو null إن ألغى المستخدم.
  Future<String?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await pick(source: source);

    return picked == null ? null : upload(picked);
  }

  /// اختيار بلا رفع.
  ///
  /// شاشة التسجيل تحتاج هذا: الحساب لم يوجد بعد ولا توكن يرفع به، فنحتفظ
  /// بالملف ونعرضه محلياً ثم نرفعه فور إنشاء الحساب.
  Future<XFile?> pick({ImageSource source = ImageSource.gallery}) =>
      _picker.pickImage(
        source: source,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
      );

  Future<String> upload(XFile file) async {
    final bytes = await file.readAsBytes();

    try {
      final response = await _api.dio.post(
        '/uploads',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(
            bytes,
            filename: _safeName(file.name),
          ),
        }),
      );

      return '${response.data['url']}';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// اسم الملف يصل من معرض الصور وقد يحمل أي شيء؛ السيرفر يعيد تسميته على
  /// أي حال، لكن لا داعي لإرسال اسم غريب في الطلب.
  String _safeName(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    final allowed = {'jpg', 'jpeg', 'png', 'webp'};

    return 'photo.${allowed.contains(extension) ? extension : 'jpg'}';
  }
}
