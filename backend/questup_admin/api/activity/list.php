<?php
/**
 * QuestUP REST API - List Activities
 * Endpoint: GET /api/activity/list.php
 *
 * Fetches recent activity records from `activity_logs` table.
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$userId = trim($_GET['user_id'] ?? '');
$limit = min(max((int)($_GET['limit'] ?? 50), 1), 200);

$db = db();

try {
    if (!empty($userId)) {
        $stmt = $db->prepare("
            SELECT id, user_id, action, details, ip_address, created_at
            FROM activity_logs
            WHERE user_id = :uid
            ORDER BY created_at DESC
            LIMIT :lim
        ");
        $stmt->bindValue(':uid', $userId, PDO::PARAM_STR);
        $stmt->bindValue(':lim', $limit, PDO::PARAM_INT);
        $stmt->execute();
    } else {
        $stmt = $db->prepare("
            SELECT id, user_id, action, details, ip_address, created_at
            FROM activity_logs
            ORDER BY created_at DESC
            LIMIT :lim
        ");
        $stmt->bindValue(':lim', $limit, PDO::PARAM_INT);
        $stmt->execute();
    }

    $activities = $stmt->fetchAll();

    echo json_encode([
        'success' => true,
        'count' => count($activities),
        'activities' => $activities,
    ]);
} catch (\Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to fetch activities: ' . $e->getMessage(),
    ]);
}
