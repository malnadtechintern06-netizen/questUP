import 'dart:io';

class MySqlConfig {
  /// Default host: Android emulator uses 10.0.2.2 to connect to PC localhost
  static String get defaultHost {
    try {
      if (Platform.isAndroid) {
        return '10.0.2.2';
      }
    } catch (_) {}
    return '127.0.0.1';
  }

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
    this.userName = 'root',
    this.password = '',
    this.secure = false,
  });

  factory MySqlConfig.defaults() {
    return MySqlConfig(
      host: defaultHost,
      port: 3306,
      database: 'questup_db',
      userName: 'root',
      password: '',
      secure: false,
    );
  }
}
