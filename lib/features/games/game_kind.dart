/// اسم اللعبة وأيقونتها من معرّفها.
///
/// الكتالوج على السيرفر هو المرجع، ويصل بأيقونته في شاشة اختيار اللعبة. لكن
/// بطاقة "لعبة جارية" وسجل القناة يعرفان المعرّف وحده — ولا يستحقّان طلب شبكة
/// إضافياً لسطر عنوان. فهذا جدول عرضٍ صغير، وله بديل معقول لأي معرّف لا يعرفه:
/// لعبة جديدة على السيرفر تظهر في السجل باسم محايد لا بشاشة فارغة.
class GameKind {
  const GameKind._();

  static const _known = {
    'harf': (name: 'لعبة الحروف', icon: '🔠'),
    'spy': (name: 'لعبة الجاسوس', icon: '🕵️'),
    'hadaf': (name: 'لعبة الهدف', icon: '🎯'),
    'mashhad': (name: 'لعبة المشهد', icon: '🎬'),
  };

  static String nameOf(String gameType) => _known[gameType]?.name ?? 'لعبة';

  static String iconOf(String gameType) => _known[gameType]?.icon ?? '🎲';
}
