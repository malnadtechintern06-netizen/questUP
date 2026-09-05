<?php
/**
 * QuestUP REST API - Player Search by Player ID / Tag or Name
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

$query = trim($_GET['query'] ?? $_GET['tag'] ?? $_POST['query'] ?? $_POST['tag'] ?? '');
$currentUserId = trim($_GET['current_user_id'] ?? $_POST['current_user_id'] ?? '');

if ($query === '') {
    echo json_encode([
        'success' => false,
        'player' => null,
        'message' => 'Please enter a valid Player ID or Explorer Name.',
    ]);
    exit;
}

// Normalize player tag:
// Handles: "QST-1108", "qst-1108", "qst 1108", "1108", "QST1108" -> "QST-1108"
$normalizedTag = strtoupper($query);
$cleanNum = preg_replace('/[^0-9]/', '', $query);

if (preg_match('/^(?:QST[\s\-_]*)?(\d+)$/i', $query, $matches)) {
    $normalizedTag = 'QST-' . $matches[1];
}

$db = db();

try {
    // 1. Check if user is searching for their own ID
    if ($currentUserId !== '') {
        $selfStmt = $db->prepare("SELECT id, player_id, name, email FROM users WHERE id = :uid LIMIT 1");
        $selfStmt->execute(['uid' => $currentUserId]);
        $selfUser = $selfStmt->fetch(PDO::FETCH_ASSOC);

        if ($selfUser) {
            $myTag = strtoupper((string)($selfUser['player_id'] ?? ''));
            $myName = strtoupper((string)$selfUser['name']);
            $myEmail = strtoupper((string)$selfUser['email']);

            if ($normalizedTag === $myTag || strtoupper($query) === $myName || strtoupper($query) === $myEmail) {
                echo json_encode([
                    'success' => true,
                    'player' => null,
                    'is_self' => true,
                    'message' => 'This is your own Player ID. You cannot add yourself as a friend.',
                ]);
                exit;
            }
        }
    }

    // 2. Query target user safely without exposing password/sensitive data
    $sql = "
        SELECT
            u.id,
            u.player_id,
            u.name AS username,
            COALESCE(up.name, u.name) AS display_name,
            COALESCE(up.avatar_key, 'adventurer_default') AS avatar_url,
            COALESCE(up.level, 1) AS level,
            COALESCE(up.current_xp, 0) AS xp,
            COALESCE(up.coins, 100) AS coins,
            (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id) AS completed_quests_count,
            (SELECT COUNT(*) FROM user_badges WHERE user_id = u.id) AS badges_count
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE (UPPER(u.player_id) = UPPER(:normalized_tag) OR UPPER(u.name) = UPPER(:raw_name) OR UPPER(u.email) = UPPER(:raw_email))
        LIMIT 1
    ";

    $stmt = $db->prepare($sql);
    $stmt->execute([
        'normalized_tag' => $normalizedTag,
        'raw_name'       => $query,
        'raw_email'      => $query,
    ]);

    $player = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($player) {
        // Exclude self if matches
        if ($currentUserId !== '' && $player['id'] === $currentUserId) {
            echo json_encode([
                'success' => true,
                'player' => null,
                'is_self' => true,
                'message' => 'This is your own Player ID. You cannot add yourself as a friend.',
            ]);
            exit;
        }

        // Format clean response
        echo json_encode([
            'success' => true,
            'player' => [
                'id'                     => (string)$player['id'],
                'player_id'              => (string)($player['player_id'] ?? $normalizedTag),
                'username'               => (string)$player['username'],
                'display_name'           => (string)$player['display_name'],
                'avatar_url'             => (string)$player['avatar_url'],
                'level'                  => (int)$player['level'],
                'xp'                     => (int)$player['xp'],
                'coins'                  => (int)$player['coins'],
                'completed_quests_count' => (int)$player['completed_quests_count'],
                'badges_count'           => (int)$player['badges_count'],
            ],
            'message' => 'Player found!',
        ]);
    } else {
        echo json_encode([
            'success' => true,
            'player'  => null,
            'message' => "No player found matching {$query}",
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
