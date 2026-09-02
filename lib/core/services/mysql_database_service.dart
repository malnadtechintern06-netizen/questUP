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
}

class MySqlDatabaseService implements IMySqlDatabaseService {
  static final MySqlDatabaseService instance = MySqlDatabaseService();

  final MySqlConfig config;
  MySQLConnection? _connection;
  bool _isConnecting = false;

  MySqlDatabaseService([MySqlConfig? config])
      : config = config ?? MySqlConfig.defaults();

  @override
  bool get isConnected => _connection != null && _connection!.connected;

  @override
  Future<bool> connect() async {
    if (isConnected) return true;
    if (_isConnecting) return false;

    _isConnecting = true;
    try {
      debugPrint('[MySQL] Connecting to ${config.host}:${config.port}/${config.database} as ${config.userName}...');
      final conn = await MySQLConnection.createConnection(
        host: config.host,
        port: config.port,
        userName: config.userName,
        password: config.password,
        databaseName: config.database,
        secure: config.secure,
      );

      await conn.connect().timeout(const Duration(milliseconds: 500));
      _connection = conn;
      debugPrint('[MySQL] Connected successfully to MySQL database "${config.database}"!');

      // Auto-initialize schema if needed
      await initializeSchema();
      return true;
    } catch (e) {
      debugPrint('[MySQL] Connection notice: Unable to connect to MySQL server ($e). Using local fallback data store.');
      _connection = null;
      return false;
    } finally {
      _isConnecting = false;
    }
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
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 2. User Profiles Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `user_profiles` (
          `user_id` VARCHAR(64) NOT NULL,
          `name` VARCHAR(120) NOT NULL,
          `email` VARCHAR(191) NOT NULL,
          `avatar_key` VARCHAR(64) DEFAULT 'adventurer_default',
          `level` INT DEFAULT 1,
          `current_xp` INT DEFAULT 0,
          `xp_to_next_level` INT DEFAULT 500,
          `coins` INT DEFAULT 100,
          `joined_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`user_id`)
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
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 4. Quest Completions Table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS `quest_completions` (
          `id` VARCHAR(64) NOT NULL,
          `quest_id` VARCHAR(64) NOT NULL,
          `user_id` VARCHAR(64) NOT NULL,
          `verification_type` VARCHAR(50) DEFAULT NULL,
          `proof_data` TEXT DEFAULT NULL,
          `xp_earned` INT DEFAULT 0,
          `coins_earned` INT DEFAULT 0,
          `completed_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      debugPrint('[MySQL] Schema verification complete. Tables are ready.');
    } catch (e) {
      debugPrint('[MySQL] Schema initialization notice: $e');
    }
  }
}
