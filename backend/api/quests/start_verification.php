<?php
/**
 * QuestUP REST API - Start Quest Verification Attempt & Issue Server Challenge
 * Endpoint: POST /api/quests/start_verification.php
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

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/activity_logger.php';
require_once __DIR__ . '/perceptual_hash.php';

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$questId = trim($data['quest_id'] ?? '');
$userId = trim($data['user_id'] ?? '');
$deviceId = trim($data['device_id'] ?? '');
$deviceInfo = trim($data['device_info'] ?? '');
$ipAddress = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';

if (empty($questId) || empty($userId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'quest_id and user_id are required to initiate quest verification.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Authenticate user
    $userStmt = $db->prepare("SELECT id, name, email, status FROM users WHERE id = :uid LIMIT 1");
    $userStmt->execute(['uid' => $userId]);
    $user = $userStmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'User authentication failed: Account not found.',
        ]);
        exit;
    }

    if (($user['status'] ?? 'active') === 'banned') {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Account access restricted. Please contact support.',
        ]);
        exit;
    }

    // 2. Fetch authoritative Quest details
    $qStmt = $db->prepare("SELECT * FROM quests WHERE id = :qid LIMIT 1");
    $qStmt->execute(['qid' => $questId]);
    $quest = $qStmt->fetch();

    if (!$quest) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Quest not found.',
        ]);
        exit;
    }

    if ((int)($quest['is_active'] ?? 1) !== 1) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'This quest is currently inactive or closed.',
        ]);
        exit;
    }

    // 3. Database-level Duplicate Completion Check
    $dupStmt = $db->prepare("SELECT id, completed_at, status FROM quest_completions WHERE quest_id = :qid AND user_id = :uid LIMIT 1");
    $dupStmt->execute(['qid' => $questId, 'uid' => $userId]);
    $existing = $dupStmt->fetch();

    if ($existing) {
        echo json_encode([
            'success' => false,
            'is_duplicate' => true,
            'message' => 'Quest already completed! Rewards have already been claimed.',
            'completion_status' => $existing['status'],
        ]);
        exit;
    }

    // 4. Rate-limit in-flight attempt creations (max 10 active started attempts in last 10 minutes)
    $rateStmt = $db->prepare("
        SELECT COUNT(*) as active_cnt 
        FROM quest_verification_attempts 
        WHERE user_id = :uid AND status = 'started' AND created_at >= NOW() - INTERVAL 10 MINUTE
    ");
    $rateStmt->execute(['uid' => $userId]);
    $activeCount = (int)($rateStmt->fetch()['active_cnt'] ?? 0);

    if ($activeCount >= 10) {
        // Expire older stale started attempts
        $db->prepare("
            UPDATE quest_verification_attempts 
            SET status = 'rejected', failure_reason = 'Stale attempt expired by new challenge request' 
            WHERE user_id = :uid AND status = 'started' AND created_at < NOW() - INTERVAL 5 MINUTE
        ")->execute(['uid' => $userId]);
    }

    // 5. Generate Cryptographic Challenge & Attempt
    $attemptId = 'att_' . bin2hex(random_bytes(16));
    $challengeToken = bin2hex(random_bytes(32));
    $verificationType = $quest['verification_type'] ?? 'locationGps';

    $insAttempt = $db->prepare("
        INSERT INTO quest_verification_attempts (
            id, attempt_id, user_id, quest_id, verification_type,
            challenge_token, device_id, device_info, ip_address,
            status, started_at, expires_at, created_at
        ) VALUES (
            :id, :att_id, :uid, :qid, :vtype,
            :token, :dev_id, :dev_info, :ip,
            'started', NOW(), NOW() + INTERVAL 15 MINUTE, NOW()
        )
    ");

    $insAttempt->execute([
        'id' => 'rec_' . bin2hex(random_bytes(16)),
        'att_id' => $attemptId,
        'uid' => $userId,
        'qid' => $questId,
        'vtype' => $verificationType,
        'token' => $challengeToken,
        'dev_id' => $deviceId ?: null,
        'dev_info' => $deviceInfo ?: null,
        'ip' => $ipAddress,
    ]);

    logActivity(
        $userId,
        'quest_started',
        "Started verification attempt for quest '{$quest['title']}' ({$questId})",
        $ipAddress
    );

    // 6. Build sanitized quest requirements for client (never sending correct answers)
    $requirements = [
        'verification_type' => $verificationType,
        'requires_gps' => (bool)($quest['requires_gps'] ?? ($verificationType === 'locationGps' || $verificationType === 'walkingGps')),
        'requires_photo' => (bool)($quest['requires_photo'] ?? ($verificationType === 'photoProof')),
        'allow_gallery_upload' => (bool)($quest['allow_gallery_upload'] ?? 0),
        'min_duration_seconds' => (int)($quest['min_duration_seconds'] ?? ($quest['required_duration_seconds'] ?? 0)),
        'radius_meters' => (float)($quest['radius_meters'] ?? 150.0),
        'target_location_name' => $quest['location_name'] ?? 'Target Area',
        'required_object' => $quest['required_object'] ?? null,
        'required_place' => $quest['required_place'] ?? null,
        'required_target' => $quest['required_target'] ?? null,
        'required_words' => (int)($quest['required_words'] ?? 0),
        'required_distance_meters' => (float)($quest['required_distance_meters'] ?? 0.0),
    ];

    // Sanitize Quiz Questions if quiz quest
    if (!empty($quest['quiz_data_json'])) {
        $quizRaw = json_decode($quest['quiz_data_json'], true);
        if (is_array($quizRaw)) {
            $sanitizedQuiz = [];
            foreach ($quizRaw as $q) {
                $sanitizedQuiz[] = [
                    'id' => $q['id'] ?? bin2hex(random_bytes(4)),
                    'question' => $q['question'] ?? '',
                    'options' => $q['options'] ?? [],
                    // Deliberately omit 'correct_index' or 'correct_answer'
                ];
            }
            $requirements['quiz_questions'] = $sanitizedQuiz;
        }
    }

    echo json_encode([
        'success' => true,
        'message' => 'Verification challenge generated.',
        'attempt_id' => $attemptId,
        'challenge_token' => $challengeToken,
        'quest_id' => $questId,
        'verification_type' => $verificationType,
        'expires_in_seconds' => 900, // 15 minutes
        'server_timestamp' => date('Y-m-d H:i:s'),
        'requirements' => $requirements,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to initialize verification challenge: ' . $e->getMessage(),
    ]);
}
