<?php
/**
 * QuestUP REST API - List Discovered Players for Add Friend Tab
 * Returns available players with their permanent Player IDs.
 * Strictly excludes private quest history.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$currentUserId = trim((string)($_GET['user_id'] ?? $_GET['current_user_id'] ?? ''));
$limit = min(50, max(5, (int)($_GET['limit'] ?? 15)));

$db = db();

try {
    // 1. Resolve current user ID if player_id was passed
    $resolvedUid = $currentUserId;
    if (!empty($currentUserId)) {
        $uStmt = $db->prepare("SELECT id FROM users WHERE id = :id OR UPPER(player_id) = UPPER(:tag) LIMIT 1");
        $uStmt->execute(['id' => $currentUserId, 'tag' => $currentUserId]);
        $uRow = $uStmt->fetch(PDO::FETCH_ASSOC);
        if ($uRow) {
            $resolvedUid = $uRow['id'];
        }
    }

    // 2. Fetch players excluding self and already accepted friends
    $sql = "
        SELECT 
            u.id,
            u.player_id,
            u.name AS username,
            COALESCE(up.name, u.name) AS display_name,
            COALESCE(up.avatar_key, 'avatar_1') AS avatar_url,
            COALESCE(up.level, 1) AS level,
            COALESCE(up.current_xp, 0) AS xp,
            COALESCE(up.coins, 100) AS coins,
            (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count,
            (SELECT status FROM friend_requests 
             WHERE ((sender_id = :curr1 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = :curr2))
             ORDER BY id DESC LIMIT 1) AS friendship_status,
            (SELECT sender_id FROM friend_requests 
             WHERE ((sender_id = :curr3 AND receiver_id = u.id) OR (sender_id = u.id AND receiver_id = :curr4))
             ORDER BY id DESC LIMIT 1) AS last_sender_id
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE u.id != :self_id
          AND u.player_id IS NOT NULL 
          AND u.player_id != ''
        ORDER BY u.created_at DESC
        LIMIT :limit
    ";

    $stmt = $db->prepare($sql);
    $stmt->bindValue(':curr1', $resolvedUid, PDO::PARAM_STR);
    $stmt->bindValue(':curr2', $resolvedUid, PDO::PARAM_STR);
    $stmt->bindValue(':curr3', $resolvedUid, PDO::PARAM_STR);
    $stmt->bindValue(':curr4', $resolvedUid, PDO::PARAM_STR);
    $stmt->bindValue(':self_id', $resolvedUid, PDO::PARAM_STR);
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $players = [];

    foreach ($rows as $row) {
        $rawStatus = (string)($row['friendship_status'] ?? '');
        $senderId = (string)($row['last_sender_id'] ?? '');

        $calcStatus = 'none';
        $isFriend = false;

        if ($rawStatus === 'accepted') {
            $calcStatus = 'accepted';
            $isFriend = true;
        } elseif ($rawStatus === 'pending') {
            $calcStatus = ($senderId === $resolvedUid) ? 'pending_sent' : 'pending_received';
        }

        $players[] = [
            'id'                     => (string)$row['id'],
            'user_id'                => (string)$row['id'],
            'player_id'              => (string)$row['player_id'],
            'display_name'           => (string)$row['display_name'],
            'username'               => (string)$row['username'],
            'avatar_url'             => (string)$row['avatar_url'],
            'level'                  => (int)$row['level'],
            'current_xp'             => (int)$row['xp'],
            'coins'                  => (int)$row['coins'],
            'completed_quests_count' => (int)$row['completed_quests_count'],
            'friendship_status'      => $calcStatus,
            'is_friend'              => $isFriend,
        ];
    }

    echo json_encode([
        'success' => true,
        'count'   => count($players),
        'players' => $players,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to query player database: ' . $e->getMessage(),
    ]);
}
