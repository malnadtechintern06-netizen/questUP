<?php
/**
 * QuestUP REST API - List Active Quests
 * Endpoint: GET /api/quests/list.php
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('Expires: 0');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';

$db = db();

try {
    $category = trim($_GET['category'] ?? '');
    $limit = min(100, max(1, (int)($_GET['limit'] ?? 50)));

    $where = ["is_active = 1"];
    $params = [];

    if ($category !== '' && $category !== 'all') {
        $where[] = "category = :cat";
        $params['cat'] = $category;
    }

    $whereSql = implode(' AND ', $where);

    $stmt = $db->prepare("
        SELECT id, title, description, category, verification_type,
               latitude, longitude, radius_meters, xp_reward, coins_reward,
               location_name, place_type, image_asset_path, difficulty, is_active, created_at
        FROM quests
        WHERE $whereSql
        ORDER BY created_at DESC
        LIMIT $limit
    ");
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $quests = [];
    foreach ($rows as $row) {
        $quests[] = [
            'id' => (string)$row['id'],
            'title' => (string)$row['title'],
            'description' => (string)$row['description'],
            'category' => (string)$row['category'],
            'verificationType' => (string)$row['verification_type'],
            'latitude' => (float)$row['latitude'],
            'longitude' => (float)$row['longitude'],
            'radiusMeters' => (float)$row['radius_meters'],
            'xpReward' => (int)$row['xp_reward'],
            'coinReward' => (int)$row['coins_reward'],
            'locationName' => (string)($row['location_name'] ?? 'Current Area'),
            'placeType' => (string)($row['place_type'] ?? 'landmark'),
            'photoUrl' => $row['image_asset_path'] ?: null,
            'imageUrl' => $row['image_asset_path'] ?: null,
            'difficulty' => (string)($row['difficulty'] ?? 'medium'),
            'isActive' => (bool)$row['is_active'],
            'createdAt' => (string)$row['created_at'],
        ];
    }

    echo json_encode([
        'success' => true,
        'count' => count($quests),
        'quests' => $quests,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to retrieve quests: ' . $e->getMessage(),
    ]);
}
