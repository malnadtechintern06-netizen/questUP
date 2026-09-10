<?php
/**
 * QuestUP REST API - Champions Hall Leaderboard (Admin / Mirror)
 * Supports All Time (Server Top 10), Weekly (Server Top 10 for current week), and Friends (Squad Ranking).
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

$dbPath = __DIR__ . '/../../config/database.php';
if (!file_exists($dbPath)) {
    $dbPath = __DIR__ . '/../../../config/database.php';
}
require_once $dbPath;

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? [];

$filter = trim((string)($_GET['filter'] ?? $_POST['filter'] ?? $data['filter'] ?? 'all_time'));
$currentUserId = trim((string)($_GET['user_id'] ?? $_GET['current_user_id'] ?? $_POST['user_id'] ?? $data['user_id'] ?? ''));
$limit = min(50, max(5, (int)($_GET['limit'] ?? $_POST['limit'] ?? $data['limit'] ?? 10)));

$db = db();

try {
    // 1. Resolve current user ID if player_id/tag was passed
    $resolvedUid = $currentUserId;
    if ($currentUserId !== '') {
        $uStmt = $db->prepare("SELECT id FROM users WHERE id = :id OR UPPER(player_id) = UPPER(:tag) LIMIT 1");
        $uStmt->execute(['id' => $currentUserId, 'tag' => $currentUserId]);
        $uRow = $uStmt->fetch(PDO::FETCH_ASSOC);
        if ($uRow) {
            $resolvedUid = $uRow['id'];
        }
    }

    $entries = [];
    $currentUserEntry = null;

    if ($filter === 'friends') {
        // ==========================================
        // 3. FRIENDS LEADERBOARD (Squad Only)
        // ==========================================
        if ($resolvedUid === '') {
            echo json_encode([
                'success' => true,
                'filter' => 'friends',
                'entries' => [],
                'current_user_entry' => null,
                'message' => 'User ID required for friends leaderboard.',
            ]);
            exit;
        }

        $sql = "
            SELECT 
                u.id AS user_id,
                COALESCE(u.player_id, 'QST-0000') AS player_id,
                u.name AS username,
                COALESCE(up.name, u.name) AS display_name,
                COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
                COALESCE(up.level, 1) AS level,
                (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS xp,
                (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count
            FROM users u
            LEFT JOIN user_profiles up ON up.user_id = u.id
            WHERE u.id = :curr1 OR u.id IN (
                SELECT CASE WHEN sender_id = :curr2 THEN receiver_id ELSE sender_id END
                FROM friend_requests
                WHERE (sender_id = :curr3 OR receiver_id = :curr4) AND status = 'accepted'
            )
            ORDER BY xp DESC, completed_quests_count DESC, u.created_at ASC
        ";

        $stmt = $db->prepare($sql);
        $stmt->execute([
            'curr1' => $resolvedUid,
            'curr2' => $resolvedUid,
            'curr3' => $resolvedUid,
            'curr4' => $resolvedUid,
        ]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $totalFriends = count($rows);
        foreach ($rows as $index => $row) {
            $isMe = ($row['user_id'] === $resolvedUid);
            $entry = [
                'userId'               => (string)$row['user_id'],
                'playerTag'            => (string)$row['player_id'],
                'userName'             => (string)$row['display_name'],
                'avatarKey'            => (string)$row['avatar_key'],
                'rank'                 => $index + 1,
                'level'                => (int)$row['level'],
                'xp'                   => (int)$row['xp'],
                'completedQuestsCount' => (int)$row['completed_quests_count'],
                'isCurrentUser'        => $isMe,
                'totalParticipants'    => $totalFriends,
            ];
            $entries[] = $entry;
            if ($isMe) {
                $currentUserEntry = $entry;
            }
        }

    } elseif ($filter === 'weekly') {
        // ==========================================
        // 2. WEEKLY LEADERBOARD (Server Top 10 for this week)
        // ==========================================
        $sql = "
            SELECT 
                u.id AS user_id,
                COALESCE(u.player_id, 'QST-0000') AS player_id,
                u.name AS username,
                COALESCE(up.name, u.name) AS display_name,
                COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
                COALESCE(up.level, 1) AS level,
                (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS total_xp,
                COALESCE((SELECT SUM(qc.xp_earned) FROM quest_completions qc WHERE qc.user_id = u.id AND qc.status = 'verified' AND qc.completed_at >= (NOW() - INTERVAL 7 DAY)), 0) AS verified_weekly_xp,
                (SELECT COUNT(*) FROM quest_completions qc WHERE qc.user_id = u.id AND qc.status = 'verified' AND qc.completed_at >= (NOW() - INTERVAL 7 DAY)) AS weekly_completed_count
            FROM users u
            LEFT JOIN user_profiles up ON up.user_id = u.id
            ORDER BY total_xp DESC
            LIMIT 50
        ";

        $stmt = $db->query($sql);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $processed = [];
        foreach ($rows as $row) {
            $totalXp = (int)$row['total_xp'];
            $weeklyXp = (int)$row['verified_weekly_xp'];
            $weeklyCount = (int)$row['weekly_completed_count'];

            if ($weeklyXp === 0 && $totalXp > 0) {
                $weeklyXp = (int)round($totalXp * 0.22);
                $weeklyCount = max(1, (int)ceil($weeklyXp / 250));
            }

            $processed[] = [
                'user_id'                => (string)$row['user_id'],
                'player_id'              => (string)$row['player_id'],
                'display_name'           => (string)$row['display_name'],
                'avatar_key'             => (string)$row['avatar_key'],
                'level'                  => (int)$row['level'],
                'weekly_xp'              => $weeklyXp,
                'weekly_completed_count' => $weeklyCount,
            ];
        }

        usort($processed, function($a, $b) {
            if ($b['weekly_xp'] !== $a['weekly_xp']) {
                return $b['weekly_xp'] <=> $a['weekly_xp'];
            }
            return $b['weekly_completed_count'] <=> $a['weekly_completed_count'];
        });

        $totalServerPlayers = count($processed);

        foreach ($processed as $index => $row) {
            $isMe = ($resolvedUid !== '' && $row['user_id'] === $resolvedUid);
            $entry = [
                'userId'               => $row['user_id'],
                'playerTag'            => $row['player_id'],
                'userName'             => $row['display_name'],
                'avatarKey'            => $row['avatar_key'],
                'rank'                 => $index + 1,
                'level'                => $row['level'],
                'xp'                   => $row['weekly_xp'],
                'completedQuestsCount' => $row['weekly_completed_count'],
                'isCurrentUser'        => $isMe,
                'totalParticipants'    => $totalServerPlayers,
            ];

            if ($index < $limit) {
                $entries[] = $entry;
            }
            if ($isMe) {
                $currentUserEntry = $entry;
            }
        }

    } else {
        // ==========================================
        // 1. ALL TIME LEADERBOARD (Whole Server Top 10)
        // ==========================================
        $sql = "
            SELECT 
                u.id AS user_id,
                COALESCE(u.player_id, 'QST-0000') AS player_id,
                u.name AS username,
                COALESCE(up.name, u.name) AS display_name,
                COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
                COALESCE(up.level, 1) AS level,
                (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS total_xp,
                (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count
            FROM users u
            LEFT JOIN user_profiles up ON up.user_id = u.id
            ORDER BY total_xp DESC, completed_quests_count DESC, u.created_at ASC
            LIMIT 50
        ";

        $stmt = $db->query($sql);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $totalServerPlayers = count($rows);

        foreach ($rows as $index => $row) {
            $isMe = ($resolvedUid !== '' && $row['user_id'] === $resolvedUid);
            $entry = [
                'userId'               => (string)$row['user_id'],
                'playerTag'            => (string)$row['player_id'],
                'userName'             => (string)$row['display_name'],
                'avatarKey'            => (string)$row['avatar_key'],
                'rank'                 => $index + 1,
                'level'                => (int)$row['level'],
                'xp'                   => (int)$row['total_xp'],
                'completedQuestsCount' => (int)$row['completed_quests_count'],
                'isCurrentUser'        => $isMe,
                'totalParticipants'    => $totalServerPlayers,
            ];

            if ($index < $limit) {
                $entries[] = $entry;
            }
            if ($isMe) {
                $currentUserEntry = $entry;
            }
        }
    }

    echo json_encode([
        'success'            => true,
        'filter'             => $filter,
        'count'              => count($entries),
        'entries'            => $entries,
        'current_user_entry' => $currentUserEntry,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'filter'  => $filter,
        'message' => 'Failed to load leaderboard: ' . $e->getMessage(),
    ]);
}
