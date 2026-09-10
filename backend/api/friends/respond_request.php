<?php
/**
 * QuestUP REST API - Accept or Reject a Friend Request
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

$requestId = trim((string)($data['request_id'] ?? $_GET['request_id'] ?? ''));
$action = strtolower(trim((string)($data['action'] ?? $_GET['action'] ?? 'accept'))); // 'accept' or 'reject'
$currentUserId = trim((string)($data['user_id'] ?? $_GET['user_id'] ?? ''));

if ($requestId === '') {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Request ID is required.',
    ]);
    exit;
}

if (!in_array($action, ['accept', 'reject'], true)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid action. Must be accept or reject.',
    ]);
    exit;
}

$db = db();

try {
    $stmt = $db->prepare("SELECT * FROM friend_requests WHERE id = :id LIMIT 1");
    $stmt->execute(['id' => $requestId]);
    $req = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$req) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Friend request not found.',
        ]);
        exit;
    }

    // If currentUserId provided, ensure they are the recipient or authorized participant
    if ($currentUserId !== '' && $req['receiver_id'] !== $currentUserId && $req['sender_id'] !== $currentUserId) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'You are not authorized to respond to this friend request.',
        ]);
        exit;
    }

    if ($action === 'accept') {
        $upStmt = $db->prepare("UPDATE friend_requests SET status = 'accepted', updated_at = NOW() WHERE id = :id");
        $upStmt->execute(['id' => $requestId]);

        // Insert bidirectional entries into user_friends cache table
        $insFriend = $db->prepare("
            INSERT IGNORE INTO user_friends (id, user_id, friend_id, created_at)
            VALUES (:id, :u, :f, NOW())
        ");
        $insFriend->execute([
            'id' => bin2hex(random_bytes(16)),
            'u'  => $req['sender_id'],
            'f'  => $req['receiver_id'],
        ]);
        $insFriend->execute([
            'id' => bin2hex(random_bytes(16)),
            'u'  => $req['receiver_id'],
            'f'  => $req['sender_id'],
        ]);

        logActivity(
            $req['receiver_id'],
            'friend_request_accepted',
            "Accepted friend request from player ID {$req['sender_id']}",
            $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
        );

        echo json_encode([
            'success' => true,
            'status'  => 'accepted',
            'message' => 'Friend request accepted! Mutual squad friendship established.',
        ]);
    } else {
        $upStmt = $db->prepare("UPDATE friend_requests SET status = 'rejected', updated_at = NOW() WHERE id = :id");
        $upStmt->execute(['id' => $requestId]);

        // Clean up from user_friends if any
        $delFriend = $db->prepare("
            DELETE FROM user_friends 
            WHERE (user_id = :u AND friend_id = :f) OR (user_id = :f AND friend_id = :u)
        ");
        $delFriend->execute([
            'u' => $req['sender_id'],
            'f' => $req['receiver_id'],
        ]);

        logActivity(
            $req['receiver_id'],
            'friend_request_rejected',
            "Declined friend request from player ID {$req['sender_id']}",
            $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
        );

        echo json_encode([
            'success' => true,
            'status'  => 'rejected',
            'message' => 'Friend request declined.',
        ]);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error updating friend request: ' . $e->getMessage(),
    ]);
}
