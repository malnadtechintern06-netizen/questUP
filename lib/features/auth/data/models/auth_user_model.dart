import 'package:quest_up/features/auth/domain/entities/auth_user.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.displayName,
    super.photoUrl,
    super.isEmailVerified = false,
    required super.createdAt,
  });

  factory AuthUserModel.fromMySqlRow(Map<String, dynamic> row) {
    return AuthUserModel(
      id: row['id']?.toString() ?? '',
      email: row['email']?.toString() ?? '',
      displayName: row['name']?.toString() ??
          (row['email']?.toString().split('@').first ?? 'Explorer'),
      photoUrl: row['avatar_key']?.toString(),
      isEmailVerified: true,
      createdAt: row['created_at'] != null
          ? (DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AuthUserModel.fromEntity(AuthUser entity) {
    return AuthUserModel(
      id: entity.id,
      email: entity.email,
      displayName: entity.displayName,
      photoUrl: entity.photoUrl,
      isEmailVerified: entity.isEmailVerified,
      createdAt: entity.createdAt,
    );
  }
}
