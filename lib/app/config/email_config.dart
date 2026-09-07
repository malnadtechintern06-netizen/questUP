class EmailConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String fromName;
  final String fromEmail;
  final bool isSsl;

  final bool enableBackendApi;
  final String? customApiUrl;

  const EmailConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.fromName = 'QuestUP Security',
    this.fromEmail = 'auth@questup.app',
    this.isSsl = false,
    this.enableBackendApi = true,
    this.customApiUrl,
  });

  /// Factory with defaults, supporting compile-time Dart environment overrides:
  /// --dart-define=SMTP_HOST=smtp.gmail.com
  /// --dart-define=SMTP_PORT=587
  /// --dart-define=SMTP_USER=your_email@gmail.com
  /// --dart-define=SMTP_PASS=your_app_password
  /// --dart-define=SMTP_FROM=security@questup.app
  /// --dart-define=ENABLE_BACKEND_EMAIL_API=true
  factory EmailConfig.defaults() {
    const host = String.fromEnvironment('SMTP_HOST', defaultValue: 'smtp.gmail.com');
    const portString = String.fromEnvironment('SMTP_PORT', defaultValue: '587');
    final port = int.tryParse(portString) ?? 587;
    const username = String.fromEnvironment('SMTP_USER', defaultValue: 'questup.auth.verify@gmail.com');
    const password = String.fromEnvironment('SMTP_PASS', defaultValue: '');
    const fromName = String.fromEnvironment('SMTP_FROM_NAME', defaultValue: 'QuestUP Security');
    const fromEmail = String.fromEnvironment('SMTP_FROM_EMAIL', defaultValue: 'security@questup.app');
    const isSsl = bool.fromEnvironment('SMTP_SSL', defaultValue: false);
    const enableBackendApi = bool.fromEnvironment('ENABLE_BACKEND_EMAIL_API', defaultValue: true);
    const customApiUrl = String.fromEnvironment('EMAIL_API_URL', defaultValue: '');

    return EmailConfig(
      host: host,
      port: port,
      username: username,
      password: password,
      fromName: fromName,
      fromEmail: fromEmail,
      isSsl: isSsl,
      enableBackendApi: enableBackendApi,
      customApiUrl: customApiUrl.isNotEmpty ? customApiUrl : null,
    );
  }

  bool get isSmtpConfigured => username.isNotEmpty && password.isNotEmpty;
  bool get isConfigured => isSmtpConfigured || enableBackendApi;

  EmailConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? fromName,
    String? fromEmail,
    bool? isSsl,
    bool? enableBackendApi,
    String? customApiUrl,
  }) {
    return EmailConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      fromName: fromName ?? this.fromName,
      fromEmail: fromEmail ?? this.fromEmail,
      isSsl: isSsl ?? this.isSsl,
      enableBackendApi: enableBackendApi ?? this.enableBackendApi,
      customApiUrl: customApiUrl ?? this.customApiUrl,
    );
  }
}
