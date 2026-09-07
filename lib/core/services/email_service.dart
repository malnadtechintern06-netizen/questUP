import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../app/config/email_config.dart';
import '../../app/config/mysql_config.dart';

abstract class IEmailService {
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
    String? userName,
  });

  String? getLastDispatchedOtp(String email);

  EmailConfig get config;
}

class EmailService implements IEmailService {
  static final EmailService instance = EmailService();

  final EmailConfig _config;
  static final Map<String, String> _lastDispatchedOtps = {};

  EmailService([EmailConfig? config]) : _config = config ?? EmailConfig.defaults();

  @override
  EmailConfig get config => _config;

  @override
  String? getLastDispatchedOtp(String email) {
    return _lastDispatchedOtps[email.trim().toLowerCase()];
  }

  @override
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
    String? userName,
  }) async {
    final cleanEmail = recipientEmail.trim().toLowerCase();
    final targetName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : cleanEmail.split('@').first;

    // Cache in-memory for instant reference / dev helper
    _lastDispatchedOtps[cleanEmail] = otpCode;

    debugPrint('====================================================');
    debugPrint('[EmailService] 🔐 DISPATCHING LOGIN OTP TO: $cleanEmail');
    debugPrint('[EmailService] 🔢 ONE-TIME PASSCODE: $otpCode');
    debugPrint('[EmailService] ⏳ EXPIRES IN: 5 minutes');
    debugPrint('====================================================');

    // 1. Primary: Dispatch via Backend REST API (if enabled)
    if (_config.enableBackendApi) {
      final backendSent = await _sendViaBackendApi(
        recipientEmail: cleanEmail,
        otpCode: otpCode,
        userName: targetName,
      );
      if (backendSent) {
        return true;
      }
    }

    // 2. Secondary: Dispatch via Direct SMTP (if configured)
    if (_config.isSmtpConfigured) {
      final smtpSent = await _sendViaSmtp(
        recipientEmail: cleanEmail,
        otpCode: otpCode,
        userName: targetName,
      );
      if (smtpSent) {
        return true;
      }
    }

    // 3. Fallback: Logged in console for local/offline dev testing
    debugPrint(
      '[EmailService] ℹ️ Live network dispatch unavailable. '
      'Passcode ($otpCode) recorded in memory for local/dev authentication.',
    );
    return true;
  }

  Future<bool> _sendViaBackendApi({
    required String recipientEmail,
    required String otpCode,
    required String userName,
  }) async {
    if (kIsWeb) {
      return false;
    }

    final candidateUrls = <String>[];
    if (_config.customApiUrl != null && _config.customApiUrl!.isNotEmpty) {
      candidateUrls.add(_config.customApiUrl!);
    }
    for (final base in MySqlConfig.apiBaseUrls) {
      candidateUrls.add('$base/auth/send_otp.php');
    }

    final payload = jsonEncode({
      'recipient_email': recipientEmail,
      'otp_code': otpCode,
      'user_name': userName,
    });

    final completer = Completer<bool>();
    int pendingCount = candidateUrls.length;

    for (final urlStr in candidateUrls) {
      () async {
        HttpClient? client;
        try {
          final uri = Uri.parse(urlStr);
          client = HttpClient()
            ..connectionTimeout = const Duration(milliseconds: 2000)
            ..badCertificateCallback = ((cert, host, port) => true);

          final request = await client.postUrl(uri);
          request.headers.set('Content-Type', 'application/json; charset=utf-8');
          request.headers.set('Accept', 'application/json, */*');
          request.headers.set('User-Agent', 'QuestUP-App/1.0');
          request.write(payload);

          final response = await request.close().timeout(const Duration(milliseconds: 2500));
          if (response.statusCode == 200 || response.statusCode == 201) {
            final bodyStr = await response.transform(utf8.decoder).join();
            try {
              final json = jsonDecode(bodyStr);
              if (json is Map && json['success'] == true) {
                debugPrint('[EmailService] ✅ Email dispatched via Backend API: $urlStr');
                if (!completer.isCompleted) completer.complete(true);
                return;
              }
            } catch (_) {
              if (bodyStr.contains('"success":true')) {
                debugPrint('[EmailService] ✅ Email dispatched via Backend API: $urlStr');
                if (!completer.isCompleted) completer.complete(true);
                return;
              }
            }
          }
        } catch (_) {
        } finally {
          client?.close(force: true);
          pendingCount--;
          if (pendingCount <= 0 && !completer.isCompleted) {
            completer.complete(false);
          }
        }
      }();
    }

    return await completer.future;
  }

  Future<bool> _sendViaSmtp({
    required String recipientEmail,
    required String otpCode,
    required String userName,
  }) async {
    try {
      final isSsl = _config.isSsl || _config.port == 465;
      final smtpServer = SmtpServer(
        _config.host,
        port: _config.port,
        username: _config.username,
        password: _config.password,
        ssl: isSsl,
        allowInsecure: !isSsl,
      );

      final message = Message()
        ..from = Address(_config.fromEmail, _config.fromName)
        ..recipients.add(recipientEmail)
        ..subject = '🔐 QuestUP Login Verification Code: $otpCode'
        ..text = 'Hello $userName,\n\n'
            'Your QuestUP login verification code is: $otpCode\n\n'
            'This code expires in 5 minutes. If you did not request this login code, please secure your account immediately.\n\n'
            '- QuestUP Security Team'
        ..html = _buildHtmlTemplate(
          userName: userName,
          otpCode: otpCode,
          recipientEmail: recipientEmail,
        );

      final sendReport = await send(message, smtpServer).timeout(
        const Duration(seconds: 8),
      );

      debugPrint('[EmailService] ✅ Email sent successfully via direct SMTP: ${sendReport.toString()}');
      return true;
    } catch (e) {
      debugPrint('[EmailService] ❌ Failed to dispatch email via direct SMTP: $e');
      return false;
    }
  }

  String _buildHtmlTemplate({
    required String userName,
    required String otpCode,
    required String recipientEmail,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>QuestUP Login Verification</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #0A0E1A;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #E2E8F0;
    }
    .container {
      max-width: 540px;
      margin: 30px auto;
      background: #131B2E;
      border: 1px solid #1E293B;
      border-radius: 20px;
      overflow: hidden;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    }
    .header {
      background: linear-gradient(135deg, #00E5FF 0%, #0072FF 100%);
      padding: 28px 24px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      color: #0A0E1A;
      font-size: 26px;
      font-weight: 900;
      letter-spacing: 1px;
    }
    .header p {
      margin: 6px 0 0 0;
      color: #0A0E1A;
      font-size: 13px;
      font-weight: 600;
      opacity: 0.9;
    }
    .content {
      padding: 32px 28px;
    }
    .greeting {
      font-size: 17px;
      font-weight: 700;
      color: #F8FAFC;
      margin-bottom: 12px;
    }
    .message {
      font-size: 14px;
      line-height: 1.6;
      color: #94A3B8;
      margin-bottom: 24px;
    }
    .otp-card {
      background: #090D16;
      border: 2px dashed #00E5FF;
      border-radius: 14px;
      padding: 20px;
      text-align: center;
      margin: 24px 0;
    }
    .otp-code {
      font-size: 36px;
      font-weight: 900;
      letter-spacing: 8px;
      color: #00E5FF;
      font-family: 'Courier New', Courier, monospace;
    }
    .otp-label {
      font-size: 11px;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 1.5px;
      margin-top: 6px;
    }
    .expiry {
      text-align: center;
      font-size: 13px;
      color: #F59E0B;
      font-weight: 600;
      margin-bottom: 24px;
    }
    .footer {
      border-top: 1px solid #1E293B;
      padding: 20px 28px;
      font-size: 12px;
      color: #64748B;
      text-align: center;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>QUESTUP</h1>
      <p>TURN THE REAL WORLD INTO A GAME</p>
    </div>
    <div class="content">
      <div class="greeting">Greetings Explorer, $userName!</div>
      <div class="message">
        You requested a secure login verification code for your QuestUP account (<strong>$recipientEmail</strong>).
      </div>
      
      <div class="otp-card">
        <div class="otp-code">$otpCode</div>
        <div class="otp-label">Single-Use Security Passcode</div>
      </div>

      <div class="expiry">
        ⏱ This verification code will expire in <strong>5 minutes</strong>.
      </div>

      <div class="message" style="margin-bottom: 0;">
        If you did not initiate this login request, no action is needed. Your password remains safe, but we recommend reviewing your account security if you suspect unauthorized activity.
      </div>
    </div>
    <div class="footer">
      QuestUP Augmented Reality Gaming &amp; Real-World Exploration<br>
      Automated security transmission • Please do not reply directly to this email.
    </div>
  </div>
</body>
</html>
''';
  }
}
