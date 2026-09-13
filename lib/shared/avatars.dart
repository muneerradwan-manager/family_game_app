import 'package:flutter/material.dart';

import '../features/auth/model/app_user.dart';

/// أفاتارات جاهزة.
///
/// كثيرون لن يرفعوا صورة، والأفاتار أفضل من دائرة رمادية. رسمها من رمز ولون
/// بدل ملفات صور: لا وزن على التطبيق، وتظهر نفسها على كل الأجهزة.
@immutable
class AvatarChoice {
  const AvatarChoice(this.id, this.emoji, this.color, this.gender);

  final String id;
  final String emoji;
  final Color color;

  /// null = يصلح للجميع.
  final Gender? gender;
}

const List<AvatarChoice> avatarChoices = [
  AvatarChoice('m1', '🧔', Color(0xFF4E7BB5), Gender.male),
  AvatarChoice('m2', '👨', Color(0xFF3F9C7C), Gender.male),
  AvatarChoice('m3', '👦', Color(0xFFCE7A3B), Gender.male),
  AvatarChoice('m4', '👴', Color(0xFF7A6BA8), Gender.male),
  AvatarChoice('m5', '🤠', Color(0xFFB5544E), Gender.male),
  AvatarChoice('f1', '👩', Color(0xFFC65C8F), Gender.female),
  AvatarChoice('f2', '🧕', Color(0xFF3E8E9E), Gender.female),
  AvatarChoice('f3', '👧', Color(0xFFD98B3C), Gender.female),
  AvatarChoice('f4', '👵', Color(0xFF8C6BB1), Gender.female),
  AvatarChoice('f5', '👩‍🦰', Color(0xFFCF5F5F), Gender.female),
  AvatarChoice('n1', '🦊', Color(0xFFD1743B), null),
  AvatarChoice('n2', '🦉', Color(0xFF5E7C8A), null),
  AvatarChoice('n3', '🐼', Color(0xFF5B6470), null),
  AvatarChoice('n4', '🦁', Color(0xFFC9A227), null),
  AvatarChoice('n5', '🐢', Color(0xFF4E8C5A), null),
  AvatarChoice('n6', '🐳', Color(0xFF3D7EA6), null),
];

List<AvatarChoice> avatarsFor(Gender gender) => avatarChoices
    .where((avatar) => avatar.gender == null || avatar.gender == gender)
    .toList();

AvatarChoice? avatarById(String? id) {
  if (id == null) return null;

  for (final avatar in avatarChoices) {
    if (avatar.id == id) return avatar;
  }

  return null;
}

/// أفاتار افتراضي ثابت لكل مستخدم بلا صورة — مشتق من اسمه، فلا يتغيّر بين
/// الشاشات ولا بين الأجهزة.
AvatarChoice fallbackAvatar(String seed, Gender gender) {
  final pool = avatarsFor(gender);
  final hash = seed.codeUnits.fold<int>(
    7,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );

  return pool[hash % pool.length];
}
