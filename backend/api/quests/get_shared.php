<?php
/**
 * QuestUP REST API - Get Shared Quests for User
 * Endpoint: GET /api/quests/get_shared.php?user_id={userId}
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$userId = trim((string)($_GET['user_id'] ?? $_GET['current_user_id'] ?? ''));

if ($userId === '') {
    echo json_encode([
        'success' => false,
        'message' => 'user_id is required.',
        'shared_quests' => [],
    ]);
    exit;
}

$db = db();

try {
    // 1. Fetch user real id if tag was passed
    $uStmt = $db->prepare("SELECT id FROM users WHERE id = :id OR player_id = :pid LIMIT 1");
    $uStmt->execute(['id' => $userId, 'pid' => $userId]);
    $userRow = $uStmt->fetch(PDO::FETCH_ASSOC);
    $realUserId = $userRow ? $userRow['id'] : $userId;

    // 2. Fetch quests shared WITH this user (incoming assist requests)
    $inStmt = $db->prepare("
        SELECT sq.*, u.player_id AS sender_resolved_tag
        FROM shared_quests sq
        LEFT JOIN users u ON u.id = sq.sender_id
        WHERE sq.receiver_id = :uid
        ORDER BY sq.created_at DESC
        LIMIT 20
    ");
    $inStmt->execute(['uid' => $realUserId]);
    $incoming = $inStmt->fetchAll(PDO::FETCH_ASSOC);

    // 3. Fetch quests shared BY this user (outgoing assist requests)
    $outStmt = $db->prepare("
        SELECT sq.*, u.player_id AS receiver_resolved_tag, u.name AS receiver_resolved_name
        FROM shared_quests sq
        LEFT JOIN users u ON u.id = sq.receiver_id
        WHERE sq.sender_id = :uid
        ORDER BY sq.created_at DESC
        LIMIT 20
    ");
    $outStmt->execute(['uid' => $realUserId]);
    $outgoing = $outStmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'success'         => true,
        'incoming_shared' => $incoming,
        'outgoing_shared' => $outgoing,
    ]);
} catch (PDOException $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
        'incoming_shared' => [],
        'outgoing_shared' => [],
    ]);
}
