// اختيار وقت الترجمة: نسخة الويب تُستبعد من بناء الجوال والعكس، فلا يدخل
// dart:html في حزمة الأندرويد ولا dart:io في حزمة الويب.
export 'io_adapter.dart' if (dart.library.js_interop) 'web_adapter.dart';
