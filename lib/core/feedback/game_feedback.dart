import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اللمسات الحسّية: صوت التكّة، اهتزاز الستوب، نغمة كشف الحرف.
///
/// ليست كماليات — هي الفرق بين "لعبة حيّة" و"استمارة إلكترونية". ومع ذلك
/// فشل تشغيل صوت لا يجوز أن يوقف جولة، فكل نداء هنا يبتلع أخطاءه.
class GameFeedback {
  GameFeedback(this._preferences);

  static const _soundKey = 'app.sound.enabled';

  final SharedPreferences _preferences;

  /// مشغّل مستقل للتكّة: تتكرر كل ثانية ولا يجوز أن تقطع صوتاً آخر.
  final _tickPlayer = AudioPlayer(playerId: 'harf_tick');
  final _effectPlayer = AudioPlayer(playerId: 'harf_effect');

  bool get soundEnabled => _preferences.getBool(_soundKey) ?? true;

  Future<void> setSoundEnabled(bool value) =>
      _preferences.setBool(_soundKey, value);

  Future<void> prepare() async {
    await _tickPlayer.setReleaseMode(ReleaseMode.stop);
    await _effectPlayer.setReleaseMode(ReleaseMode.stop);
    await _tickPlayer.setVolume(0.5);
  }

  /// تكّة العدّاد في آخر 15 ثانية.
  Future<void> tick() => _play(_tickPlayer, 'sounds/tick.wav');

  Future<void> letterRevealed() async {
    await HapticFeedback.selectionClick();
    await _play(_effectPlayer, 'sounds/reveal.wav');
  }

  /// ضغطة الستوب: اهتزاز وصوت معاً — أعلى لحظة توتّر في الجولة.
  Future<void> stopPressed() async {
    await HapticFeedback.heavyImpact();
    await _play(_effectPlayer, 'sounds/stop.wav');
  }

  Future<void> voteDecided() => HapticFeedback.lightImpact();

  Future<void> scoreboard() => HapticFeedback.selectionClick();

  Future<void> gameFinished() async {
    await HapticFeedback.mediumImpact();
    await _play(_effectPlayer, 'sounds/win.wav');
  }

  /// لا أصوات على ويندوز سطح المكتب.
  ///
  /// `audioplayers_windows` (4.4.1) يرسل أحداث المشغّل إلى Flutter من خيوط
  /// Media Foundation لا من خيط المنصّة، فيطبع المحرّك خطأ «non-platform
  /// thread» مع كل صوت ويحذّر من فقد بيانات أو انهيار — في منتصف مشهد. الخطأ
  /// على الجانب الأصلي فلا يصل `catch` أدناه. ويندوز منصّة تطوير لا إطلاق،
  /// فنُسكت الصوت هناك وحده؛ الجوال والويب يستعملان تنفيذات أخرى سليمة.
  /// احذف هذا الشرط حين يُصلَح الملحق.
  static bool get _audioUnsupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _play(AudioPlayer player, String asset) async {
    if (!soundEnabled || _audioUnsupported) return;

    try {
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (error) {
      debugPrint('[feedback] تعذّر تشغيل $asset: $error');
    }
  }

  Future<void> dispose() async {
    await _tickPlayer.dispose();
    await _effectPlayer.dispose();
  }
}
