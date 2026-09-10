<?php
/**
 * QuestUP REST API - Check Quest Verification Status
 * Endpoint: GET /api/quests/verification_status.php?attempt_id=...&user_id=...
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$attemptId = trim($_GET['attempt_id'] ?? '');
$questId = trim($_GET['quest_id'] ?? '');
$userId = trim($_GET['user_id'] ?? '');

if (empty($userId) || (empty($attemptId) && empty($questId))) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'user_id and either attempt_id or quest_id are required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Check completion status first
    if (!empty($questId)) {
        $cmpStmt = $db->prepare("
            SELECT id, quest_id, user_id, verification_type, status, xp_earned, coins_earned, completed_at, review_notes
            FROM quest_completions
            WHERE quest_id = :qid AND user_id = :uid
            LIMIT 1
        ");
        $cmpStmt->execute(['qid' => $questId, 'uid' => $userId]);
        $cmp = $cmpStmt->fetch();

        if ($cmp) {
            echo json_encode([
                'success' => true,
                'status' => $cmp['status'], // 'verified', 'pending', 'rejected'
                'is_completed' => ($cmp['status'] === 'verified'),
                'xp_earned' => (int)$cmp['xp_earned'],
                'coins_earned' => (int)$cmp['coins_earned'],
                'completed_at' => $cmp['completed_at'],
                'review_notes' => $cmp['review_notes'],
            ]);
            exit;
        }
    }

    // 2. Check verification attempt status
    if (!empty($attemptId)) {
        $attStmt = $db->prepare("
            SELECT id, attempt_id, user_id, quest_id, verification_type, status, failure_reason, is_suspicious, created_at, verified_at
            FROM quest_verification_attempts
            WHERE attempt_id = :aid AND user_id = :uid
            LIMIT 1
        ");
        $attStmt->execute(['aid' => $attemptId, 'uid' => $userId]);
        $att = $attStmt->fetch();

        if ($att) {
            echo json_encode([
                'success' => true,
                'status' => $att['status'],
                'is_completed' => ($att['status'] === 'approved'),
                'failure_reason' => $att['failure_reason'],
                'is_suspicious' => (bool)$att['is_suspicious'],
                'verified_at' => $att['verified_at'],
            ]);
            exit;
        }
    }

    echo json_encode([
        'success' => true,
        'status' => 'not_started',
        'is_completed' => false,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
    ]);
}
