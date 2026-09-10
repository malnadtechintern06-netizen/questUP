<?php
/**
 * QuestUP REST API - Player History Privacy Endpoint
 * 
 * STRICT PRIVACY RULES:
 * 1. Requires authenticated logged-in player ID (user_id).
 * 2. If target is self: returns complete own quest history.
 * 3. If target is another player: checks whether a mutual friendship exists with status = 'accepted'.
 * 4. If friendship is NOT accepted (pending, rejected, cancelled, or none):
 *    returns HTTP 403 Forbidden with {"success": false, "error": "Players are not friends"}.
 * 5. NEVER trusts player_id alone as proof of permission.
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

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? [];

$userId = trim((string)($_GET['user_id'] ?? $_POST['user_id'] ?? $data['user_id'] ?? ''));
$targetPlayerId = trim((string)($_GET['target_player_id'] ?? $_GET['player_id'] ?? $_POST['target_player_id'] ?? $_POST['player_id'] ?? $data['target_player_id'] ?? $data['player_id'] ?? ''));

// Normalize target tag if numeric or prefixed
$cleanTargetTag = strtoupper($targetPlayerId);
if (preg_match('/^(?:QST[\s\-_]*)?(\d+)$/i', $targetPlayerId, $m)) {
    $cleanTargetTag = 'QST-' . $m[1];
}

if ($userId === '' || $targetPlayerId === '') {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error'   => 'user_id and target_player_id are required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Verify requesting authenticated user exists
    $uStmt = $db->prepare("SELECT id, player_id, name FROM users WHERE id = :uid LIMIT 1");
    $uStmt->execute(['uid' => $userId]);
    $requester = $uStmt->fetch(PDO::FETCH_ASSOC);

    if (!$requester) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'error'   => 'Authenticated user session not found.',
        ]);
        exit;
    }

    // 2. Resolve target player by player_id, id, or name
    $tStmt = $db->prepare("
        SELECT id, player_id, name 
        FROM users 
        WHERE UPPER(player_id) = UPPER(:tag) OR id = :tid OR UPPER(player_id) = UPPER(:raw_tag)
        LIMIT 1
    ");
    $tStmt->execute([
        'tag'     => $cleanTargetTag,
        'tid'     => $targetPlayerId,
        'raw_tag' => $targetPlayerId,
    ]);
    $target = $tStmt->fetch(PDO::FETCH_ASSOC);

    if (!$target) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'error'   => "Player '{$targetPlayerId}' not found.",
        ]);
        exit;
    }

    $isSelf = ($requester['id'] === $target['id'] || strtoupper((string)$requester['player_id']) === strtoupper((string)$target['player_id']));

    // 3. If requester is target player: return own history
    if ($isSelf) {
        $qStmt = $db->prepare("
            SELECT 
                qc.id,
                qc.quest_id,
                qc.completed_at,
                qc.xp_earned,
                qc.coins_earned,
                qc.status,
                q.title,
                q.category,
                COALESCE(q.location_name, 'Unknown Location') AS location_name
            FROM quest_completions qc
            JOIN quests q ON qc.quest_id = q.id
            WHERE qc.user_id = :uid
            ORDER BY qc.completed_at DESC
        ");
        $qStmt->execute(['uid' => $target['id']]);
        $history = $qStmt->fetchAll(PDO::FETCH_ASSOC);

        $formattedHistory = array_map(function ($row) {
            return [
                'quest_id'      => (string)$row['quest_id'],
                'title'         => (string)$row['title'],
                'category'      => (string)$row['category'],
                'xp_earned'     => (int)$row['xp_earned'],
                'coins_earned'  => (int)$row['coins_earned'],
                'completed_at'  => (string)$row['completed_at'],
                'location_name' => (string)$row['location_name'],
            ];
        }, $history);

        echo json_encode([
            'success'        => true,
            'is_own_history' => true,
            'is_friend'      => true,
            'player_id'      => (string)$target['player_id'],
            'player_name'    => (string)$target['name'],
            'history'        => $formattedHistory,
        ]);
        exit;
    }

    // 4. Target is another player: Check friendship relationship
    $fStmt = $db->prepare("
        SELECT id, status 
        FROM friend_requests
        WHERE ((sender_id = :u1 AND receiver_id = :t1) OR (sender_id = :t2 AND receiver_id = :u2))
          AND status = 'accepted'
        LIMIT 1
    ");
    $fStmt->execute([
        'u1' => $requester['id'],
        't1' => $target['id'],
        't2' => $target['id'],
        'u2' => $requester['id'],
    ]);
    $friendship = $fStmt->fetch(PDO::FETCH_ASSOC);

    // If not accepted friends: STRICTLY BLOCK ACCESS
    if (!$friendship) {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'error'   => 'Players are not friends',
        ]);
        exit;
    }

    // 5. Mutual accepted friendship confirmed: return friend-visible quest history
    $qStmt = $db->prepare("
        SELECT 
            qc.id,
            qc.quest_id,
            qc.completed_at,
            qc.xp_earned,
            qc.coins_earned,
            q.title,
            q.category,
            COALESCE(q.location_name, 'Unknown Location') AS location_name
        FROM quest_completions qc
        JOIN quests q ON qc.quest_id = q.id
        WHERE qc.user_id = :target_id AND qc.status = 'verified'
        ORDER BY qc.completed_at DESC
    ");
    $qStmt->execute(['target_id' => $target['id']]);
    $history = $qStmt->fetchAll(PDO::FETCH_ASSOC);

    $formattedHistory = array_map(function ($row) {
        return [
            'quest_id'      => (string)$row['quest_id'],
            'title'         => (string)$row['title'],
            'category'      => (string)$row['category'],
            'xp_earned'     => (int)$row['xp_earned'],
            'coins_earned'  => (int)$row['coins_earned'],
            'completed_at'  => (string)$row['completed_at'],
            'location_name' => (string)$row['location_name'],
        ];
    }, $history);

    echo json_encode([
        'success'        => true,
        'is_own_history' => false,
        'is_friend'      => true,
        'player_id'      => (string)$target['player_id'],
        'player_name'    => (string)$target['name'],
        'history'        => $formattedHistory,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error'   => 'Database error loading player history: ' . $e->getMessage(),
    ]);
}
