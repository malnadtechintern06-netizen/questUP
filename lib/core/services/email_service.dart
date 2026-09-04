import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../app/config/email_config.dart';

abstract class IEmailService {
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
    String? userName,
  });

  EmailConfig get config;
}

class EmailService implements IEmailService {
  static final EmailService instance = EmailService();

  final EmailConfig _config;

  EmailService([EmailConfig? config]) : _config = config ?? EmailConfig.defaults();

  @override
  EmailConfig get config => _config;

  @override
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
    String? userName,
  }) async {
    final targetName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : recipientEmail.split('@').first;

    debugPrint('====================================================');
    debugPrint('[EmailService] 🔐 DISPATCHING LOGIN OTP TO: $recipientEmail');
    debugPrint('[EmailService] 🔢 ONE-TIME PASSCODE: $otpCode');
    debugPrint('[EmailService] ⏳ EXPIRES IN: 5 minutes');
    debugPrint('====================================================');

    if (!_config.isConfigured) {
      debugPrint(
        '[EmailService] ⚠️ SMTP credentials not configured (SMTP_USER / SMTP_PASS). '
        'Email logged in console for testing. Simulated delivery successful.',
      );
      return true;
    }

    try {
      final smtpServer = SmtpServer(
        _config.host,
        port: _config.port,
        username: _config.username,
        password: _config.password,
        ssl: _config.isSsl,
        allowInsecure: !_config.isSsl,
      );

      final message = Message()
        ..from = Address(_config.fromEmail, _config.fromName)
        ..recipients.add(recipientEmail)
        ..subject = '🔐 QuestUP Login Verification Code: $otpCode'
        ..text = 'Hello $targetName,\n\n'
            'Your QuestUP login verification code is: $otpCode\n\n'
            'This code expires in 5 minutes. If you did not request this login code, please secure your account immediately.\n\n'
            '- QuestUP Security Team'
        ..html = _buildHtmlTemplate(
          userName: targetName,
          otpCode: otpCode,
          recipientEmail: recipientEmail,
        );

      final sendReport = await send(message, smtpServer).timeout(
        const Duration(seconds: 8),
      );

      debugPrint('[EmailService] ✅ Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      debugPrint('[EmailService] ❌ Failed to dispatch email via SMTP: $e');
      debugPrint('[EmailService] ℹ️ You can still use the generated OTP ($otpCode) to log in.');
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
