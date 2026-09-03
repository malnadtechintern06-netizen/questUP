import 'dart:io';

class MySqlConfig {
  /// Candidate hosts to connect to MySQL server from different environments
  static List<String> get candidateHosts {
    final hosts = <String>[];
    try {
      if (Platform.isAndroid) {
        // 1. Localhost via 'adb reverse tcp:3306 tcp:3306' (Fastest & most reliable over USB)
        hosts.add('127.0.0.1');
        // 2. Android Emulator virtual gateway
        hosts.add('10.0.2.2');
        // 3. Local LAN host IP for direct Wi-Fi debugging
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
