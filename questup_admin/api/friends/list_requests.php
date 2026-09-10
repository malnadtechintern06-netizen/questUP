<?php
/**
 * QuestUP REST API - List Friends & Pending Requests for a user
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$userId = trim((string)($_GET['user_id'] ?? $_POST['user_id'] ?? ''));

if ($userId === '') {
    http_response_code(400);
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
               u.name AS sender_name, u.email AS sender_email, u.player_id AS sender_player_id,
               COALESCE(up.avatar_key, 'avatar_ranger') AS sender_avatar_key,
               COALESCE(up.level, 1) AS sender_level
        FROM friend_requests r
        JOIN users u ON r.sender_id = u.id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE r.receiver_id = :uid AND r.status = 'pending'
        ORDER BY r.created_at DESC
    ");
    $inStmt->execute(['uid' => $userId]);
    $incoming = $inStmt->fetchAll(PDO::FETCH_ASSOC);

    // Normalize sender_tag with real user player_id
    $formattedIncoming = array_map(function ($r) {
        return [
            'id'                => (string)$r['id'],
            'sender_id'         => (string)$r['sender_id'],
            'receiver_id'       => (string)$r['receiver_id'],
            'sender_tag'        => (string)($r['sender_player_id'] ?? $r['sender_tag'] ?? 'QST-0000'),
            'receiver_tag'      => (string)($r['receiver_tag'] ?? 'QST-0000'),
            'status'            => (string)$r['status'],
            'created_at'        => (string)$r['created_at'],
            'sender_name'       => (string)$r['sender_name'],
            'sender_avatar_key' => (string)$r['sender_avatar_key'],
            'sender_level'      => (int)$r['sender_level'],
        ];
    }, $incoming);

    // 2. Sent outgoing requests
    $outStmt = $db->prepare("
        SELECT r.id, r.sender_id, r.receiver_id, r.sender_tag, r.receiver_tag, r.status, r.created_at,
               u.name AS receiver_name, u.email AS receiver_email, u.player_id AS receiver_player_id,
               COALESCE(up.avatar_key, 'avatar_ranger') AS receiver_avatar_key,
               COALESCE(up.level, 1) AS receiver_level
        FROM friend_requests r
        JOIN users u ON r.receiver_id = u.id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE r.sender_id = :uid AND r.status = 'pending'
        ORDER BY r.created_at DESC
    ");
    $outStmt->execute(['uid' => $userId]);
    $outgoing = $outStmt->fetchAll(PDO::FETCH_ASSOC);

    $formattedOutgoing = array_map(function ($r) {
        return [
            'id'                  => (string)$r['id'],
            'sender_id'           => (string)$r['sender_id'],
            'receiver_id'         => (string)$r['receiver_id'],
            'sender_tag'          => (string)($r['sender_tag'] ?? 'QST-0000'),
            'receiver_tag'        => (string)($r['receiver_player_id'] ?? $r['receiver_tag'] ?? 'QST-0000'),
            'status'              => (string)$r['status'],
            'created_at'          => (string)$r['created_at'],
            'receiver_name'       => (string)$r['receiver_name'],
            'receiver_avatar_key' => (string)$r['receiver_avatar_key'],
            'receiver_level'      => (int)$r['receiver_level'],
        ];
    }, $outgoing);

    // 3. Mutual Accepted Friends (works in BOTH directions)
    $fStmt = $db->prepare("
        SELECT u.id, u.player_id, u.name, u.email,
               COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
               COALESCE(up.level, 1) AS level,
               COALESCE(up.current_xp, 0) AS current_xp,
               COALESCE(up.coins, 100) AS coins,
               (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count,
               (SELECT COUNT(*) FROM user_badges WHERE user_id = u.id) AS badges_count,
               r.updated_at AS friendship_date
        FROM friend_requests r
        JOIN users u ON (u.id = CASE WHEN r.sender_id = :uid THEN r.receiver_id ELSE r.sender_id END)
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE (r.sender_id = :uid OR r.receiver_id = :uid) 
          AND r.status = 'accepted'
          AND u.id != :uid
        ORDER BY r.updated_at DESC
    ");
    $fStmt->execute(['uid' => $userId]);
    $friends = $fStmt->fetchAll(PDO::FETCH_ASSOC);

    $formattedFriends = array_map(function ($f) {
        return [
            'id'                     => (string)$f['id'],
            'player_id'              => (string)($f['player_id'] ?? 'QST-0000'),
            'player_tag'             => (string)($f['player_id'] ?? 'QST-0000'),
            'name'                   => (string)$f['name'],
            'display_name'           => (string)$f['name'],
            'avatar_key'             => (string)$f['avatar_key'],
            'avatar_url'             => (string)$f['avatar_key'],
            'level'                  => (int)$f['level'],
            'current_xp'             => (int)$f['current_xp'],
            'xp'                     => (int)$f['current_xp'],
            'coins'                  => (int)$f['coins'],
            'completed_quests_count' => (int)$f['completed_quests_count'],
            'badges_count'           => (int)$f['badges_count'],
            'friendship_date'        => (string)$f['friendship_date'],
            'is_friend'              => true,
        ];
    }, $friends);

    echo json_encode([
        'success'           => true,
        'incoming_requests' => $formattedIncoming,
        'outgoing_requests' => $formattedOutgoing,
        'friends'           => $formattedFriends,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error loading friends: ' . $e->getMessage(),
    ]);
}
