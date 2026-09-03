import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/services/mysql_database_service.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/models/auth_user_model.dart';

abstract class IAuthRemoteDataSource {
  Future<AuthUserModel> login({
    required String email,
    required String password,
  });

  Future<AuthUserModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<void> sendPasswordReset(String email);

  Stream<AuthUserModel?> get authStateChanges;

  Future<AuthUserModel?> getCurrentUser();
}

class AuthMySqlDataSource implements IAuthRemoteDataSource {
  final ILocalStorageService _storage;
  final IMySqlDatabaseService _dbService;
  final StreamController<AuthUserModel?> _authStreamController =
      StreamController<AuthUserModel?>.broadcast();

  AuthMySqlDataSource(
    this._storage, [
    IMySqlDatabaseService? dbService,
  ]) : _dbService = dbService ?? MySqlDatabaseService.instance;

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$password::$salt::questup_secret');
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, dynamic>> _getLocalUsersMap() async {
    final raw = await _storage.getJson(AppConstants.keyLocalUsers);
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  @override
  Stream<AuthUserModel?> get authStateChanges {
    return _authStreamController.stream;
  }

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    final cached = await _storage.getJson(AppConstants.keyAuthSession);
    if (cached != null && cached is Map<String, dynamic>) {
      final model = AuthUserModel.fromJson(cached);
      _authStreamController.add(model);
      return model;
    }
    return null;
  }

