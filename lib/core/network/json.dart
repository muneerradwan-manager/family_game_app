/// قراءة متساهلة لحمولات JSON.
///
/// السبب مخصوص: **PHP يسلسل المصفوفة الترابطية الفارغة إلى `[]` لا `{}`**.
/// فحقلٌ عقدُه خريطة يصل قائمةً فارغة متى كان فارغاً — `myAnswers` قبل أن
/// يكتب اللاعب حرفاً، و`myAwardVotes` قبل أن يصوّت لجائزة. والتحويل المباشر
/// `as Map` حينها يرمي استثناءً يُسقط الجلسة كلها.
///
/// السيرفر يصحّح المصدر بـ`(object)`، وهذه شبكة الأمان: حقل نسيناه اليوم، أو
/// جهاز يتكلم مع سيرفر أقدم، يجب ألا يكسر اللعبة.
library;

/// خريطة من حقل JSON — والقائمة الفارغة تُقرأ خريطةً فارغة.
Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);

  // قائمة غير فارغة في موضع خريطة خطأ حقيقي لا نُخفيه بصمت، لكننا لا نُسقط
  // الجلسة من أجله: نعيد خريطة فارغة ونكمل.
  return const {};
}

/// خريطة نصّية — لتحويل قيم الخريطة إلى نصوص دفعةً واحدة.
Map<String, String> asStringMap(Object? value) =>
    asJsonMap(value).map((key, item) => MapEntry(key, '$item'));

/// خريطة أعداد صحيحة.
Map<String, int> asIntMap(Object? value) => asJsonMap(
  value,
).map((key, item) => MapEntry(key, (item as num?)?.toInt() ?? 0));

/// قائمة كائنات مُحوَّلة بمحوِّلها.
List<T> asJsonList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList();
}
