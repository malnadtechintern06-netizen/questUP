<?php
/**
 * QuestUP REST API - Player Search by Player ID / Tag, Name, Email or UUID
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? [];

$query = trim((string)($_GET['query'] ?? $_GET['tag'] ?? $_POST['query'] ?? $_POST['tag'] ?? $data['query'] ?? $data['tag'] ?? ''));
$currentUserId = trim((string)($_GET['current_user_id'] ?? $_POST['current_user_id'] ?? $data['current_user_id'] ?? ''));

if ($query === '') {
    echo json_encode([
        'success' => false,
        'player'  => null,
        'message' => 'Please enter a valid Player ID or Explorer Name.',
    ]);
    exit;
}

$cleanQuery = trim(str_replace('#', '', $query));

// Normalize player tag: e.g. "QST-2794", "qst-2794", "2794", "QST 2794" -> "QST-2794"
$normalizedTag = strtoupper($cleanQuery);
if (preg_match('/^(?:QST[\s\-_]*)?(\d+)$/i', $cleanQuery, $matches)) {
    $normalizedTag = 'QST-' . $matches[1];
}

$db = db();

try {
    // 1. Check if user is searching for their own ID / profile
    $selfId = null;
    $selfTag = null;
    $selfName = null;
    $selfEmail = null;

    if ($currentUserId !== '') {
        $selfStmt = $db->prepare("SELECT id, player_id, name, email FROM users WHERE id = :uid OR UPPER(player_id) = UPPER(:tag) LIMIT 1");
        $selfStmt->execute(['uid' => $currentUserId, 'tag' => $currentUserId]);
        $selfUser = $selfStmt->fetch(PDO::FETCH_ASSOC);

        if ($selfUser) {
            $selfId = (string)$selfUser['id'];
            $selfTag = strtoupper((string)($selfUser['player_id'] ?? ''));
            $selfName = strtoupper((string)$selfUser['name']);
            $selfEmail = strtoupper((string)$selfUser['email']);

            if ($normalizedTag === $selfTag || 
                strtoupper($cleanQuery) === $selfTag || 
                $cleanQuery === $selfId || 
                strtoupper($cleanQuery) === $selfName || 
                strtoupper($cleanQuery) === $selfEmail) {
                echo json_encode([
                    'success' => true,
                    'player'  => null,
                    'is_self' => true,
                    'message' => 'This is your own Player ID. You cannot add yourself as a friend.',
                ]);
                exit;
            }
        }
    }

    // 2. Query target user safely across all identifier fields
    $likeQuery = '%' . $cleanQuery . '%';
    $likeTag = '%' . $normalizedTag . '%';

    $sql = "
        SELECT
            u.id,
            u.player_id,
            u.name AS username,
            COALESCE(up.name, u.name) AS display_name,
            COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_url,
            COALESCE(up.level, 1) AS level,
            COALESCE(up.current_xp, 0) AS xp,
            COALESCE(up.coins, 100) AS coins,
            (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count,
            (SELECT COUNT(*) FROM user_badges WHERE user_id = u.id) AS badges_count,
            CASE
                WHEN UPPER(u.player_id) = UPPER(:norm_tag1) THEN 1
                WHEN UPPER(u.player_id) = UPPER(:raw_query1) THEN 2
                WHEN u.id = :raw_id1 THEN 3
                WHEN UPPER(u.email) = UPPER(:raw_email1) THEN 4
                WHEN UPPER(u.name) = UPPER(:raw_name1) THEN 5
                WHEN UPPER(up.name) = UPPER(:raw_pname1) THEN 6
                WHEN u.player_id LIKE :like_tag1 THEN 7
                WHEN u.name LIKE :like_name1 THEN 8
                WHEN up.name LIKE :like_pname1 THEN 9
                WHEN u.email LIKE :like_email1 THEN 10
                ELSE 11
            END AS match_score
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE (
            UPPER(u.player_id) = UPPER(:norm_tag2)
            OR UPPER(u.player_id) = UPPER(:raw_query2)
            OR u.id = :raw_id2
            OR UPPER(u.email) = UPPER(:raw_email2)
            OR UPPER(u.name) = UPPER(:raw_name2)
            OR UPPER(up.name) = UPPER(:raw_pname2)
            OR u.player_id LIKE :like_tag2
            OR u.name LIKE :like_name2
            OR up.name LIKE :like_pname2
            OR u.email LIKE :like_email2
        )
        ORDER BY match_score ASC, u.created_at DESC
        LIMIT 1
    ";

    $stmt = $db->prepare($sql);
    $stmt->execute([
        'norm_tag1'    => $normalizedTag,
        'raw_query1'   => $cleanQuery,
        'raw_id1'      => $cleanQuery,
        'raw_email1'   => $cleanQuery,
        'raw_name1'    => $cleanQuery,
        'raw_pname1'   => $cleanQuery,
        'like_tag1'    => $likeTag,
        'like_name1'   => $likeQuery,
        'like_pname1'  => $likeQuery,
        'like_email1'  => $likeQuery,

        'norm_tag2'    => $normalizedTag,
        'raw_query2'   => $cleanQuery,
        'raw_id2'      => $cleanQuery,
        'raw_email2'   => $cleanQuery,
        'raw_name2'    => $cleanQuery,
        'raw_pname2'   => $cleanQuery,
        'like_tag2'    => $likeTag,
        'like_name2'   => $likeQuery,
        'like_pname2'  => $likeQuery,
        'like_email2'  => $likeQuery,
    ]);

    $player = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($player) {
        // Exclude self if ID or player tag matches
        if ($selfId !== null && ($player['id'] === $selfId || strtoupper((string)$player['player_id']) === $selfTag)) {
            echo json_encode([
                'success' => true,
                'player'  => null,
                'is_self' => true,
                'message' => 'This is your own Player ID. You cannot add yourself as a friend.',
            ]);
            exit;
        }

        // Check friendship status relative to searching user
        $friendshipStatus = 'none';
        if ($selfId !== null) {
            $frStmt = $db->prepare("
                SELECT sender_id, receiver_id, status 
                FROM friend_requests
                WHERE (sender_id = :u1 AND receiver_id = :t1) OR (sender_id = :t2 AND receiver_id = :u2)
                ORDER BY id DESC
                LIMIT 1
            ");
            $frStmt->execute([
                'u1' => $selfId,
                't1' => $player['id'],
                't2' => $player['id'],
                'u2' => $selfId,
            ]);
            $fr = $frStmt->fetch(PDO::FETCH_ASSOC);
            if ($fr) {
                if ($fr['status'] === 'accepted') {
                    $friendshipStatus = 'accepted';
                } elseif ($fr['status'] === 'pending') {
                    $friendshipStatus = ($fr['sender_id'] === $selfId) ? 'pending_sent' : 'pending_received';
                }
            }
        }

        $resolvedTag = !empty($player['player_id']) ? (string)$player['player_id'] : $normalizedTag;

        echo json_encode([
            'success' => true,
            'player'  => [
                'id'                     => (string)$player['id'],
                'user_id'                => (string)$player['id'],
                'player_id'              => $resolvedTag,
                'player_tag'             => $resolvedTag,
                'username'               => (string)$player['username'],
                'name'                   => (string)$player['display_name'],
                'display_name'           => (string)$player['display_name'],
                'avatar_url'             => (string)$player['avatar_url'],
                'avatar_key'             => (string)$player['avatar_url'],
                'level'                  => (int)$player['level'],
                'current_xp'             => (int)$player['xp'],
                'xp'                     => (int)$player['xp'],
                'coins'                  => (int)$player['coins'],
                'completed_quests_count' => (int)$player['completed_quests_count'],
                'badges_count'           => (int)$player['badges_count'],
                'friendship_status'      => $friendshipStatus,
                'is_friend'              => ($friendshipStatus === 'accepted'),
            ],
            'message' => 'Player found!',
        ]);
    } else {
        echo json_encode([
            'success' => true,
            'player'  => null,
            'message' => "No player found matching '{$query}'.",
        ]);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'player'  => null,
        'message' => 'Database error during player search: ' . $e->getMessage(),
    ]);
}
