<?php
/**
 * QuestUP Admin - User Actions Handler
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../includes/functions.php';

require_admin();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ../pages/users.php');
    exit;
}

$token = $_POST['csrf_token'] ?? '';
if (!verify_csrf_token($token)) {
    set_flash('danger', 'Security validation failed (CSRF token invalid).');
    header('Location: ../pages/users.php');
    exit;
}

$action = trim($_POST['action'] ?? '');
$db = db();

switch ($action) {
    case 'update_user':
        $userId = trim($_POST['user_id'] ?? '');
        $name = trim($_POST['name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $status = in_array($_POST['status'] ?? '', ['active', 'disabled']) ? $_POST['status'] : 'active';
        $level = max(1, (int)($_POST['level'] ?? 1));
        $currentXp = max(0, (int)($_POST['current_xp'] ?? 0));
        $xpNext = max(100, (int)($_POST['xp_to_next_level'] ?? 500));
        $coins = max(0, (int)($_POST['coins'] ?? 0));

        if (empty($userId) || empty($name) || empty($email)) {
            set_flash('danger', 'Please provide valid name and email.');
            header("Location: ../pages/user_edit.php?id=" . urlencode($userId));
            exit;
        }

        try {
            $db->beginTransaction();

            // Update Users table
            $stmt = $db->prepare("
                UPDATE users
                SET name = :name, email = :email, status = :status
                WHERE id = :id
            ");
            $stmt->execute([
                'name' => $name,
                'email' => $email,
                'status' => $status,
                'id' => $userId,
            ]);

            // Update or Insert into User Profiles table
            $stmt = $db->prepare("
                INSERT INTO user_profiles (user_id, name, email, level, current_xp, xp_to_next_level, coins)
                VALUES (:user_id, :name, :email, :level, :current_xp, :xp_to_next_level, :coins)
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    email = VALUES(email),
                    level = VALUES(level),
                    current_xp = VALUES(current_xp),
                    xp_to_next_level = VALUES(xp_to_next_level),
                    coins = VALUES(coins)
            ");
            $stmt->execute([
                'user_id' => $userId,
                'name' => $name,
                'email' => $email,
                'level' => $level,
                'current_xp' => $currentXp,
                'xp_to_next_level' => $xpNext,
                'coins' => $coins,
            ]);

            $db->commit();
            set_flash('success', "Explorer '{$name}' updated successfully!");
            header("Location: ../pages/user_view.php?id=" . urlencode($userId));
            exit;
        } catch (PDOException $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            error_log('[Update User Error] ' . $e->getMessage());
            set_flash('danger', 'Failed to update user: ' . $e->getMessage());
            header("Location: ../pages/user_edit.php?id=" . urlencode($userId));
            exit;
        }

    case 'toggle_status':
        $userId = trim($_POST['user_id'] ?? '');
        $currentStatus = trim($_POST['current_status'] ?? 'active');
        $newStatus = ($currentStatus === 'disabled') ? 'active' : 'disabled';

        if (empty($userId)) {
            set_flash('danger', 'Invalid user specified.');
            header('Location: ../pages/users.php');
            exit;
        }

        try {
            $stmt = $db->prepare("UPDATE users SET status = :status WHERE id = :id");
            $stmt->execute(['status' => $newStatus, 'id' => $userId]);
            set_flash('success', "User status updated to " . ucfirst($newStatus) . ".");
        } catch (PDOException $e) {
            set_flash('danger', 'Error updating status: ' . $e->getMessage());
        }
        header('Location: ../pages/users.php');
        exit;

    case 'delete_user':
        $userId = trim($_POST['user_id'] ?? '');
        if (empty($userId)) {
            set_flash('danger', 'Invalid user ID.');
            header('Location: ../pages/users.php');
            exit;
        }

        try {
            $db->beginTransaction();
            // Delete child associations
            $stmt = $db->prepare("DELETE FROM user_badges WHERE user_id = :id");
            $stmt->execute(['id' => $userId]);

            $stmt = $db->prepare("DELETE FROM quest_completions WHERE user_id = :id");
            $stmt->execute(['id' => $userId]);

            $stmt = $db->prepare("DELETE FROM notifications WHERE user_id = :id");
            $stmt->execute(['id' => $userId]);

            $stmt = $db->prepare("DELETE FROM user_profiles WHERE user_id = :id");
            $stmt->execute(['id' => $userId]);

            $stmt = $db->prepare("DELETE FROM users WHERE id = :id");
            $stmt->execute(['id' => $userId]);

            $db->commit();
            set_flash('success', 'User and all associated data permanently deleted.');
        } catch (PDOException $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            error_log('[Delete User Error] ' . $e->getMessage());
            set_flash('danger', 'Failed to delete user: ' . $e->getMessage());
        }
        header('Location: ../pages/users.php');
        exit;

    default:
        set_flash('warning', 'Unknown action requested.');
        header('Location: ../pages/users.php');
        exit;
}
