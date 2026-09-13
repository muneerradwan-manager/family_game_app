import 'package:family_game_app/core/network/json.dart';
import 'package:family_game_app/features/games/harf/model/harf_models.dart';
import 'package:family_game_app/features/games/mashhad/model/mashhad_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// PHP يسلسل المصفوفة الترابطية الفارغة إلى `[]` لا `{}`.
///
/// هذه الاختبارات تعيد إنتاج العطل الذي أسقط جلسة كاملة: حقلٌ عقدُه خريطة
/// وصل قائمةً فارغة، فرمى التحويل المباشر استثناءً قبل أن تُبنى اللقطة.
void main() {
  group('قراءة الخرائط المتساهلة', () {
    test('القائمة الفارغة تُقرأ خريطة فارغة لا تُسقط الجلسة', () {
      expect(asJsonMap(const []), isEmpty);
      expect(asStringMap(const []), isEmpty);
      expect(asIntMap(const []), isEmpty);
      expect(asJsonMap(null), isEmpty);
    });

    test('الخريطة الحقيقية تُقرأ كما هي', () {
      expect(asStringMap({'name': 'أحمد'}), {'name': 'أحمد'});
      expect(asIntMap({'animal': 10, 'food': 5}), {'animal': 10, 'food': 5});
    });
  });

  group('لعبة الحروف', () {
    test('لقطة بلا إجابات لا تنكسر', () {
      final round = HarfRound.fromJson(const {
        'no': 1,
        'phase': 'writing',
        'phaseStartedAt': 0,
        'deadline': 1000,
        'drawerUserId': 'u1',
        // ما كتب اللاعب شيئاً بعد: PHP يرسلها [] لا {}.
        'myAnswers': <dynamic>[],
        'roundScores': <dynamic>[],
      }, 'u1');

      expect(round.myAnswers, isEmpty);
      expect(round.roundScores, isEmpty);
    });

    test('شروط بلا عناوين أعمدة لا تنكسر', () {
      final config = HarfConfig.fromJson(const {
        'columns': ['name'],
        'columnLabels': <dynamic>[],
      });

      expect(config.labelOf('name'), 'name');
    });
  });

  group('لعبة المشهد', () {
    test('لقطة بلا أصوات جوائز لا تنكسر', () {
      final round = MashhadRound.fromJson(const {
        'no': 1,
        'phase': 'awards',
        'phaseStartedAt': 0,
        'deadline': 1000,
        'title': 'انقطعت الكهرباء',
        'setup': 'الكل بالبيت',
        // ما صوّت لأي جائزة بعد.
        'myAwardVotes': <dynamic>[],
      });

      expect(round.myAwardVotes, isEmpty);
      expect(round.title, 'انقطعت الكهرباء');
    });
  });
}
