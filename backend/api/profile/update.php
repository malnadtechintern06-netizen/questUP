<?php
/**
 * QuestUP REST API - Update User Profile
 * Endpoint: POST /api/profile/update.php or /backend/api/profile/update.php
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
$data = json_decode($rawBody, true) ?? $_POST;

$userId = trim($data['user_id'] ?? ($data['id'] ?? ''));
if (empty($userId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required.',
    ]);
    exit;
}

$db = db();

try {
    // Check if profile exists
    $stmt = $db->prepare("SELECT * FROM user_profiles WHERE user_id = :uid LIMIT 1");
    $stmt->execute(['uid' => $userId]);
    $current = $stmt->fetch();

    $name = isset($data['name']) ? trim($data['name']) : ($current['name'] ?? 'Explorer');
    $email = isset($data['email']) ? trim(strtolower($data['email'])) : ($current['email'] ?? '');
    $avatarKey = isset($data['avatar_key']) ? trim($data['avatar_key']) : ($current['avatar_key'] ?? 'avatar_ranger');
    $level = isset($data['level']) ? max(1, (int)$data['level']) : (int)($current['level'] ?? 1);
    $currentXp = isset($data['current_xp']) ? max(0, (int)$data['current_xp']) : (int)($current['current_xp'] ?? 0);
    $xpToNextLevel = isset($data['xp_to_next_level']) ? max(100, (int)$data['xp_to_next_level']) : (int)($current['xp_to_next_level'] ?? 500);
    $coins = isset($data['coins']) ? max(0, (int)$data['coins']) : (int)($current['coins'] ?? 100);

    // Ensure parent user exists in `users` table
    $uCheck = $db->prepare("SELECT id FROM users WHERE id = :uid LIMIT 1");
    $uCheck->execute(['uid' => $userId]);
    if (!$uCheck->fetch()) {
        $hasPlayerId = false;
        try {
            $colCheck = $db->query("SHOW COLUMNS FROM users LIKE 'player_id'");
            $hasPlayerId = ($colCheck && $colCheck->rowCount() > 0);
        } catch (Throwable $_) {}

        $salt = bin2hex(random_bytes(8));
        $hash = hash('sha256', 'user::' . $userId . '::' . $salt);
        $cleanEmail = !empty($email) ? $email : ($userId . '@questup.local');

        if ($hasPlayerId) {
            $num = (hexdec(substr(hash('sha256', $userId), 0, 4)) % 9000) + 1000;
            $pid = 'QST-' . $num;
            $insU = $db->prepare("
                INSERT INTO users (id, player_id, name, email, password_hash, salt, status, created_at)
                VALUES (:uid, :pid, :name, :email, :hash, :salt, 'active', NOW())
                ON DUPLICATE KEY UPDATE name = VALUES(name)
            ");
            $insU->execute([
                'uid' => $userId,
                'pid' => $pid,
                'name' => $name,
                'email' => $cleanEmail,
                'hash' => $hash,
                'salt' => $salt,
            ]);
        } else {
            $insU = $db->prepare("
                INSERT INTO users (id, name, email, password_hash, salt, status, created_at)
                VALUES (:uid, :name, :email, :hash, :salt, 'active', NOW())
                ON DUPLICATE KEY UPDATE name = VALUES(name)
            ");
            $insU->execute([
                'uid' => $userId,
                'name' => $name,
                'email' => $cleanEmail,
                'hash' => $hash,
                'salt' => $salt,
            ]);
        }
    }

    $upsert = $db->prepare("
        INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, xp_to_next_level, coins, joined_at)
        VALUES (:uid, :name, :email, :avatar, :lvl, :xp, :xpnext, :coins, NOW())
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            email = IF(VALUES(email) != '', VALUES(email), email),
            avatar_key = VALUES(avatar_key),
            level = VALUES(level),
            current_xp = VALUES(current_xp),
            xp_to_next_level = VALUES(xp_to_next_level),
            coins = VALUES(coins)
    ");
    $upsert->execute([
        'uid' => $userId,
        'name' => $name,
        'email' => $email,
        'avatar' => $avatarKey,
        'lvl' => $level,
        'xp' => $currentXp,
        'xpnext' => $xpToNextLevel,
        'coins' => $coins,
    ]);

    // Also update users table name if provided
    if (!empty($name)) {
        try {
            $db->prepare("UPDATE users SET name = :name WHERE id = :uid")->execute(['name' => $name, 'uid' => $userId]);
        } catch (Throwable $_) {}
    }

    // If badge_id is provided, record it in user_badges
    if (!empty($data['badge_id'])) {
        $badgeId = trim((string)$data['badge_id']);
        try {
            $badgeStmt = $db->prepare("
                INSERT INTO user_badges (id, user_id, badge_id, earned_at)
                VALUES (UUID(), :uid, :bid, NOW())
                ON DUPLICATE KEY UPDATE earned_at = NOW()
            ");
            $badgeStmt->execute(['uid' => $userId, 'bid' => $badgeId]);
        } catch (Throwable $_) {}
    }

    echo json_encode([
        'success' => true,
        'message' => 'Profile synchronized successfully in MySQL.',
        'profile' => [
            'user_id' => $userId,
            'name' => $name,
            'email' => $email,
            'avatar_key' => $avatarKey,
            'level' => $level,
            'current_xp' => $currentXp,
            'xp_to_next_level' => $xpToNextLevel,
            'coins' => $coins,
        ],
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
    ]);
}
