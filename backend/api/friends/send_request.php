<?php
/**
 * QuestUP REST API - Send Friend Request
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
require_once __DIR__ . '/../../config/activity_logger.php';

$rawBody = file_get_contents('php://input');
if ($rawBody !== false) {
    if (substr($rawBody, 0, 3) === "\xEF\xBB\xBF") {
        $rawBody = substr($rawBody, 3);
    }
}
$data = (!empty($rawBody)) ? json_decode($rawBody, true) : null;
if (!is_array($data)) {
    $data = $_POST ?: $_GET ?: [];
}

$senderId = trim((string)($data['sender_id'] ?? $_GET['sender_id'] ?? ''));
$targetTagOrId = trim((string)($data['target_tag'] ?? $data['receiver_id'] ?? $data['target_id'] ?? $_GET['target_tag'] ?? ''));
$senderTagInput = trim((string)($data['sender_tag'] ?? ''));
$senderNameInput = trim((string)($data['sender_name'] ?? ''));
$senderEmailInput = trim((string)($data['sender_email'] ?? ''));

if ($senderId === '' || $targetTagOrId === '') {
    echo json_encode([
        'success' => false,
        'message' => 'Sender ID and Target Player Tag/ID are required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Fetch sender info (by ID, Player ID/Tag, or Email)
    $sStmt = $db->prepare("
        SELECT id, player_id, name, email
        FROM users
        WHERE id = :id 
           OR player_id = :pid 
           OR UPPER(player_id) = UPPER(:pid_tag)
           OR (email != '' AND email = :email)
        LIMIT 1
    ");
    $sStmt->execute([
        'id'      => $senderId,
        'pid'     => $senderId,
        'pid_tag' => $senderTagInput !== '' ? $senderTagInput : $senderId,
        'email'   => $senderEmailInput !== '' ? $senderEmailInput : $senderId,
    ]);
    $sender = $sStmt->fetch(PDO::FETCH_ASSOC);

    // If sender does not yet exist in MySQL (e.g. newly registered or local guest), auto-provision them
    if (!$sender) {
        $finalSenderTag = $senderTagInput !== '' ? $senderTagInput : ('QST-' . rand(1000, 9999));
        $finalSenderName = $senderNameInput !== '' ? $senderNameInput : 'Explorer';
        $finalSenderEmail = $senderEmailInput !== '' ? $senderEmailInput : ($senderId . '@questup.app');

        $insStmt = $db->prepare("
            INSERT INTO users (id, player_id, name, email, password_hash, status)
            VALUES (:id, :pid, :name, :email, :pw, 'active')
            ON DUPLICATE KEY UPDATE player_id = VALUES(player_id)
        ");
        $insStmt->execute([
            'id'    => $senderId,
            'pid'   => $finalSenderTag,
            'name'  => $finalSenderName,
            'email' => $finalSenderEmail,
            'pw'    => password_hash('questup_explorer', PASSWORD_BCRYPT),
        ]);

        $profStmt = $db->prepare("
            INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, coins)
            VALUES (:uid, :name, :email, 'adventurer_default', 1, 0, 100)
            ON DUPLICATE KEY UPDATE name = VALUES(name)
        ");
        $profStmt->execute([
            'uid'   => $senderId,
            'name'  => $finalSenderName,
            'email' => $finalSenderEmail,
        ]);

        $sStmt->execute([
            'id'      => $senderId,
            'pid'     => $finalSenderTag,
            'pid_tag' => $finalSenderTag,
            'email'   => $finalSenderEmail,
        ]);
        $sender = $sStmt->fetch(PDO::FETCH_ASSOC);
    }

    if (!$sender) {
        echo json_encode([
            'success' => false,
            'message' => 'Sender account could not be initialized.',
        ]);
        exit;
    }

    $senderId = $sender['id'];
    $senderTag = $sender['player_id'] ?? ('QST-' . substr(md5($sender['id']), 0, 4));

    // Normalize target tag: e.g. "2794", "qst-2794", "QST2794" -> "QST-2794"
    $cleanTargetTag = strtoupper($targetTagOrId);
    if (preg_match('/^(?:QST[\s\-_]*)?(\d+)$/i', $targetTagOrId, $m)) {
        $cleanTargetTag = 'QST-' . $m[1];
    }

    // 2. Fetch target user info (by normalized tag, user id, or exact name)
    $tStmt = $db->prepare("
        SELECT id, player_id, name, email
        FROM users
        WHERE UPPER(player_id) = UPPER(:tag) 
           OR id = :tid 
           OR UPPER(name) = UPPER(:tname)
           OR name LIKE :tlike
        LIMIT 1
    ");
    $tStmt->execute([
        'tag'   => $cleanTargetTag,
        'tid'   => $targetTagOrId,
        'tname' => $targetTagOrId,
        'tlike' => $targetTagOrId . '%',
    ]);
    $target = $tStmt->fetch(PDO::FETCH_ASSOC);

    if (!$target) {
        echo json_encode([
            'success' => false,
            'message' => "Player '{$targetTagOrId}' not found. Check Player ID (e.g. QST-1108).",
        ]);
        exit;
    }

    $receiverId = $target['id'];
    $receiverTag = $target['player_id'] ?? $cleanTargetTag;

    // 3. Prevent self-request
    if ($senderId === $receiverId || strtoupper((string)$senderTag) === strtoupper((string)$receiverTag)) {
        echo json_encode([
            'success' => false,
            'message' => 'You cannot send a friend request to yourself.',
        ]);
        exit;
    }

    // 4. Check if already mutual accepted friends
    $fStmt = $db->prepare("
        SELECT id FROM friend_requests
        WHERE ((sender_id = :s1 AND receiver_id = :r1) OR (sender_id = :r2 AND receiver_id = :s2))
          AND status = 'accepted'
        LIMIT 1
    ");
    $fStmt->execute(['s1' => $senderId, 'r1' => $receiverId, 'r2' => $receiverId, 's2' => $senderId]);
    if ($fStmt->fetch()) {
        echo json_encode([
            'success' => false,
            'message' => "{$target['name']} ({$receiverTag}) is already in your friends squad.",
        ]);
        exit;
    }

    // 5. Check if active pending request exists in either direction
    $reqStmt = $db->prepare("
        SELECT id, sender_id, receiver_id, status FROM friend_requests
        WHERE ((sender_id = :s3 AND receiver_id = :r3) OR (sender_id = :r4 AND receiver_id = :s4))
          AND status = 'pending'
        LIMIT 1
    ");
    $reqStmt->execute(['s3' => $senderId, 'r3' => $receiverId, 'r4' => $receiverId, 's4' => $senderId]);
    $existingPending = $reqStmt->fetch(PDO::FETCH_ASSOC);

    if ($existingPending) {
        if ($existingPending['sender_id'] === $senderId) {
            echo json_encode([
                'success' => false,
                'message' => "A friend request has already been sent to {$target['name']}.",
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => "{$target['name']} has already sent you a friend request. Check your incoming requests!",
            ]);
        }
        exit;
    }

    // 6. Check if a previous rejected/cancelled request exists to reuse row
    $oldReqStmt = $db->prepare("
        SELECT id FROM friend_requests
        WHERE (sender_id = :s5 AND receiver_id = :r5) OR (sender_id = :r6 AND receiver_id = :s6)
        LIMIT 1
    ");
    $oldReqStmt->execute(['s5' => $senderId, 'r5' => $receiverId, 'r6' => $receiverId, 's6' => $senderId]);
    $oldReq = $oldReqStmt->fetch(PDO::FETCH_ASSOC);

    if ($oldReq) {
        $requestId = $oldReq['id'];
        $updStmt = $db->prepare("
            UPDATE friend_requests 
            SET sender_id = :s_id, receiver_id = :r_id, sender_tag = :s_tag, receiver_tag = :r_tag,
                status = 'pending', updated_at = NOW()
            WHERE id = :id
        ");
        $updStmt->execute([
            'id'    => $requestId,
            's_id'  => $senderId,
            'r_id'  => $receiverId,
            's_tag' => $senderTag,
            'r_tag' => $receiverTag,
        ]);
    } else {
        $requestId = sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );

        $insStmt = $db->prepare("
            INSERT INTO friend_requests (id, sender_id, receiver_id, sender_tag, receiver_tag, status, created_at, updated_at)
            VALUES (:id, :s_id, :r_id, :s_tag, :r_tag, 'pending', NOW(), NOW())
        ");
        $insStmt->execute([
            'id'    => $requestId,
            's_id'  => $senderId,
            'r_id'  => $receiverId,
            's_tag' => $senderTag,
            'r_tag' => $receiverTag,
        ]);
    }

    logActivity(
        $senderId,
        'friend_request_sent',
        "Player {$senderTag} sent friend request to {$target['name']} ({$receiverTag})",
        $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
    );

    echo json_encode([
        'success' => true,
        'message' => "Friend request sent successfully to {$target['name']} ({$receiverTag})!",
        'request' => [
            'id'           => $requestId,
            'sender_id'    => $senderId,
            'receiver_id'  => $receiverId,
            'sender_tag'   => $senderTag,
            'receiver_tag' => $receiverTag,
            'status'       => 'pending',
        ],
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error sending friend request: ' . $e->getMessage() . ' on line ' . $e->getLine(),
    ]);
}
