import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mysql_client/mysql_client.dart';
import '../../app/config/mysql_config.dart';

abstract class IMySqlDatabaseService {
  Future<bool> connect();
  Future<void> disconnect();
  bool get isConnected;
  Future<IResultSet?> execute(String sql, [Map<String, dynamic>? params]);
  Future<void> initializeSchema();
  String get activeHost;
}

class MySqlDatabaseService implements IMySqlDatabaseService {
  static final MySqlDatabaseService instance = MySqlDatabaseService();

  MySqlConfig _config;
  MySQLConnection? _connection;
  bool _isConnecting = false;
  String _workingHost = '';
  DateTime? _lastConnectFailure;

  MySqlDatabaseService([MySqlConfig? config])
      : _config = config ?? MySqlConfig.defaults(),
        _workingHost = (config ?? MySqlConfig.defaults()).host;

  @override
  String get activeHost => _workingHost;

  @override
  bool get isConnected => _connection != null && _connection!.connected;

  @override
  Future<bool> connect() async {
    if (isConnected) return true;

    // Fail-fast if recent connection attempt failed (avoids blocking UI on every call)
    if (_lastConnectFailure != null &&
        DateTime.now().difference(_lastConnectFailure!) < const Duration(seconds: 15)) {
      return false;
    }

    if (_isConnecting) {
      // Wait for in-flight connection
      int waits = 0;
      while (_isConnecting && waits < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        waits++;
      }
      if (isConnected) return true;
    }

    _isConnecting = true;
    final hostsToTry = <String>[
      if (_workingHost.isNotEmpty) _workingHost,
      ...MySqlConfig.candidateHosts.where((h) => h != _workingHost),
    ];

    for (final host in hostsToTry) {
      try {
        final conn = await MySQLConnection.createConnection(
          host: host,
          port: _config.port,
          userName: _config.userName,
          password: _config.password,
          databaseName: _config.database,
          secure: _config.secure,
        );

        await conn.connect().timeout(const Duration(milliseconds: 600));
        _connection = conn;
        _workingHost = host;
        _config = _config.copyWith(host: host);
        _lastConnectFailure = null;
        debugPrint('[MySQL] MYSQL CONNECTION SUCCESS on host "$host", database "${_config.database}"');

        // Auto-initialize schema if needed
        await initializeSchema();
        _isConnecting = false;
        return true;
      } catch (e) {
        _connection = null;
      }
    }

    _isConnecting = false;
    _lastConnectFailure = DateTime.now();
    debugPrint('[MySQL] MYSQL Offline / Unreachable. Operating in ultra-fast local offline mode.');
    return false;
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_connection != null && _connection!.connected) {
        await _connection!.close();
      }
    } catch (e) {
      debugPrint('[MySQL] Error disconnecting: $e');
    } finally {
      _connection = null;
    }
  }

  @override
  Future<IResultSet?> execute(String sql, [Map<String, dynamic>? params]) async {
    if (!isConnected) {
      final connected = await connect();
      if (!connected) return null;
    }

    try {
      if (params != null && params.isNotEmpty) {
        final result = await _connection!.execute(sql, params);
        return result;
      } else {
        final result = await _connection!.execute(sql);
        return result;
      }
    } catch (e) {
      debugPrint('[MySQL] Query Execution Error: $e | Query: $sql');
      return null;
    }
  }

  @override
  Future<void> initializeSchema() async {
    if (!isConnected) return;

    try {
      // 1. Users Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `users` (
          `id` VARCHAR(64) NOT NULL,
          `name` VARCHAR(120) NOT NULL,
          `email` VARCHAR(191) NOT NULL UNIQUE,
          `password_hash` VARCHAR(255) NOT NULL,
          `salt` VARCHAR(64) DEFAULT NULL,
          `status` VARCHAR(30) DEFAULT 'active',
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_users_email` (`email`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 2. User Profiles Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `user_profiles` (
          `user_id` VARCHAR(64) NOT NULL,
          `name` VARCHAR(120) NOT NULL,
          `email` VARCHAR(191) NOT NULL,
          `avatar_key` VARCHAR(64) DEFAULT 'avatar_ranger',
          `level` INT DEFAULT 1,
          `current_xp` INT DEFAULT 0,
          `xp_to_next_level` INT DEFAULT 500,
          `coins` INT DEFAULT 100,
          `joined_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`user_id`),
          KEY `idx_profiles_email` (`email`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 3. Quests Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `quests` (
          `id` VARCHAR(64) NOT NULL,
          `title` VARCHAR(191) NOT NULL,
          `description` TEXT NOT NULL,
          `category` VARCHAR(50) NOT NULL,
          `verification_type` VARCHAR(50) NOT NULL,
          `latitude` DOUBLE DEFAULT NULL,
          `longitude` DOUBLE DEFAULT NULL,
          `radius_meters` DOUBLE DEFAULT 150.0,
          `xp_reward` INT DEFAULT 100,
          `coins_reward` INT DEFAULT 50,
          `location_name` VARCHAR(191) DEFAULT 'Current Area',
          `place_type` VARCHAR(100) DEFAULT NULL,
          `image_asset_path` VARCHAR(255) DEFAULT NULL,
          `difficulty` VARCHAR(30) DEFAULT 'medium',
          `is_active` TINYINT(1) DEFAULT 1,
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_quests_active_cat` (`is_active`, `category`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 4. Quest Completions Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `quest_completions` (
          `id` VARCHAR(64) NOT NULL,
          `quest_id` VARCHAR(64) NOT NULL,
          `user_id` VARCHAR(64) NOT NULL,
          `verification_type` VARCHAR(50) DEFAULT 'locationGps',
          `proof_data` TEXT DEFAULT NULL,
          `xp_earned` INT DEFAULT 0,
          `coins_earned` INT DEFAULT 0,
          `completed_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          `status` VARCHAR(30) DEFAULT 'verified',
          `review_notes` TEXT DEFAULT NULL,
          `reviewed_by` VARCHAR(64) DEFAULT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_user_quest` (`user_id`, `quest_id`),
          KEY `idx_quest_user` (`quest_id`, `user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 5. Notifications Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `notifications` (
          `id` VARCHAR(64) NOT NULL,
          `user_id` VARCHAR(64) DEFAULT NULL,
          `title` VARCHAR(191) NOT NULL,
          `message` TEXT NOT NULL,
          `type` VARCHAR(50) DEFAULT 'system',
          `is_read` TINYINT(1) DEFAULT 0,
          `route_target` VARCHAR(100) DEFAULT NULL,
          `action_label` VARCHAR(100) DEFAULT NULL,
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_user_notif` (`user_id`, `is_read`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 6. Badges & User Badges Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `badges` (
          `id` VARCHAR(64) NOT NULL,
          `name` VARCHAR(100) NOT NULL,
          `description` VARCHAR(255) NOT NULL,
          `icon` VARCHAR(100) DEFAULT 'badge_crown',
          `category` VARCHAR(50) DEFAULT 'exploration',
          `xp_bonus` INT DEFAULT 100,
          `is_active` TINYINT(1) DEFAULT 1,
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `user_badges` (
          `id` VARCHAR(64) NOT NULL,
          `user_id` VARCHAR(64) NOT NULL,
          `badge_id` VARCHAR(64) NOT NULL,
          `earned_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `idx_user_badge_unique` (`user_id`, `badge_id`),
          KEY `idx_badge_user` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 7. Email OTPs Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `email_otps` (
          `id` VARCHAR(64) NOT NULL,
          `email` VARCHAR(191) NOT NULL,
          `otp_code` VARCHAR(10) NOT NULL,
          `expires_at` DATETIME NOT NULL,
          `is_used` TINYINT(1) DEFAULT 0,
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_email_otp` (`email`, `otp_code`),
          KEY `idx_email_expires` (`email`, `expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');
    } catch (e) {
      debugPrint('[MySQL] Schema verification notice: $e');
    }
  }
}
