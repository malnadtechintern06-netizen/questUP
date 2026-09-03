<?php
/**
 * QuestUP REST API - Send Friend Request
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$senderId = trim($data['sender_id'] ?? '');
$targetTagOrId = trim($data['target_tag'] ?? $data['receiver_id'] ?? $data['target_id'] ?? '');

if ($senderId === '' || $targetTagOrId === '') {
    echo json_encode([
        'success' => false,
        'message' => 'Sender ID and Target Player Tag/ID are required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Fetch sender info
    $sStmt = $db->prepare("SELECT id, player_id, name, email FROM users WHERE id = :id LIMIT 1");
    $sStmt->execute(['id' => $senderId]);
    $sender = $sStmt->fetch(PDO::FETCH_ASSOC);

    if (!$sender) {
        echo json_encode([
            'success' => false,
            'message' => 'Sender user account not found.',
        ]);
        exit;
    }

    $senderTag = $sender['player_id'] ?? ('QST-' . substr(md5($sender['id']), 0, 4));

    // Normalize target tag
    $cleanTargetTag = strtoupper($targetTagOrId);
    if (preg_match('/^(?:QST[\s\-_]*)?(\d+)$/i', $targetTagOrId, $m)) {
        $cleanTargetTag = 'QST-' . $m[1];
    }

    // 2. Fetch target user info
    $tStmt = $db->prepare("
        SELECT id, player_id, name, email
        FROM users
        WHERE UPPER(player_id) = UPPER(:tag) OR id = :tid OR UPPER(name) = UPPER(:tname)
        LIMIT 1
    ");
    $tStmt->execute([
        'tag'   => $cleanTargetTag,
        'tid'   => $targetTagOrId,
        'tname' => $targetTagOrId,
    ]);
    $target = $tStmt->fetch(PDO::FETCH_ASSOC);

    if (!$target) {
        echo json_encode([
            'success' => false,
            'message' => "Player '{$targetTagOrId}' not found.",
        ]);
        exit;
    }

    $receiverId = $target['id'];
    $receiverTag = $target['player_id'] ?? $cleanTargetTag;

    // Prevent self-request
    if ($senderId === $receiverId || strtoupper($senderTag) === strtoupper($receiverTag)) {
        echo json_encode([
            'success' => false,
            'message' => 'You cannot send a friend request to yourself.',
        ]);
        exit;
    }

    // Check if already friends
    $fStmt = $db->prepare("
        SELECT id FROM user_friends
        WHERE (user_id = :s1 AND friend_id = :r1) OR (user_id = :r2 AND friend_id = :s2)
        LIMIT 1
    ");
    $fStmt->execute(['s1' => $senderId, 'r1' => $receiverId, 'r2' => $receiverId, 's2' => $senderId]);
    if ($fStmt->fetch()) {
        echo json_encode([
            'success' => false,
            'message' => "{$target['name']} is already in your friends squad.",
        ]);
        exit;
    }

    // Check if duplicate pending request exists
    $reqStmt = $db->prepare("
        SELECT id, status FROM friend_requests
        WHERE (sender_id = :s3 AND receiver_id = :r3 AND status = 'pending')
           OR (sender_id = :r4 AND receiver_id = :s4 AND status = 'pending')
        LIMIT 1
    ");
    $reqStmt->execute(['s3' => $senderId, 'r3' => $receiverId, 'r4' => $receiverId, 's4' => $senderId]);
    $existing = $reqStmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        echo json_encode([
            'success' => false,
            'message' => "A pending friend request already exists with {$target['name']}.",
        ]);
        exit;
    }

    // Insert new friend request
    $requestId = sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );

    $insStmt = $db->prepare("
        INSERT INTO friend_requests (id, sender_id, receiver_id, sender_tag, receiver_tag, status, created_at)
        VALUES (:id, :s_id, :r_id, :s_tag, :r_tag, 'pending', NOW())
    ");
    $insStmt->execute([
        'id'    => $requestId,
        's_id'  => $senderId,
        'r_id'  => $receiverId,
        's_tag' => $senderTag,
        'r_tag' => $receiverTag,
    ]);

    // Record activity log
    $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    $logStmt = $db->prepare("
        INSERT INTO activity_logs (user_id, action, details, ip_address, created_at)
        VALUES (:uid, 'friend_request_sent', :details, :ip, NOW())
    ");
    $logStmt->execute([
        'uid'     => $senderId,
        'details' => "Player {$sender['name']} ({$senderTag}) sent friend request to {$target['name']} ({$receiverTag})",
        'ip'      => $ip,
    ]);

    echo json_encode([
        'success' => true,
        'message' => "Friend request sent successfully to {$target['name']} ({$receiverTag})!",
        'request' => [
            'id'           => $requestId,
            'sender_id'    => $senderId,
            'receiver_id'  => $receiverId,
            'sender_tag'   => $senderTag,
            'receiver_tag' => $receiverTag,
            'status'       => 'pending',
        ],
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error sending friend request: ' . $e->getMessage(),
    ]);
}
