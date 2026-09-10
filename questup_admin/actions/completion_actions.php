<?php
/**
 * QuestUP Admin - Completion & Verification Actions Handler
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../includes/functions.php';

require_admin();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ../pages/verification.php');
    exit;
}

$token = $_POST['csrf_token'] ?? '';
if (!verify_csrf_token($token)) {
    set_flash('danger', 'Security validation failed (CSRF token invalid).');
    header('Location: ../pages/verification.php');
    exit;
}

$action = trim($_POST['action'] ?? '');
$db = db();
$currentAdmin = get_current_admin();
$adminId = $currentAdmin['id'] ?? 'admin';

switch ($action) {
    case 'approve_verification':
        $completionId = trim($_POST['completion_id'] ?? '');
        $attemptId = trim($_POST['attempt_id'] ?? '');
        $userId = trim($_POST['user_id'] ?? '');
        $xpReward = max(0, (int)($_POST['xp_reward'] ?? 100));
        $coinsReward = max(0, (int)($_POST['coins_reward'] ?? 50));

        if (empty($completionId) || empty($userId)) {
            set_flash('danger', 'Invalid completion or user ID specified.');
            header('Location: ../pages/verification.php');
            exit;
        }

        try {
            $db->beginTransaction();

            // 1. Update completion record status and awarded amounts
            $stmt = $db->prepare("
                UPDATE quest_completions
                SET status = 'verified',
                    xp_earned = :xp,
                    coins_earned = :coins,
                    reviewed_by = :admin,
                    review_notes = 'Approved by admin review'
                WHERE id = :id
            ");
            $stmt->execute([
                'xp' => $xpReward,
                'coins' => $coinsReward,
                'admin' => $adminId,
                'id' => $completionId,
            ]);

            // 2. Update verification attempt if linked
            if (!empty($attemptId)) {
                $db->prepare("
                    UPDATE quest_verification_attempts
                    SET status = 'approved',
                        verified_at = NOW()
                    WHERE attempt_id = :aid
                ")->execute(['aid' => $attemptId]);
            }

            // 3. Fetch current profile stats and atomically update XP/Coins
            $profStmt = $db->prepare("SELECT user_id, level, current_xp, xp_to_next_level, coins FROM user_profiles WHERE user_id = :id FOR UPDATE");
            $profStmt->execute(['id' => $userId]);
            $prof = $profStmt->fetch();

            if ($prof) {
                $newXp = (int)$prof['current_xp'] + $xpReward;
                $newCoins = (int)$prof['coins'] + $coinsReward;
                $level = (int)$prof['level'];
                $xpNext = (int)$prof['xp_to_next_level'];

                // Check Level Up calculation
                while ($newXp >= $xpNext && $xpNext > 0) {
                    $newXp -= $xpNext;
                    $level++;
                    $xpNext = (int)round($xpNext * 1.35); // 35% scaling per level
                }

                $updateProf = $db->prepare("
                    UPDATE user_profiles
                    SET current_xp = :xp,
                        coins = :coins,
                        level = :level,
                        xp_to_next_level = :xp_next,
                        updated_at = NOW()
                    WHERE user_id = :id
                ");
                $updateProf->execute([
                    'xp' => $newXp,
                    'coins' => $newCoins,
                    'level' => $level,
                    'xp_next' => $xpNext,
                    'id' => $userId,
                ]);
            }

            // 4. Send congratulatory system notification
            $notifId = generate_uuid();
            $notifStmt = $db->prepare("
                INSERT INTO notifications (id, user_id, title, message, type, is_read, route_target, action_label, created_at)
                VALUES (:id, :user_id, 'Quest Verified!', :message, 'quest', 0, '/profile', 'View Rewards', NOW())
            ");
            $notifStmt->execute([
                'id' => $notifId,
                'user_id' => $userId,
                'message' => "Your quest completion was approved by an administrator! You earned +{$xpReward} XP and +{$coinsReward} Gold Coins.",
            ]);

            $db->commit();
            set_flash('success', "Submission approved! Granted +{$xpReward} XP and +{$coinsReward} Coins to explorer.");
        } catch (PDOException $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            error_log('[Approve Verification Error] ' . $e->getMessage());
            set_flash('danger', 'Failed to approve verification: ' . $e->getMessage());
        }
        header('Location: ../pages/verification.php');
        exit;

    case 'reject_verification':
        $completionId = trim($_POST['completion_id'] ?? '');
        $attemptId = trim($_POST['attempt_id'] ?? '');
        $notes = trim($_POST['review_notes'] ?? 'Verification rejected by administrator.');

        if (!empty($completionId)) {
            try {
                $db->beginTransaction();

                $stmt = $db->prepare("
                    UPDATE quest_completions
                    SET status = 'rejected',
                        reviewed_by = :admin,
                        review_notes = :notes
                    WHERE id = :id
                ");
                $stmt->execute([
                    'admin' => $adminId,
                    'notes' => $notes,
                    'id' => $completionId,
                ]);

                if (!empty($attemptId)) {
                    $db->prepare("
                        UPDATE quest_verification_attempts
                        SET status = 'rejected',
                            failure_reason = :notes
                        WHERE attempt_id = :aid
                    ")->execute(['notes' => $notes, 'aid' => $attemptId]);
                }

                $db->commit();
                set_flash('warning', 'Submission rejected. No rewards were awarded.');
            } catch (PDOException $e) {
                if ($db->inTransaction()) {
                    $db->rollBack();
                }
                set_flash('danger', 'Error updating submission: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/verification.php');
        exit;

    case 'flag_review':
        $completionId = trim($_POST['completion_id'] ?? '');
        $attemptId = trim($_POST['attempt_id'] ?? '');
        if (!empty($completionId)) {
            try {
                $stmt = $db->prepare("
                    UPDATE quest_completions
                    SET status = 'review',
                        reviewed_by = :admin,
                        review_notes = 'Flagged for anti-cheat and security review'
                    WHERE id = :id
                ");
                $stmt->execute([
                    'admin' => $adminId,
                    'id' => $completionId,
                ]);

                if (!empty($attemptId)) {
                    $db->prepare("
                        UPDATE quest_verification_attempts
                        SET is_suspicious = 1,
                            status = 'flagged',
                            suspicious_reason = 'Flagged by administrator'
                        WHERE attempt_id = :aid
                    ")->execute(['aid' => $attemptId]);
                }

                set_flash('info', 'Submission flagged for secondary review.');
            } catch (PDOException $e) {
                set_flash('danger', 'Error flagging submission: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/verification.php');
        exit;

    case 'delete_completion':
        $completionId = trim($_POST['completion_id'] ?? '');
        if (!empty($completionId)) {
            try {
                $stmt = $db->prepare("DELETE FROM quest_completions WHERE id = :id");
                $stmt->execute(['id' => $completionId]);
                set_flash('success', 'Completion record deleted.');
            } catch (PDOException $e) {
                set_flash('danger', 'Error deleting record: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/completions.php');
        exit;

    default:
        set_flash('warning', 'Unknown action requested.');
        header('Location: ../pages/verification.php');
        exit;
}
