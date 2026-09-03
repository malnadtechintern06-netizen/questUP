<?php
/**
 * QuestUP REST API - Accept or Reject a Friend Request
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

$requestId = trim($data['request_id'] ?? '');
$action = strtolower(trim($data['action'] ?? 'accept')); // 'accept' or 'reject'
$currentUserId = trim($data['user_id'] ?? '');

if ($requestId === '') {
    echo json_encode([
        'success' => false,
        'message' => 'Request ID is required.',
    ]);
    exit;
}

$db = db();

try {
    $stmt = $db->prepare("SELECT * FROM friend_requests WHERE id = :id LIMIT 1");
    $stmt->execute(['id' => $requestId]);
    $req = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$req) {
        echo json_encode([
            'success' => false,
            'message' => 'Friend request not found.',
        ]);
        exit;
    }

    if ($action === 'accept') {
        $upStmt = $db->prepare("UPDATE friend_requests SET status = 'accepted', updated_at = NOW() WHERE id = :id");
        $upStmt->execute(['id' => $requestId]);

        // Insert into user_friends
        $fId = sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );

        $insFriend = $db->prepare("
            INSERT IGNORE INTO user_friends (id, user_id, friend_id, created_at)
            VALUES (:id, :u, :f, NOW())
        ");
        $insFriend->execute([
            'id' => $fId,
            'u'  => $req['sender_id'],
            'f'  => $req['receiver_id'],
        ]);

        echo json_encode([
            'success' => true,
            'message' => 'Friend request accepted! Added to your squad.',
        ]);
    } else {
        $upStmt = $db->prepare("UPDATE friend_requests SET status = 'rejected', updated_at = NOW() WHERE id = :id");
        $upStmt->execute(['id' => $requestId]);

        echo json_encode([
            'success' => true,
            'message' => 'Friend request rejected.',
        ]);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error updating friend request: ' . $e->getMessage(),
    ]);
}
