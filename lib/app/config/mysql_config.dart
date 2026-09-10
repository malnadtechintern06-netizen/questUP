import 'dart:io';

class MySqlConfig {
  /// Global working API Base URL cached across all datasources
  static String? workingApiBaseUrl;

  /// Candidate hosts to connect to MySQL server from different environments
  static List<String> get candidateHosts {
    final hosts = <String>[];
    try {
      if (Platform.isAndroid) {
        // 1. Active Wi-Fi LAN IP (Physical Android phone e.g. Realme / Oppo)
        hosts.add('192.168.31.125');
        // 2. Android Emulator virtual gateway
        hosts.add('10.0.2.2');
        // 3. Localhost via USB port forwarding (adb reverse tcp:3306 tcp:3306)
        hosts.add('127.0.0.1');
        hosts.add('localhost');
      } else {
        hosts.add('127.0.0.1');
        hosts.add('localhost');
        hosts.add('192.168.31.125');
      }
    } catch (_) {
      hosts.add('192.168.31.125');
      hosts.add('127.0.0.1');
    }
    return hosts.toSet().toList();
  }

  /// REST API Base URLs: Pure LOCALHOST / XAMPP Development APIs (No Cloud Fallbacks)
  static List<String> get apiBaseUrls {
    final urls = <String>[];
    if (workingApiBaseUrl != null && workingApiBaseUrl!.isNotEmpty) {
      urls.add(workingApiBaseUrl!);
    }

    try {
      if (Platform.isAndroid) {
        // 1. Physical Android phone Wi-Fi LAN IP (active XAMPP server on 192.168.31.125)
        urls.add('http://192.168.31.125/questUP/backend/api');
        urls.add('http://192.168.31.125/backend/api');
        // 2. Android Emulator virtual gateway
        urls.add('http://10.0.2.2/questUP/backend/api');
        urls.add('http://10.0.2.2/backend/api');
        // 3. Localhost (only works if adb reverse tcp:80 tcp:80 is active)
        urls.add('http://127.0.0.1/questUP/backend/api');
        urls.add('http://localhost/questUP/backend/api');
      } else {
        // Windows / Desktop / Tests / Localhost
        urls.add('http://127.0.0.1/questUP/backend/api');
        urls.add('http://127.0.0.1/backend/api');
        urls.add('http://localhost/questUP/backend/api');
        urls.add('http://192.168.31.125/questUP/backend/api');
        urls.add('http://192.168.31.125/backend/api');
      }
    } catch (_) {
      urls.add('http://192.168.31.125/questUP/backend/api');
      urls.add('http://127.0.0.1/questUP/backend/api');
    }
    return urls.toSet().toList();
  }

  static String get defaultHost => candidateHosts.first;

  final String host;
  final int port;
  final String database;
  final String userName;
  final String password;
  final bool secure;

  const MySqlConfig({
    required this.host,
    this.port = 3306,
    this.database = 'questup_db',
    this.userName = 'questup',
    this.password = 'questup123',
    this.secure = false,
  });

  factory MySqlConfig.defaults() {
    return MySqlConfig(
      host: defaultHost,
      port: 3306,
      database: 'questup_db',
      userName: 'questup',
      password: 'questup123',
      secure: false,
    );
  }

  MySqlConfig copyWith({
    String? host,
    int? port,
    String? database,
    String? userName,
    String? password,
    bool? secure,
  }) {
    return MySqlConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      userName: userName ?? this.userName,
      password: password ?? this.password,
      secure: secure ?? this.secure,
    );
  }
}
