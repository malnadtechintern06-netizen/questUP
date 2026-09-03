<?php
/**
 * QuestUP Admin - Notification Actions Handler
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../includes/functions.php';

require_admin();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ../pages/notifications.php');
    exit;
}

$token = $_POST['csrf_token'] ?? '';
if (!verify_csrf_token($token)) {
    set_flash('danger', 'Security validation failed (CSRF token invalid).');
    header('Location: ../pages/notifications.php');
    exit;
}

$action = trim($_POST['action'] ?? '');
$db = db();

switch ($action) {
    case 'send_notification':
        $recipientType = trim($_POST['recipient_type'] ?? 'broadcast');
        $targetUserId = trim($_POST['target_user_id'] ?? '');
        $title = trim($_POST['title'] ?? '');
        $message = trim($_POST['message'] ?? '');
        $type = trim($_POST['type'] ?? 'system');
        $route = trim($_POST['route_target'] ?? '/home');
        $actionLabel = trim($_POST['action_label'] ?? 'Open');

        if (empty($title) || empty($message)) {
            set_flash('danger', 'Please enter both title and message.');
            header('Location: ../pages/notifications.php');
            exit;
        }

        if ($recipientType === 'specific' && empty($targetUserId)) {
            set_flash('danger', 'Please select a recipient explorer.');
            header('Location: ../pages/notifications.php');
            exit;
        }

        try {
            $id = generate_uuid();
            $userIdToInsert = ($recipientType === 'specific') ? $targetUserId : null;

            $stmt = $db->prepare("
                INSERT INTO notifications (id, user_id, title, message, type, is_read, route_target, action_label, created_at)
                VALUES (:id, :user_id, :title, :message, :type, 0, :route, :action_label, NOW())
            ");
            $stmt->execute([
                'id' => $id,
                'user_id' => $userIdToInsert,
                'title' => $title,
                'message' => $message,
                'type' => $type,
                'route' => $route,
                'action_label' => $actionLabel,
            ]);

            set_flash('success', ($recipientType === 'broadcast') 
                ? 'Global broadcast notification dispatched to all explorers!' 
                : 'Direct notification dispatched to player!');
        } catch (PDOException $e) {
            error_log('[Send Notification Error] ' . $e->getMessage());
            set_flash('danger', 'Failed to dispatch notification: ' . $e->getMessage());
        }
        header('Location: ../pages/notifications.php');
        exit;

    case 'delete_notification':
        $notifId = trim($_POST['notification_id'] ?? '');
        if (!empty($notifId)) {
            try {
                $stmt = $db->prepare("DELETE FROM notifications WHERE id = :id");
                $stmt->execute(['id' => $notifId]);
                set_flash('success', 'Notification record deleted.');
            } catch (PDOException $e) {
                set_flash('danger', 'Error deleting notification: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/notifications.php');
        exit;

    default:
        set_flash('warning', 'Unknown action requested.');
        header('Location: ../pages/notifications.php');
        exit;
}
