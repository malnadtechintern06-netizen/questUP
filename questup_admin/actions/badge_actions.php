<?php
/**
 * QuestUP Admin - Badge Actions Handler
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../includes/functions.php';

require_admin();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ../pages/badges.php');
    exit;
}

$token = $_POST['csrf_token'] ?? '';
if (!verify_csrf_token($token)) {
    set_flash('danger', 'Security validation failed (CSRF token invalid).');
    header('Location: ../pages/badges.php');
    exit;
}

$action = trim($_POST['action'] ?? '');
$db = db();

switch ($action) {
    case 'create_badge':
        $name = trim($_POST['name'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $category = trim($_POST['category'] ?? 'exploration');
        $xpBonus = max(0, (int)($_POST['xp_bonus'] ?? 100));

        if (empty($name) || empty($description)) {
            set_flash('danger', 'Please provide badge name and description.');
            header('Location: ../pages/badges.php');
            exit;
        }

        $badgeId = 'badge_' . preg_replace('/[^a-z0-9_]/', '', strtolower(str_replace(' ', '_', $name))) . '_' . substr(bin2hex(random_bytes(2)), 0, 4);

        try {
            $stmt = $db->prepare("
                INSERT INTO badges (id, name, description, icon, category, xp_bonus, is_active, created_at)
                VALUES (:id, :name, :description, 'badge_crown', :category, :xp_bonus, 1, NOW())
            ");
            $stmt->execute([
                'id' => $badgeId,
                'name' => $name,
                'description' => $description,
                'category' => $category,
                'xp_bonus' => $xpBonus,
            ]);
            set_flash('success', "Badge '{$name}' created in catalog!");
        } catch (PDOException $e) {
            set_flash('danger', 'Failed to create badge: ' . $e->getMessage());
        }
        header('Location: ../pages/badges.php');
        exit;

    case 'assign_badge':
        $userId = trim($_POST['user_id'] ?? '');
        $badgeId = trim($_POST['badge_id'] ?? '');
        $grantXp = (int)($_POST['grant_xp'] ?? 0) === 1;

        if (empty($userId) || empty($badgeId)) {
            set_flash('danger', 'Please select both an explorer and a badge.');
            header('Location: ../pages/badges.php');
            exit;
        }

        try {
            $db->beginTransaction();

            $id = generate_uuid();
            $stmt = $db->prepare("
                INSERT INTO user_badges (id, user_id, badge_id, earned_at)
                VALUES (:id, :user_id, :badge_id, NOW())
                ON DUPLICATE KEY UPDATE earned_at = NOW()
            ");
            $stmt->execute([
                'id' => $id,
                'user_id' => $userId,
                'badge_id' => $badgeId,
            ]);

            if ($grantXp) {
                $bStmt = $db->prepare("SELECT xp_bonus, name FROM badges WHERE id = :id LIMIT 1");
                $bStmt->execute(['id' => $badgeId]);
                $b = $bStmt->fetch();
                $bonus = (int)($b['xp_bonus'] ?? 100);

                $uStmt = $db->prepare("UPDATE user_profiles SET current_xp = current_xp + :bonus WHERE user_id = :id");
                $uStmt->execute(['bonus' => $bonus, 'id' => $userId]);

                // Create in-game notification
                $nStmt = $db->prepare("
                    INSERT INTO notifications (id, user_id, title, message, type, is_read, route_target, action_label, created_at)
                    VALUES (:id, :user_id, 'Badge Awarded!', :msg, 'achievement', 0, '/achievements', 'View Badges', NOW())
                ");
                $nStmt->execute([
                    'id' => generate_uuid(),
                    'user_id' => $userId,
                    'msg' => "You were awarded the '{$b['name']}' badge and +{$bonus} XP!",
                ]);
            }

            $db->commit();
            set_flash('success', "Badge successfully bestowed upon explorer!");
        } catch (PDOException $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            set_flash('danger', 'Failed to assign badge: ' . $e->getMessage());
        }
        header('Location: ../pages/badges.php');
        exit;

    case 'toggle_badge':
        $badgeId = trim($_POST['badge_id'] ?? '');
        $currentStatus = (int)($_POST['current_status'] ?? 1);
        $newStatus = ($currentStatus === 1) ? 0 : 1;

        if (!empty($badgeId)) {
            try {
                $stmt = $db->prepare("UPDATE badges SET is_active = :status WHERE id = :id");
                $stmt->execute(['status' => $newStatus, 'id' => $badgeId]);
                set_flash('success', "Badge status updated.");
            } catch (PDOException $e) {
                set_flash('danger', 'Error updating badge status: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/badges.php');
        exit;

    case 'delete_badge':
        $badgeId = trim($_POST['badge_id'] ?? '');
        if (!empty($badgeId)) {
            try {
                $db->beginTransaction();
                $stmt = $db->prepare("DELETE FROM user_badges WHERE badge_id = :id");
                $stmt->execute(['id' => $badgeId]);

                $stmt = $db->prepare("DELETE FROM badges WHERE id = :id");
                $stmt->execute(['id' => $badgeId]);
                $db->commit();
                set_flash('success', 'Badge removed from catalog.');
            } catch (PDOException $e) {
                if ($db->inTransaction()) {
                    $db->rollBack();
                }
                set_flash('danger', 'Failed to delete badge: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/badges.php');
        exit;

    default:
        set_flash('warning', 'Unknown action.');
        header('Location: ../pages/badges.php');
        exit;
}
