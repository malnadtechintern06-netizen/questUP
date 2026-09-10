<?php
/**
 * QuestUP REST API - User Login Authentication
 * Endpoint: POST /api/auth/login.php or /backend/api/auth/login.php
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
$data = json_decode($rawBody, true) ?? $_POST;

$email = trim(strtolower($data['email'] ?? ''));
$password = (string)($data['password'] ?? '');
$providedHash = trim($data['password_hash'] ?? '');

if (empty($email)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Email address is required.',
    ]);
    exit;
}

$db = db();

try {
    // 1. Fetch user by email
    $stmt = $db->prepare("SELECT id, player_id, name, email, password_hash, salt, status, created_at FROM users WHERE email = :email LIMIT 1");
    $stmt->execute(['email' => $email]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'No account found with this email. Please register first.',
        ]);
        exit;
    }

    if (($user['status'] ?? 'active') === 'banned') {
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Account is banned or suspended.',
        ]);
        exit;
    }

    // 2. Validate password
    $storedHash = (string)($user['password_hash'] ?? '');
    $salt = (string)($user['salt'] ?? '');
    $isValid = false;

    if (!empty($providedHash) && hash_equals($storedHash, $providedHash)) {
        $isValid = true;
    } elseif (!empty($password)) {
        $computed = hash('sha256', "{$password}::{$salt}::questup_secret");
        if (hash_equals($storedHash, $computed)) {
            $isValid = true;
        } elseif (hash_equals($storedHash, hash('sha256', $password . $salt))) {
            $isValid = true;
        } elseif (password_verify($password, $storedHash)) {
            $isValid = true;
        } elseif ($storedHash === hash('sha256', $password)) {
            $isValid = true;
        }
    }

    if (!$isValid) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Invalid email or password. Please try again.',
        ]);
        exit;
    }

    // 3. Fetch profile details
    $profStmt = $db->prepare("SELECT avatar_key, level, current_xp, xp_to_next_level, coins, joined_at FROM user_profiles WHERE user_id = :uid LIMIT 1");
    $profStmt->execute(['uid' => $user['id']]);
    $profile = $profStmt->fetch() ?: [];

    // 4. Log activity
    logActivity(
        $user['id'],
        'user_logged_in',
        "User logged in: {$user['name']} ({$user['player_id']})",
        $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
    );

    echo json_encode([
        'success' => true,
        'message' => 'Login successful.',
        'user' => [
            'id' => $user['id'],
            'player_id' => $user['player_id'] ?? 'QST-0000',
            'name' => $user['name'],
            'email' => $user['email'],
            'password_hash' => $storedHash,
            'salt' => $salt,
            'created_at' => $user['created_at'],
            'avatar_key' => $profile['avatar_key'] ?? 'avatar_1',
            'level' => (int)($profile['level'] ?? 1),
            'current_xp' => (int)($profile['current_xp'] ?? 0),
            'xp_to_next_level' => (int)($profile['xp_to_next_level'] ?? 500),
            'coins' => (int)($profile['coins'] ?? 100),
        ],
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error during login: ' . $e->getMessage(),
    ]);
}
