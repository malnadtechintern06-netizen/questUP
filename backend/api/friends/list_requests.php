<?php
/**
 * QuestUP REST API - List Friends & Pending Requests for a user
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$userId = trim($_GET['user_id'] ?? $_POST['user_id'] ?? '');

if ($userId === '') {
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Pending incoming requests
    $inStmt = $db->prepare("
        SELECT r.id, r.sender_id, r.receiver_id, r.sender_tag, r.receiver_tag, r.status, r.created_at,
               u.name as sender_name, u.email as sender_email,
               COALESCE(up.avatar_key, 'adventurer_default') as sender_avatar_key,
               COALESCE(up.level, 1) as sender_level
        FROM friend_requests r
        JOIN users u ON r.sender_id = u.id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE r.receiver_id = :uid AND r.status = 'pending'
        ORDER BY r.created_at DESC
    ");
    $inStmt->execute(['uid' => $userId]);
    $incoming = $inStmt->fetchAll(PDO::FETCH_ASSOC);

    // 2. Sent outgoing requests
    $outStmt = $db->prepare("
        SELECT r.id, r.sender_id, r.receiver_id, r.sender_tag, r.receiver_tag, r.status, r.created_at,
               u.name as receiver_name, u.email as receiver_email,
               COALESCE(up.avatar_key, 'adventurer_default') as receiver_avatar_key,
               COALESCE(up.level, 1) as receiver_level
        FROM friend_requests r
        JOIN users u ON r.receiver_id = u.id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE r.sender_id = :uid AND r.status = 'pending'
        ORDER BY r.created_at DESC
    ");
    $outStmt->execute(['uid' => $userId]);
    $outgoing = $outStmt->fetchAll(PDO::FETCH_ASSOC);

    // 3. Accepted Friends
    $fStmt = $db->prepare("
        SELECT u.id, u.player_id, u.name, u.email,
               COALESCE(up.avatar_key, 'adventurer_default') as avatar_key,
               COALESCE(up.level, 1) as level,
               COALESCE(up.current_xp, 0) as current_xp,
               COALESCE(up.coins, 100) as coins,
               (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id) as completed_quests_count,
               f.created_at as friendship_date
        FROM user_friends f
        JOIN users u ON (f.friend_id = u.id AND f.user_id = :uid) OR (f.user_id = u.id AND f.friend_id = :uid)
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE u.id != :uid
        ORDER BY f.created_at DESC
    ");
    $fStmt->execute(['uid' => $userId]);
    $friends = $fStmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'success'           => true,
        'incoming_requests' => $incoming,
        'outgoing_requests' => $outgoing,
        'friends'           => $friends,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error loading friends: ' . $e->getMessage(),
    ]);
}
