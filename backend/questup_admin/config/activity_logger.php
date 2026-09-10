<?php
/**
 * QuestUP - Central Activity Logger Helper
 * Automatically logs user activities, quest attempts, completions, and calendar events
 * into the `activity_logs` table for real-time visibility in phpMyAdmin.
 */

declare(strict_types=1);

require_once __DIR__ . '/database.php';

function logActivity(
    ?string $userId,
    string $action,
    ?string $details = null,
    ?string $ip = null
): bool {
    try {
        $db = db();
        $ip = $ip ?? ($_SERVER['REMOTE_ADDR'] ?? '127.0.0.1');

        $stmt = $db->prepare("
            INSERT INTO activity_logs (user_id, action, details, ip_address, created_at)
            VALUES (:uid, :act, :det, :ip, NOW())
        ");
        return $stmt->execute([
            'uid' => $userId,
            'act' => substr($action, 0, 64),
            'det' => $details,
            'ip'  => substr($ip, 0, 45),
        ]);
    } catch (\Throwable $e) {
        error_log("[QuestUP ActivityLog Error] " . $e->getMessage());
        return false;
    }
}
