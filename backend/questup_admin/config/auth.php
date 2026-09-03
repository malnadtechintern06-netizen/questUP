<?php
/**
 * QuestUP Admin Authentication & Session Management
 */

declare(strict_types=1);

require_once __DIR__ . '/database.php';

if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_httponly', '1');
    ini_set('session.use_only_cookies', '1');
    ini_set('session.cookie_samesite', 'Lax');
    session_start();
}

define('SESSION_TIMEOUT_SECONDS', 7200); // 2 hours

function is_admin_logged_in(): bool {
    if (!isset($_SESSION['admin_user_id']) || empty($_SESSION['admin_user_id'])) {
        return false;
    }

    if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > SESSION_TIMEOUT_SECONDS)) {
        admin_logout();
        return false;
    }

    $_SESSION['last_activity'] = time();
    return true;
}

function require_admin(): void {
    if (!is_admin_logged_in()) {
        $loginUrl = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\') . '/login.php';
        if (strpos($_SERVER['SCRIPT_NAME'], '/pages/') !== false || strpos($_SERVER['SCRIPT_NAME'], '/actions/') !== false) {
            $loginUrl = '../login.php';
        }
        header("Location: $loginUrl");
        exit;
    }
}

function get_current_admin(): ?array {
    if (!is_admin_logged_in()) {
        return null;
    }

    return [
        'id' => $_SESSION['admin_user_id'] ?? '',
        'username' => $_SESSION['admin_username'] ?? 'Admin',
        'email' => $_SESSION['admin_email'] ?? '',
        'full_name' => $_SESSION['admin_full_name'] ?? 'QuestUP Admin',
        'role' => $_SESSION['admin_role'] ?? 'superadmin',
    ];
}

function admin_login(string $identifier, string $password): array {
    $identifier = trim($identifier);
    if (empty($identifier) || empty($password)) {
        return ['success' => false, 'message' => 'Please enter username/email and password.'];
    }

    try {
        $db = db();
        $stmt = $db->prepare("
            SELECT id, username, email, password_hash, full_name, role, is_active
            FROM admin_users
            WHERE (username = :u OR email = :e)
            LIMIT 1
        ");
        $stmt->execute(['u' => $identifier, 'e' => $identifier]);
        $admin = $stmt->fetch();

        if (!$admin) {
            return ['success' => false, 'message' => 'Invalid username or password.'];
        }

        if ((int)$admin['is_active'] !== 1) {
            return ['success' => false, 'message' => 'This admin account has been disabled.'];
        }

        if (!password_verify($password, $admin['password_hash'])) {
            return ['success' => false, 'message' => 'Invalid username or password.'];
        }

        // Session fixation protection
        session_regenerate_id(true);

        $_SESSION['admin_user_id'] = $admin['id'];
        $_SESSION['admin_username'] = $admin['username'];
        $_SESSION['admin_email'] = $admin['email'];
        $_SESSION['admin_full_name'] = $admin['full_name'];
        $_SESSION['admin_role'] = $admin['role'];
        $_SESSION['last_activity'] = time();

        // Update last login timestamp
        $update = $db->prepare("UPDATE admin_users SET last_login = NOW() WHERE id = :id");
        $update->execute(['id' => $admin['id']]);

        return ['success' => true, 'message' => 'Login successful!'];
    } catch (PDOException $e) {
        error_log('[Admin Login Error] ' . $e->getMessage());
        return ['success' => false, 'message' => 'Database error occurred during login.'];
    }
}

function admin_logout(): void {
    $_SESSION = [];
    if (ini_get("session.use_cookies")) {
        $params = session_get_cookie_params();
        setcookie(
            session_name(),
            '',
            time() - 42000,
            $params["path"],
            $params["domain"],
            $params["secure"],
            $params["httponly"]
        );
    }
    session_destroy();
}

function csrf_token(): string {
    if (!isset($_SESSION['csrf_token']) || empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function csrf_field(): string {
    return '<input type="hidden" name="csrf_token" value="' . htmlspecialchars(csrf_token(), ENT_QUOTES, 'UTF-8') . '">';
}

function verify_csrf_token(?string $token): bool {
    if (empty($token) || !isset($_SESSION['csrf_token'])) {
        return false;
    }
    return hash_equals($_SESSION['csrf_token'], $token);
}
