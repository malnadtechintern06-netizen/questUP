<?php
/**
 * QuestUP REST API - Submit Quest Completion
 * Endpoint: POST /api/quests/complete.php
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$questId = trim($data['quest_id'] ?? '');
$userId = trim($data['user_id'] ?? '');
$verificationType = trim($data['verification_type'] ?? 'locationGps');
$xpEarned = (int)($data['xp_earned'] ?? 100);
$coinsEarned = (int)($data['coins_earned'] ?? 50);
$proofData = isset($data['proof_data']) ? (is_string($data['proof_data']) ? $data['proof_data'] : json_encode($data['proof_data'])) : null;

if (empty($questId) || empty($userId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'quest_id and user_id are required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Check duplicate
    $chkStmt = $db->prepare("SELECT id FROM quest_completions WHERE quest_id = :qid AND user_id = :uid LIMIT 1");
    $chkStmt->execute(['qid' => $questId, 'uid' => $userId]);
    if ($chkStmt->fetch()) {
        echo json_encode([
            'success' => true,
            'message' => 'Quest already completed by user.',
            'is_duplicate' => true,
        ]);
        exit;
    }

    // 2. Insert completion
    $completionId = 'cmp_' . bin2hex(random_bytes(12));
    $insStmt = $db->prepare("
        INSERT INTO quest_completions (
            id, quest_id, user_id, verification_type, proof_data,
            xp_earned, coins_earned, completed_at, status
        ) VALUES (
            :id, :qid, :uid, :vtype, :proof,
            :xp, :coins, NOW(), 'verified'
        )
    ");
    $insStmt->execute([
        'id' => $completionId,
        'qid' => $questId,
        'uid' => $userId,
        'vtype' => $verificationType,
        'proof' => $proofData,
        'xp' => $xpEarned,
        'coins' => $coinsEarned,
    ]);

    // 3. Update user profile XP & Coins
    $updStmt = $db->prepare("
        UPDATE user_profiles 
        SET current_xp = current_xp + :xp,
            coins = coins + :coins,
            updated_at = NOW()
        WHERE user_id = :uid
    ");
    $updStmt->execute([
        'xp' => $xpEarned,
        'coins' => $coinsEarned,
        'uid' => $userId,
    ]);

    // 4. Check if this quest was part of an active squad co-op assist
    try {
        $sqStmt = $db->prepare("
            SELECT id, quest_title, sender_id, receiver_id, sender_name 
            FROM shared_quests
            WHERE quest_id = :qid AND (receiver_id = :uid1 OR sender_id = :uid2)
            LIMIT 1
        ");
        $sqStmt->execute(['qid' => $questId, 'uid1' => $userId, 'uid2' => $userId]);
        $sharedQuest = $sqStmt->fetch(PDO::FETCH_ASSOC);

        if ($sharedQuest) {
            $db->prepare("UPDATE shared_quests SET status = 'completed', updated_at = NOW() WHERE id = :id")
               ->execute(['id' => $sharedQuest['id']]);

            // Notify partner
            $partnerId = ($sharedQuest['receiver_id'] === $userId) ? $sharedQuest['sender_id'] : $sharedQuest['receiver_id'];
            
            // Get completer name
            $cNameStmt = $db->prepare("SELECT name FROM users WHERE id = :uid LIMIT 1");
            $cNameStmt->execute(['uid' => $userId]);
            $cUser = $cNameStmt->fetch(PDO::FETCH_ASSOC);
            $completerName = $cUser ? $cUser['name'] : 'Squad Explorer';

            $notifId = sprintf(
                '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000,
                mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );

            $db->prepare("
                INSERT INTO notifications (id, user_id, title, message, type, is_read, route_target, action_label, created_at)
                VALUES (:id, :uid, :title, :msg, 'quest', 0, :route, 'View Squad', NOW())
            ")->execute([
                'id'    => $notifId,
                'uid'   => $partnerId,
                'title' => '🎉 Squad Co-op Mission Accomplished!',
                'msg'   => "{$completerName} helped complete '{$sharedQuest['quest_title']}'! Squad assist rewards awarded!",
                'route' => "/quest/{$questId}",
            ]);
        }
    } catch (Throwable $e) {}

    echo json_encode([
        'success' => true,
        'message' => 'Quest completed successfully!',
        'completion_id' => $completionId,
        'xp_earned' => $xpEarned,
        'coins_earned' => $coinsEarned,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
    ]);
}
