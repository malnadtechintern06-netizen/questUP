import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/core/errors/exceptions.dart';
import 'package:quest_up/core/services/email_service.dart';
import 'package:quest_up/core/services/mysql_database_service.dart';
import 'package:quest_up/core/storage/local_storage_service.dart';
import 'package:quest_up/features/auth/data/models/auth_user_model.dart';

abstract class IAuthRemoteDataSource {
  Future<AuthUserModel> login({
    required String email,
    required String password,
  });

  Future<bool> initiateLoginWithOtp({
    required String email,
    required String password,
  });

  Future<AuthUserModel> verifyLoginOtp({
    required String email,
    required String otp,
  });

  Future<bool> resendLoginOtp({
    required String email,
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
  final IEmailService _emailService;
  final StreamController<AuthUserModel?> _authStreamController =
      StreamController<AuthUserModel?>.broadcast();

  AuthMySqlDataSource(
    this._storage, [
    IMySqlDatabaseService? dbService,
    IEmailService? emailService,
  ])  : _dbService = dbService ?? MySqlDatabaseService.instance,
        _emailService = emailService ?? EmailService.instance;

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$password::$salt::questup_secret');
    return sha256.convert(bytes).toString();
  }

  String _generateOtp() {
    final rng = Random.secure();
    final code = 100000 + rng.nextInt(900000);
    return code.toString();
  }

  Future<Map<String, dynamic>> _getLocalUsersMap() async {
    final raw = await _storage.getJson(AppConstants.keyLocalUsers);
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _getPendingOtpsMap() async {
    final raw = await _storage.getJson(AppConstants.keyPendingOtps);
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

    // 1. Check Local Auth first for instant login (< 10ms)
    final localUsers = await _getLocalUsersMap();
    final localRecord = localUsers[cleanEmail];

    if (localRecord != null && localRecord is Map<String, dynamic>) {
      final storedHash = localRecord['password_hash'] as String?;
      final salt = localRecord['salt'] as String?;

      if (storedHash != null && salt != null) {
        final computedHash = _hashPassword(password, salt);
        if (computedHash != storedHash) {
          throw const AppException('Invalid email or password. Please try again.');
        }

        final user = AuthUserModel(
          id: localRecord['id'] as String? ?? const Uuid().v4(),
          email: cleanEmail,
          displayName: (localRecord['name'] as String?) ?? cleanEmail.split('@').first,
          createdAt: localRecord['created_at'] != null
              ? (DateTime.tryParse(localRecord['created_at'] as String) ?? DateTime.now())
              : DateTime.now(),
        );

        await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
        _authStreamController.add(user);
        debugPrint('[Local Auth] User authenticated instantly: ${user.email}');
        return user;
      }
    }

    // 2. Try MySQL Database authentication if not found in local cache
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
        debugPrint('[MySQL] Login query notice: $e');
      }
    }

    throw const AppException('No account found with this email. Please register first.');
  }

