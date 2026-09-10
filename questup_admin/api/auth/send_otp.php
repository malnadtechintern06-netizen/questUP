<?php
/**
 * QuestUP REST API - Send Login Verification OTP Email
 * Endpoint: POST /backend/api/auth/send_otp.php or /api/auth/send_otp.php
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 1. Parse JSON input or Form POST
$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$recipientEmail = trim($data['recipient_email'] ?? $data['email'] ?? '');
$otpCode = trim($data['otp_code'] ?? $data['otp'] ?? '');
$userName = trim($data['user_name'] ?? $data['name'] ?? '');

if (empty($recipientEmail) || !filter_var($recipientEmail, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'A valid recipient_email is required.',
    ]);
    exit;
}

if (empty($otpCode) || strlen($otpCode) < 4) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'A valid otp_code is required.',
    ]);
    exit;
}

if (empty($userName)) {
    $parts = explode('@', $recipientEmail);
    $userName = $parts[0];
}

$otpId = 'otp_' . bin2hex(random_bytes(16));
$expiresAt = date('Y-m-d H:i:s', time() + (5 * 60)); // 5 minutes expiry

// 2. Record to MySQL Database (if available)
$dbRecorded = false;
$dbError = null;
try {
    $dbFile = __DIR__ . '/../../config/database.php';
    if (file_exists($dbFile)) {
        require_once $dbFile;
        if (function_exists('db')) {
            $pdo = db();
            if ($pdo instanceof PDO) {
                // Invalidate old active OTPs for this email
                $updStmt = $pdo->prepare("UPDATE email_otps SET is_used = 1 WHERE email = :email AND is_used = 0");
                $updStmt->execute(['email' => $recipientEmail]);

                // Insert new OTP
                $insStmt = $pdo->prepare("
                    INSERT INTO email_otps (id, email, otp_code, expires_at, is_used, created_at)
                    VALUES (:id, :email, :otp, :exp, 0, NOW())
                ");
                $insStmt->execute([
                    'id' => $otpId,
                    'email' => $recipientEmail,
                    'otp' => $otpCode,
                    'exp' => $expiresAt,
                ]);
                $dbRecorded = true;
            }
        }
    }
} catch (Throwable $e) {
    $dbError = $e->getMessage();
}

// 3. Compose HTML Email Content
$subject = "🔐 QuestUP Login Verification Code: {$otpCode}";
$fromEmail = 'security@questup.app';
$fromName = 'QuestUP Security';

$htmlBody = <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
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
      <div class="greeting">Greetings Explorer, {$userName}!</div>
      <div class="message">
        You requested a secure login verification code for your QuestUP account (<strong>{$recipientEmail}</strong>).
      </div>
      
      <div class="otp-card">
        <div class="otp-code">{$otpCode}</div>
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
HTML;

// 4. Dispatch Email via PHP mail()
$headers = [
    'MIME-Version: 1.0',
    'Content-Type: text/html; charset=UTF-8',
    'From: ' . $fromName . ' <' . $fromEmail . '>',
    'Reply-To: ' . $fromEmail,
    'X-Mailer: PHP/' . phpversion(),
];

$mailSent = false;
try {
    // Attempt standard PHP mail
    $mailSent = @mail($recipientEmail, $subject, $htmlBody, implode("\r\n", $headers));
} catch (Throwable $e) {
    $mailSent = false;
}

// 5. Build Response
http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'OTP generated and dispatched successfully.',
    'otp_id' => $otpId,
    'email' => $recipientEmail,
    'expires_at' => $expiresAt,
    'mail_dispatched' => $mailSent,
    'db_recorded' => $dbRecorded,
    'db_error' => $dbError,
]);
