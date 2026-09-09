<?php
/**
 * QuestUP REST API - Share Quest with Squad Friend (Co-op Assist)
 * Endpoint: POST /api/quests/share.php
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

$questId = trim((string)($data['quest_id'] ?? ''));
$questTitle = trim((string)($data['quest_title'] ?? 'Quest Expedition'));
$senderId = trim((string)($data['sender_id'] ?? ''));
$senderTagInput = trim((string)($data['sender_tag'] ?? ''));
$senderNameInput = trim((string)($data['sender_name'] ?? ''));
$receiverIdOrTag = trim((string)($data['receiver_id'] ?? $data['target_tag'] ?? ''));
$questData = isset($data['quest_data']) ? json_encode($data['quest_data']) : null;

if ($questId === '' || $senderId === '' || $receiverIdOrTag === '') {
    echo json_encode([
        'success' => false,
        'message' => 'quest_id, sender_id, and receiver_id are required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Fetch sender info
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
        'email'   => $senderId,
    ]);
    $sender = $sStmt->fetch(PDO::FETCH_ASSOC);

    if (!$sender) {
        $sender = [
            'id'        => $senderId,
            'name'      => $senderNameInput !== '' ? $senderNameInput : 'Explorer',
            'player_id' => $senderTagInput !== '' ? $senderTagInput : 'QST-0000',
        ];
    }

    $senderTag = $sender['player_id'] ?? $senderTagInput ?: 'QST-0000';
    $senderName = $sender['name'] ?? $senderNameInput ?: 'Explorer';
    $realSenderId = $sender['id'];

    // 2. Fetch receiver info
    $cleanReceiverTag = strtoupper($receiverIdOrTag);
    if (preg_match('/^(?:QST[\s\-_]*)?(\d+)$/i', $receiverIdOrTag, $m)) {
        $cleanReceiverTag = 'QST-' . $m[1];
    }

    $rStmt = $db->prepare("
        SELECT id, player_id, name, email
        FROM users
        WHERE id = :rid 
           OR UPPER(player_id) = UPPER(:rtag) 
           OR UPPER(name) = UPPER(:rname)
        LIMIT 1
    ");
    $rStmt->execute([
        'rid'   => $receiverIdOrTag,
        'rtag'  => $cleanReceiverTag,
        'rname' => $receiverIdOrTag,
    ]);
    $receiver = $rStmt->fetch(PDO::FETCH_ASSOC);

    if (!$receiver) {
        echo json_encode([
            'success' => false,
            'message' => "Player '{$receiverIdOrTag}' not found in database.",
        ]);
        exit;
    }

    $realReceiverId = $receiver['id'];
    $receiverName = $receiver['name'];
    $receiverTag = $receiver['player_id'] ?? $cleanReceiverTag;

    // 3. Prevent self-sharing
    if ($realSenderId === $realReceiverId || strtoupper((string)$senderTag) === strtoupper((string)$receiverTag)) {
        echo json_encode([
            'success' => false,
            'message' => 'You cannot share a quest with yourself.',
        ]);
        exit;
    }

    // 4. Check if already shared for this quest
    $chkStmt = $db->prepare("
        SELECT id, status FROM shared_quests
        WHERE quest_id = :qid 
          AND sender_id = :sid 
          AND receiver_id = :rid
        LIMIT 1
    ");
    $chkStmt->execute([
        'qid' => $questId,
        'sid' => $realSenderId,
        'rid' => $realReceiverId,
    ]);
    $existing = $chkStmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        $sharedId = $existing['id'];
        // Update status to pending if previously completed or assisting
        $upd = $db->prepare("UPDATE shared_quests SET status = 'pending', updated_at = NOW() WHERE id = :id");
        $upd->execute(['id' => $sharedId]);
    } else {
        $sharedId = sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );

        $insStmt = $db->prepare("
            INSERT INTO shared_quests (id, quest_id, quest_title, quest_data, sender_id, sender_name, sender_tag, receiver_id, status, created_at, updated_at)
            VALUES (:id, :qid, :qtitle, :qdata, :sid, :sname, :stag, :rid, 'pending', NOW(), NOW())
        ");
        $insStmt->execute([
            'id'     => $sharedId,
            'qid'    => $questId,
            'qtitle' => $questTitle,
            'qdata'  => $questData,
            'sid'    => $realSenderId,
            'sname'  => $senderName,
            'stag'   => $senderTag,
            'rid'    => $realReceiverId,
        ]);
    }

    // 5. Send notification to the receiver
    $notifId = sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );

    $notifStmt = $db->prepare("
        INSERT INTO notifications (id, user_id, title, message, type, is_read, route_target, action_label, created_at)
        VALUES (:id, :uid, :title, :msg, 'quest', 0, :route, :action, NOW())
    ");
    $notifStmt->execute([
        'id'     => $notifId,
        'uid'    => $realReceiverId,
        'title'  => "Squad Assist: {$senderName} shared a quest!",
        'msg'    => "{$senderName} ({$senderTag}) requested your squad assist on '{$questTitle}'. Team up and complete it together!",
        'route'  => "/quest/{$questId}",
        'action' => "Help {$senderName}",
    ]);

    echo json_encode([
        'success'   => true,
        'message'   => "Quest shared with {$receiverName} ({$receiverTag})! They have been notified to assist you. 🚀",
        'shared_id' => $sharedId,
        'receiver'  => [
            'id'         => $realReceiverId,
            'name'       => $receiverName,
            'player_tag' => $receiverTag,
        ],
    ]);
} catch (PDOException $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error while sharing quest: ' . $e->getMessage(),
    ]);
}