  @override
  Future<AuthUserModel> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const AppException('Please enter both email and password.');
    }

    // 1. Try MySQL Database authentication if connected
    final isDbReady = await _dbService.connect();
    if (isDbReady) {
      try {
        final result = await _dbService.execute(
          'SELECT id, name, email, password_hash, salt, created_at FROM users WHERE email = :email LIMIT 1',
          {'email': cleanEmail},
        );

        if (result != null && result.rows.isNotEmpty) {
          final row = result.rows.first.assoc();
          final storedHash = row['password_hash'] ?? '';
          final salt = row['salt'] ?? '';

          final computedHash = _hashPassword(password, salt);
          if (computedHash != storedHash) {
            throw const AppException('Invalid email or password. Please try again.');
          }

          final user = AuthUserModel(
            id: row['id'] ?? const Uuid().v4(),
            email: row['email'] ?? cleanEmail,
            displayName: row['name'] ?? (cleanEmail.split('@').first),
            createdAt: row['created_at'] != null
                ? (DateTime.tryParse(row['created_at']!) ?? DateTime.now())
                : DateTime.now(),
          );

          // Synchronize local credentials registry
          final localUsers = await _getLocalUsersMap();
          localUsers[cleanEmail] = {
            'id': user.id,
            'name': user.displayName,
            'email': cleanEmail,
            'password_hash': storedHash,
            'salt': salt,
            'created_at': user.createdAt.toIso8601String(),
          };
          await _storage.saveJson(AppConstants.keyLocalUsers, localUsers);

          await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
          _authStreamController.add(user);
          debugPrint('[MySQL] User logged in successfully: ${user.email} (${user.id})');
          return user;
        } else {
          throw const AppException('No account found with this email. Please register first.');
        }
      } on AppException {
        rethrow;
      } catch (e) {
        debugPrint('[MySQL] Login query notice: $e. Falling back to local authentication.');
      }
    }

    // 2. Offline / Local Fallback Authentication
    debugPrint('[Auth] Operating in local secure authentication mode for: $cleanEmail');
    final localUsers = await _getLocalUsersMap();
    final userRecord = localUsers[cleanEmail];

    if (userRecord == null || userRecord is! Map<String, dynamic>) {
      throw const AppException('No account found with this email. Please register first.');
    }

    final storedHash = userRecord['password_hash'] as String?;
    final salt = userRecord['salt'] as String?;

    if (storedHash == null || salt == null) {
      throw const AppException('Account credentials error. Please reset your password or register again.');
    }

    final computedHash = _hashPassword(password, salt);
    if (computedHash != storedHash) {
      throw const AppException('Invalid email or password. Please try again.');
    }

    final user = AuthUserModel(
      id: userRecord['id'] as String? ?? const Uuid().v4(),
      email: cleanEmail,
      displayName: (userRecord['name'] as String?) ?? cleanEmail.split('@').first,
      createdAt: userRecord['created_at'] != null
          ? (DateTime.tryParse(userRecord['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
    );

    await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
    _authStreamController.add(user);
    debugPrint('[Local Auth] User authenticated successfully: ${user.email}');
    return user;
  }

  @override
  Future<AuthUserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const AppException('Please provide valid name, email, and password.');
    }
    if (password.length < 6) {
      throw const AppException('Password must be at least 6 characters long.');
    }

    final userId = const Uuid().v4();
    final salt = const Uuid().v4().substring(0, 16);
    final passwordHash = _hashPassword(password, salt);

    // 1. Try MySQL Database Registration if connected
    final isDbReady = await _dbService.connect();
    if (isDbReady) {
      try {
        // Check for existing user
        final checkResult = await _dbService.execute(
          'SELECT id FROM users WHERE email = :email LIMIT 1',
          {'email': cleanEmail},
        );

        if (checkResult != null && checkResult.rows.isNotEmpty) {
          throw const AppException('An account with this email already exists.');
        }

        // Insert into users table
        await _dbService.execute(
          '''
          INSERT INTO users (id, name, email, password_hash, salt, created_at)
          VALUES (:id, :name, :email, :password_hash, :salt, NOW())
          ''',
          {
            'id': userId,
            'name': cleanName,
            'email': cleanEmail,
            'password_hash': passwordHash,
            'salt': salt,
          },
        );

        // Insert into user_profiles table
        await _dbService.execute(
          '''
          INSERT INTO user_profiles (user_id, name, email, level, current_xp, xp_to_next_level, coins, joined_at)
          VALUES (:user_id, :name, :email, 1, 0, 500, 100, NOW())
          ''',
          {
            'user_id': userId,
            'name': cleanName,
            'email': cleanEmail,
          },
        );

        final user = AuthUserModel(
          id: userId,
          email: cleanEmail,
          displayName: cleanName,
          createdAt: DateTime.now(),
        );

        // Save into local credentials store as well
        final localUsers = await _getLocalUsersMap();
        localUsers[cleanEmail] = {
          'id': userId,
          'name': cleanName,
          'email': cleanEmail,
          'password_hash': passwordHash,
          'salt': salt,
          'created_at': DateTime.now().toIso8601String(),
        };
        await _storage.saveJson(AppConstants.keyLocalUsers, localUsers);

        await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
        _authStreamController.add(user);
        debugPrint('[MySQL] User registered successfully: ${user.email} (${user.id})');
        return user;
      } on AppException {
        rethrow;
      } catch (e) {
        debugPrint('[MySQL] Registration query notice: $e. Falling back to local store.');
      }
    }

    // 2. Offline / Local Fallback Registration
    final localUsers = await _getLocalUsersMap();
    if (localUsers.containsKey(cleanEmail)) {
      throw const AppException('An account with this email already exists. Please sign in.');
    }

    localUsers[cleanEmail] = {
      'id': userId,
      'name': cleanName,
      'email': cleanEmail,
      'password_hash': passwordHash,
      'salt': salt,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _storage.saveJson(AppConstants.keyLocalUsers, localUsers);

    final user = AuthUserModel(
      id: userId,
      email: cleanEmail,
      displayName: cleanName,
      createdAt: DateTime.now(),
    );

    await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
    _authStreamController.add(user);
    debugPrint('[Local Auth] User registered and credentials secured: ${user.email}');
    return user;
  }

  @override
  Future<void> logout() async {
    await _storage.remove(AppConstants.keyAuthSession);
    _authStreamController.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final isDbReady = await _dbService.connect();
    if (isDbReady) {
      try {
        final result = await _dbService.execute(
          'SELECT id FROM users WHERE email = :email LIMIT 1',
          {'email': cleanEmail},
        );
        if (result == null || result.rows.isEmpty) {
          throw const AppException('No account found with that email address.');
        }
        return;
      } on AppException {
        rethrow;
      } catch (e) {
        debugPrint('[MySQL] Password reset check: $e');
      }
    }

    // Local check
    final localUsers = await _getLocalUsersMap();
    if (!localUsers.containsKey(cleanEmail)) {
      throw const AppException('No account found with that email address.');
    }
  }
}

