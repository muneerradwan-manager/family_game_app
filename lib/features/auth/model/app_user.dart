import 'package:equatable/equatable.dart';

enum Gender {
  male,
  female;

  static Gender parse(Object? value) =>
      '$value' == 'female' ? Gender.female : Gender.male;

  String get value => name;

  String get label => this == Gender.female ? 'أنثى' : 'ذكر';
}

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.gender,
    this.photoUrl,
    this.avatarId,
    this.phone,
    this.recoveryEmail,
  });

  final String id;
  final String username;
  final String fullName;
  final Gender gender;
  final String? photoUrl;
  final String? avatarId;
  final String? phone;
  final String? recoveryEmail;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: '${json['id']}',
    username: '${json['username']}',
    fullName: '${json['fullName'] ?? ''}',
    gender: Gender.parse(json['gender']),
    photoUrl: json['photoUrl'] as String?,
    avatarId: json['avatarId'] as String?,
    phone: json['phone'] as String?,
    recoveryEmail: json['recoveryEmail'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    gender,
    photoUrl,
    avatarId,
    phone,
    recoveryEmail,
  ];
}
