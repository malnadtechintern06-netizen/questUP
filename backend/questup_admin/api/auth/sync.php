<?php
/**
 * QuestUP REST API - Batch Sync Local Users & Profiles to MySQL
 * Endpoint: POST /api/auth/sync.php or /backend/api/auth/sync.php
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

$users = $data['users'] ?? [];
if (!is_array($users) || empty($users)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'An array of users is required for synchronization.',
    ]);
    exit;
}

$db = db();
$syncedCount = 0;
$errors = [];

$hasPlayerId = false;
try {
    $colCheck = $db->query("SHOW COLUMNS FROM users LIKE 'player_id'");
    $hasPlayerId = ($colCheck && $colCheck->rowCount() > 0);
} catch (Throwable $e) {
    $hasPlayerId = false;
}

foreach ($users as $u) {
    if (!is_array($u)) continue;

    $email = trim(strtolower($u['email'] ?? ''));
    if (empty($email)) continue;

    $id = trim($u['id'] ?? '') ?: ('usr_' . bin2hex(random_bytes(16)));
    $name = trim($u['name'] ?? '') ?: ucfirst(explode('@', $email)[0]);
    $passwordHash = trim($u['password_hash'] ?? '') ?: hash('sha256', 'secret');
    $salt = trim($u['salt'] ?? '') ?: bin2hex(random_bytes(8));
    $playerId = trim($u['player_id'] ?? '') ?: ('QST-' . strtoupper(bin2hex(random_bytes(2))));
    $avatarKey = trim($u['avatar_key'] ?? 'avatar_1');
    $level = max(1, (int)($u['level'] ?? 1));
    $currentXp = max(0, (int)($u['current_xp'] ?? 0));
    $coins = max(0, (int)($u['coins'] ?? 100));

    try {
        if ($hasPlayerId) {
            $stmt = $db->prepare("
                INSERT INTO users (id, player_id, name, email, password_hash, salt, status, created_at)
                VALUES (:id, :pid, :name, :email, :hash, :salt, 'active', NOW())
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    player_id = COALESCE(users.player_id, VALUES(player_id)),
                    status = 'active'
            ");
            $stmt->execute([
                'id' => $id,
                'pid' => $playerId,
                'name' => $name,
                'email' => $email,
                'hash' => $passwordHash,
                'salt' => $salt,
            ]);
        } else {
            $stmt = $db->prepare("
                INSERT INTO users (id, name, email, password_hash, salt, status, created_at)
                VALUES (:id, :name, :email, :hash, :salt, 'active', NOW())
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    status = 'active'
            ");
            $stmt->execute([
                'id' => $id,
                'name' => $name,
                'email' => $email,
                'hash' => $passwordHash,
                'salt' => $salt,
            ]);
        }

        // Profile sync
        $profStmt = $db->prepare("
            INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, xp_to_next_level, coins, joined_at)
            VALUES (:uid, :name, :email, :avatar, :level, :xp, 500, :coins, NOW())
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                email = VALUES(email)
        ");
        $profStmt->execute([
            'uid' => $id,
            'name' => $name,
            'email' => $email,
            'avatar' => $avatarKey,
            'level' => $level,
            'xp' => $currentXp,
            'coins' => $coins,
        ]);

        $syncedCount++;
    } catch (Throwable $e) {
        $errors[] = $e->getMessage();
    }
}

http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => "Synchronized {$syncedCount} users into MySQL database successfully.",
    'synced_count' => $syncedCount,
    'errors' => $errors,
]);
