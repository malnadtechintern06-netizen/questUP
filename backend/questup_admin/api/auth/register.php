<?php
/**
 * QuestUP REST API - Register / Sync User Account
 * Endpoint: POST /api/auth/register.php or /backend/api/auth/register.php
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

// 1. Parse JSON input or Form POST
$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$id = trim($data['id'] ?? '');
$name = trim($data['name'] ?? '');
$email = trim(strtolower($data['email'] ?? ''));
$password = (string)($data['password'] ?? '');
$passwordHash = trim($data['password_hash'] ?? '');
$salt = trim($data['salt'] ?? '');
$playerId = trim($data['player_id'] ?? '');
$avatarKey = trim($data['avatar_key'] ?? 'avatar_1');
$level = max(1, (int)($data['level'] ?? 1));
$currentXp = max(0, (int)($data['current_xp'] ?? 0));
$xpNext = max(100, (int)($data['xp_to_next_level'] ?? 500));
$coins = max(0, (int)($data['coins'] ?? 100));

if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'A valid email address is required.',
    ]);
    exit;
}

if (empty($name)) {
    $parts = explode('@', $email);
    $name = ucfirst($parts[0]);
}

if (empty($id)) {
    $id = 'usr_' . bin2hex(random_bytes(16));
}

if (empty($salt)) {
    $salt = bin2hex(random_bytes(8));
}

if (empty($passwordHash)) {
    if (!empty($password)) {
        $passwordHash = hash('sha256', $password . '::' . $salt . '::questup_secret');
    } else {
        $passwordHash = hash('sha256', 'default_secret::' . $salt . '::questup_secret');
    }
}

$db = db();

// Helper to generate a unique permanent 4-digit Player ID (QST-XXXX)
function generateUniquePlayerId(PDO $db, string $seed): string {
    $hash = hash('sha256', $seed);
    $num = (hexdec(substr($hash, 0, 4)) % 9000) + 1000;
    $tag = 'QST-' . $num;

    $stmt = $db->prepare("SELECT 1 FROM users WHERE player_id = :pid LIMIT 1");
    $stmt->execute(['pid' => $tag]);
    if (!$stmt->fetch()) {
        return $tag;
    }

    for ($i = 0; $i < 50; $i++) {
        $rndTag = 'QST-' . mt_rand(1000, 9999);
        $stmt->execute(['pid' => $rndTag]);
        if (!$stmt->fetch()) {
            return $rndTag;
        }
    }

    for ($n = 1000; $n <= 9999; $n++) {
        $seqTag = 'QST-' . $n;
        $stmt->execute(['pid' => $seqTag]);
        if (!$stmt->fetch()) {
            return $seqTag;
        }
    }

    return 'QST-' . mt_rand(1000, 9999);
}

if (empty($playerId) || !preg_match('/^QST-\d{4}$/', $playerId)) {
    $playerId = generateUniquePlayerId($db, $email);
}

try {
    // 2. Check if player_id column exists
    $hasPlayerId = false;
    try {
        $colCheck = $db->query("SHOW COLUMNS FROM users LIKE 'player_id'");
        $hasPlayerId = ($colCheck && $colCheck->rowCount() > 0);
    } catch (Throwable $e) {
        $hasPlayerId = false;
    }

    // 3. Check if user already exists
    $stmt = $db->prepare("SELECT id, name, email, created_at FROM users WHERE email = :email LIMIT 1");
    $stmt->execute(['email' => $email]);
    $existingUser = $stmt->fetch();

    if ($existingUser) {
        $existingId = $existingUser['id'];
        // Update user record
        if ($hasPlayerId) {
            $upd = $db->prepare("
                UPDATE users 
                SET name = :name, password_hash = :hash, salt = :salt, status = 'active', player_id = COALESCE(player_id, :pid)
                WHERE id = :id
            ");
            $upd->execute([
                'name' => $name,
                'hash' => $passwordHash,
                'salt' => $salt,
                'pid' => $playerId,
                'id' => $existingId,
            ]);
        } else {
            $upd = $db->prepare("
                UPDATE users 
                SET name = :name, password_hash = :hash, salt = :salt, status = 'active'
                WHERE id = :id
            ");
            $upd->execute([
                'name' => $name,
                'hash' => $passwordHash,
                'salt' => $salt,
                'id' => $existingId,
            ]);
        }

        // Update profile
        $updProfile = $db->prepare("
            INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, xp_to_next_level, coins, joined_at)
            VALUES (:uid, :name, :email, :avatar, :level, :xp, :xp_next, :coins, NOW())
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                email = VALUES(email),
                avatar_key = COALESCE(avatar_key, VALUES(avatar_key))
        ");
        $updProfile->execute([
            'uid' => $existingId,
            'name' => $name,
            'email' => $email,
            'avatar' => $avatarKey,
            'level' => $level,
            'xp' => $currentXp,
            'xp_next' => $xpNext,
            'coins' => $coins,
        ]);

        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'User account verified and synchronized with MySQL.',
            'user' => [
                'id' => $existingId,
                'name' => $name,
                'email' => $email,
                'player_id' => $playerId,
                'created_at' => $existingUser['created_at'],
            ],
        ]);
        exit;
    }

    // 4. Insert new User into `users` table
    if ($hasPlayerId) {
        $insUser = $db->prepare("
            INSERT INTO users (id, player_id, name, email, password_hash, salt, status, created_at)
            VALUES (:id, :player_id, :name, :email, :password_hash, :salt, 'active', NOW())
        ");
        $insUser->execute([
            'id' => $id,
            'player_id' => $playerId,
            'name' => $name,
            'email' => $email,
            'password_hash' => $passwordHash,
            'salt' => $salt,
        ]);
    } else {
        $insUser = $db->prepare("
            INSERT INTO users (id, name, email, password_hash, salt, status, created_at)
            VALUES (:id, :name, :email, :password_hash, :salt, 'active', NOW())
        ");
        $insUser->execute([
            'id' => $id,
            'name' => $name,
            'email' => $email,
            'password_hash' => $passwordHash,
            'salt' => $salt,
        ]);
    }

    // 5. Insert new Profile into `user_profiles` table
    $insProfile = $db->prepare("
        INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, xp_to_next_level, coins, joined_at)
        VALUES (:user_id, :name, :email, :avatar_key, :level, :current_xp, :xp_to_next_level, :coins, NOW())
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            email = VALUES(email)
    ");
    $insProfile->execute([
        'user_id' => $id,
        'name' => $name,
        'email' => $email,
        'avatar_key' => $avatarKey,
        'level' => $level,
        'current_xp' => $currentXp,
        'xp_to_next_level' => $xpNext,
        'coins' => $coins,
    ]);

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'User account created and registered in MySQL successfully.',
        'user' => [
            'id' => $id,
            'name' => $name,
            'email' => $email,
            'player_id' => $playerId,
            'level' => $level,
            'coins' => $coins,
            'created_at' => date('Y-m-d H:i:s'),
        ],
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database registration error: ' . $e->getMessage(),
    ]);
}