  @override
  Future<bool> initiateLoginWithOtp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const AppException('Please enter both email and password.');
    }

    String userName = cleanEmail.split('@').first;
    bool credentialsValid = false;

    // 1. Fast Local Credentials Check (< 5ms)
    final localUsers = await _getLocalUsersMap();
    final localRecord = localUsers[cleanEmail];

    if (localRecord != null && localRecord is Map<String, dynamic>) {
      final storedHash = localRecord['password_hash'] as String?;
      final salt = localRecord['salt'] as String?;

      if (storedHash == null || salt == null) {
        throw const AppException('Account credentials error. Please reset your password or register again.');
      }

      final computedHash = _hashPassword(password, salt);
      if (computedHash != storedHash) {
        throw const AppException('Invalid email or password. Please try again.');
      }

      userName = (localRecord['name'] as String?) ?? userName;
      credentialsValid = true;
    }

    // 2. If not found locally, check MySQL
    if (!credentialsValid) {
      final isDbReady = await _dbService.connect();
      if (isDbReady) {
        try {
          final result = await _dbService.execute(
            'SELECT id, name, email, password_hash, salt FROM users WHERE email = :email LIMIT 1',
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

            userName = row['name'] ?? userName;
            credentialsValid = true;

            // Cache locally for next time
            localUsers[cleanEmail] = {
              'id': row['id'] ?? const Uuid().v4(),
              'name': userName,
              'email': cleanEmail,
              'password_hash': storedHash,
              'salt': salt,
              'created_at': DateTime.now().toIso8601String(),
            };
            await _storage.saveJson(AppConstants.keyLocalUsers, localUsers);
          } else {
            throw const AppException('No account found with this email. Please register first.');
          }
        } on AppException {
          rethrow;
        } catch (e) {
          debugPrint('[MySQL] Initiate OTP credential verification notice: $e');
        }
      }
    }

    if (!credentialsValid) {
      throw const AppException('No account found with this email. Please register first.');
    }

    // 3. Generate 6-Digit OTP & Expiry (5 minutes)
    final otpCode = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    final otpId = const Uuid().v4();

    // 4. Save OTP to Local Storage Cache (Immediate)
    final pendingOtps = await _getPendingOtpsMap();
    pendingOtps[cleanEmail] = {
      'id': otpId,
      'email': cleanEmail,
      'otp_code': otpCode,
      'expires_at': expiresAt.toIso8601String(),
      'is_used': false,
    };
    await _storage.saveJson(AppConstants.keyPendingOtps, pendingOtps);

    // 5. Asynchronously dispatch Email & sync MySQL in background (Non-blocking!)
    unawaited(_emailService.sendOtpEmail(
      recipientEmail: cleanEmail,
      otpCode: otpCode,
      userName: userName,
    ));

    if (_dbService.isConnected) {
      unawaited(() async {
        try {
          await _dbService.execute(
            'UPDATE email_otps SET is_used = 1 WHERE email = :email AND is_used = 0',
            {'email': cleanEmail},
          );
          await _dbService.execute(
            '''
            INSERT INTO email_otps (id, email, otp_code, expires_at, is_used, created_at)
            VALUES (:id, :email, :otp_code, :expires_at, 0, NOW())
            ''',
            {
              'id': otpId,
              'email': cleanEmail,
              'otp_code': otpCode,
              'expires_at': expiresAt.toIso8601String(),
            },
          );
        } catch (_) {}
      }());
    }

    debugPrint('[Auth] Instant OTP generated for: $cleanEmail ($otpCode)');
    return true;
  }

  @override
  Future<AuthUserModel> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (cleanEmail.isEmpty) {
      throw const AppException('Email address is missing.');
    }
    if (cleanOtp.length != 6) {
      throw const AppException('Please enter the full 6-digit verification code.');
    }

    // 1. Fast Local Store OTP Validation (< 5ms)
    final pendingOtps = await _getPendingOtpsMap();
    final otpRecord = pendingOtps[cleanEmail];

    if (otpRecord != null && otpRecord is Map<String, dynamic>) {
      final storedOtp = otpRecord['otp_code'] as String?;
      final isUsed = otpRecord['is_used'] as bool? ?? false;
      final expiresAtStr = otpRecord['expires_at'] as String?;
      final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

      if (!isUsed && storedOtp == cleanOtp) {
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
          throw const AppException('Verification code has expired. Please request a new one.');
        }

        // Mark OTP as consumed
        otpRecord['is_used'] = true;
        await _storage.saveJson(AppConstants.keyPendingOtps, pendingOtps);

        // Fetch user from local users
        final localUsers = await _getLocalUsersMap();
        final userRecord = localUsers[cleanEmail];

        final user = AuthUserModel(
          id: (userRecord?['id'] as String?) ?? const Uuid().v4(),
          email: cleanEmail,
          displayName: (userRecord?['name'] as String?) ?? cleanEmail.split('@').first,
          createdAt: userRecord?['created_at'] != null
              ? (DateTime.tryParse(userRecord!['created_at'] as String) ?? DateTime.now())
              : DateTime.now(),
        );

        await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
        _authStreamController.add(user);

        // Async MySQL sync if connected
        if (_dbService.isConnected) {
          unawaited(_dbService.execute(
            'UPDATE email_otps SET is_used = 1 WHERE email = :email AND otp_code = :otp',
            {'email': cleanEmail, 'otp': cleanOtp},
          ));
        }

        debugPrint('[Local Auth] User OTP verified instantly: ${user.email}');
        return user;
      }
    }

    // 2. Try MySQL OTP Validation if not verified locally
    final isDbReady = await _dbService.connect();
    if (isDbReady) {
      try {
        final otpResult = await _dbService.execute(
          '''
          SELECT id, email, otp_code, expires_at, is_used 
          FROM email_otps 
          WHERE email = :email AND otp_code = :otp AND is_used = 0 
          ORDER BY created_at DESC LIMIT 1
          ''',
          {
            'email': cleanEmail,
            'otp': cleanOtp,
          },
        );

        if (otpResult != null && otpResult.rows.isNotEmpty) {
          final row = otpResult.rows.first.assoc();
          final expiresAtStr = row['expires_at'];
          DateTime? expiresAt;
          if (expiresAtStr != null) {
            expiresAt = DateTime.tryParse(expiresAtStr);
          }

          if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
            throw const AppException('Verification code has expired. Please request a new one.');
          }

          // Mark OTP as used
          final otpDbId = row['id'];
          if (otpDbId != null) {
            await _dbService.execute(
              'UPDATE email_otps SET is_used = 1 WHERE id = :id',
              {'id': otpDbId},
            );
          }

          // Fetch user info from database
          final userResult = await _dbService.execute(
            'SELECT id, name, email, created_at FROM users WHERE email = :email LIMIT 1',
            {'email': cleanEmail},
          );

          if (userResult != null && userResult.rows.isNotEmpty) {
            final uRow = userResult.rows.first.assoc();
            final user = AuthUserModel(
              id: uRow['id'] ?? const Uuid().v4(),
              email: cleanEmail,
              displayName: uRow['name'] ?? cleanEmail.split('@').first,
              createdAt: uRow['created_at'] != null
                  ? (DateTime.tryParse(uRow['created_at']!) ?? DateTime.now())
                  : DateTime.now(),
            );

            // Clean pending local OTP
            pendingOtps.remove(cleanEmail);
            await _storage.saveJson(AppConstants.keyPendingOtps, pendingOtps);

            await _storage.saveJson(AppConstants.keyAuthSession, user.toJson());
            _authStreamController.add(user);
            debugPrint('[MySQL] User OTP verified successfully: ${user.email}');
            return user;
          }
        }
      } on AppException {
        rethrow;
      } catch (e) {
        debugPrint('[MySQL] Verify OTP query notice: $e');
      }
    }

    throw const AppException('Invalid verification code. Please check your email and try again.');
  }

  @override
  Future<bool> resendLoginOtp({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const AppException('Email address is missing.');
    }

    String userName = cleanEmail.split('@').first;
    final localUsers = await _getLocalUsersMap();
    final userRecord = localUsers[cleanEmail];
    if (userRecord != null && userRecord is Map<String, dynamic>) {
      userName = (userRecord['name'] as String?) ?? userName;
    }

    final otpCode = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    final otpId = const Uuid().v4();

    final pendingOtps = await _getPendingOtpsMap();
    pendingOtps[cleanEmail] = {
      'id': otpId,
      'email': cleanEmail,
      'otp_code': otpCode,
      'expires_at': expiresAt.toIso8601String(),
      'is_used': false,
    };
    await _storage.saveJson(AppConstants.keyPendingOtps, pendingOtps);

    unawaited(_emailService.sendOtpEmail(
      recipientEmail: cleanEmail,
      otpCode: otpCode,
      userName: userName,
    ));

    if (_dbService.isConnected) {
      unawaited(() async {
        try {
          await _dbService.execute(
            'UPDATE email_otps SET is_used = 1 WHERE email = :email AND is_used = 0',
            {'email': cleanEmail},
          );
          await _dbService.execute(
            '''
            INSERT INTO email_otps (id, email, otp_code, expires_at, is_used, created_at)
            VALUES (:id, :email, :otp_code, :expires_at, 0, NOW())
            ''',
            {
              'id': otpId,
              'email': cleanEmail,
              'otp_code': otpCode,
              'expires_at': expiresAt.toIso8601String(),
            },
          );
        } catch (_) {}
      }());
    }

    debugPrint('[Auth] Instant Resent OTP for: $cleanEmail ($otpCode)');
    return true;
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

