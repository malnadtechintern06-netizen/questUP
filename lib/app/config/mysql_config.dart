import 'dart:io';

class MySqlConfig {
  /// Live Production Cloud API Endpoint (InfinityFree)
  static const String cloudApiBaseUrl = 'https://questup.infinityfreeapp.com/backend/api';
  static const String cloudApiFallbackUrl = 'https://questup.infinityfreeapp.com/api';

  /// Candidate hosts to connect to MySQL server from different environments
  static List<String> get candidateHosts {
    final hosts = <String>[];
    try {
      if (Platform.isAndroid) {
        // 1. Real active Wi-Fi LAN IP (Physical Android phone e.g. Realme RMX3395)
        hosts.add('10.136.37.253');
        // 2. Localhost via USB
        hosts.add('127.0.0.1');
        // 3. Android Emulator virtual gateway
        hosts.add('10.0.2.2');
        // 4. Secondary LAN fallback
        hosts.add('192.168.31.125');
      } else {
        hosts.add('127.0.0.1');
        hosts.add('localhost');
      }
    } catch (_) {
      hosts.add('127.0.0.1');
    }
    return hosts;
  }

  static List<String> get apiBaseUrls {
    return [
      // 1. Production InfinityFree Cloud API (Priority #1)
      cloudApiBaseUrl,
      cloudApiFallbackUrl,

      // 2. Local & LAN Fallbacks (Offline development)
      'http://10.136.37.253/questUP/backend/api',
      'http://10.0.2.2/questUP/backend/api',
      'http://127.0.0.1/questUP/backend/api',
      'http://192.168.31.125/questUP/backend/api',
    ];
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
