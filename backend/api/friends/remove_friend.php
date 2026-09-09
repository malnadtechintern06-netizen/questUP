<?php
/**
 * QuestUP REST API - Remove Friend from Squad
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

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$userId = trim((string)($data['user_id'] ?? $_GET['user_id'] ?? ''));
$friendUserId = trim((string)($data['friend_user_id'] ?? $data['target_id'] ?? $_GET['friend_user_id'] ?? ''));

if ($userId === '' || $friendUserId === '') {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID and Friend User ID are required.',
    ]);
    exit;
}

$db = db();

try {
    // Resolve friend user ID if player_id tag was passed
    $fStmt = $db->prepare("SELECT id, player_id, name FROM users WHERE id = :id OR UPPER(player_id) = UPPER(:tag) LIMIT 1");
    $fStmt->execute(['id' => $friendUserId, 'tag' => $friendUserId]);
    $friend = $fStmt->fetch(PDO::FETCH_ASSOC);

    if ($friend) {
        $resolvedFriendId = $friend['id'];
    } else {
        $resolvedFriendId = $friendUserId;
    }

    // 1. Update friend_requests status to cancelled
    $updReq = $db->prepare("
        UPDATE friend_requests
        SET status = 'cancelled', updated_at = NOW()
        WHERE (sender_id = :u1 AND receiver_id = :f1)
           OR (sender_id = :f2 AND receiver_id = :u2)
    ");
    $updReq->execute([
        'u1' => $userId,
        'f1' => $resolvedFriendId,
        'f2' => $resolvedFriendId,
        'u2' => $userId,
    ]);

    // 2. Delete bidirectional entries from user_friends
    $delUf = $db->prepare("
        DELETE FROM user_friends
        WHERE (user_id = :u1 AND friend_id = :f1)
           OR (user_id = :f2 AND friend_id = :u2)
    ");
    $delUf->execute([
        'u1' => $userId,
        'f1' => $resolvedFriendId,
        'f2' => $resolvedFriendId,
        'u2' => $userId,
    ]);

    echo json_encode([
        'success' => true,
        'message' => 'Friend removed from squad successfully.',
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error removing friend: ' . $e->getMessage(),
    ]);
}
