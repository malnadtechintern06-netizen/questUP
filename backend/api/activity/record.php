<?php
/**
 * QuestUP REST API - Record Activity
 * Endpoint: POST /api/activity/record.php
 *
 * Records user activities, quest attempts, calendar events, and achievements
 * into `activity_logs` table so they are instantly visible in phpMyAdmin.
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

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$userId = trim($data['user_id'] ?? '');
$action = trim($data['action'] ?? '');
$details = $data['details'] ?? null;
$questId = trim($data['quest_id'] ?? '');
$questTitle = trim($data['quest_title'] ?? '');
$status = trim($data['status'] ?? '');
$xpReward = (int)($data['xp_reward'] ?? $data['xp'] ?? 0);
$coinReward = (int)($data['coin_reward'] ?? $data['coins'] ?? 0);

if (empty($action)) {
    if (!empty($questId) || !empty($questTitle)) {
        $action = 'quest_activity';
    } else {
        $action = 'user_activity';
    }
}

// Build descriptive details text if details is null or empty
if (empty($details)) {
    $detailParts = [];
    if (!empty($questTitle)) {
        $detailParts[] = "Quest: '{$questTitle}'";
    }
    if (!empty($status)) {
        $detailParts[] = "Status: {$status}";
    }
    if ($xpReward > 0 || $coinReward > 0) {
        $detailParts[] = "Rewards: +{$xpReward} XP, +{$coinReward} Coins";
    }
    if (!empty($data['category'])) {
        $detailParts[] = "Category: " . $data['category'];
    }
    if (!empty($data['difficulty'])) {
        $detailParts[] = "Difficulty: " . $data['difficulty'];
    }
    if (!empty($data['failure_reason'])) {
        $detailParts[] = "Failure: " . $data['failure_reason'];
    }
    $details = !empty($detailParts) ? implode(' | ', $detailParts) : 'Activity recorded';
} elseif (is_array($details)) {
    $details = json_encode($details, JSON_UNESCAPED_UNICODE);
}

$ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';

$logged = logActivity(
    !empty($userId) ? $userId : null,
    $action,
    (string)$details,
    $ip
);

if ($logged) {
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Activity recorded successfully',
        'action' => $action,
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to record activity in database',
    ]);
}
