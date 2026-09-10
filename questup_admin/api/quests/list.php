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
    $userId = trim($_GET['user_id'] ?? '');
    $userLat = isset($_GET['lat']) ? (float)$_GET['lat'] : null;
    $userLon = isset($_GET['lng']) ? (float)$_GET['lng'] : null;
    $limit = min(100, max(1, (int)($_GET['limit'] ?? 50)));

    $where = ["is_active = 1"];
    $params = [];

    if ($category !== '' && $category !== 'all') {
        $where[] = "category = :cat";
        $params['cat'] = $category;
    }

    if ($userId !== '') {
        $where[] = "(source_type = 'admin' OR user_id IS NULL OR user_id = :uid)";
        $params['uid'] = $userId;
    }

    $whereSql = implode(' AND ', $where);

    $stmt = $db->prepare("
        SELECT id, title, description, storyline, category, verification_type,
               latitude, longitude, radius_meters, xp_reward, coins_reward,
               location_name, place_type, image_asset_path, difficulty, is_active,
               required_object, required_drawing_subject, required_place, required_target,
               required_words, required_duration_seconds, required_distance_meters,
               required_lines, required_repetitions,
               requires_gps, requires_photo, requires_fresh_photo, requires_drawing,
               requires_text, requires_video, requires_game_session, icon_key,
               source_type, user_id, google_place_id, generation_latitude, generation_longitude,
               created_at
        FROM quests
        WHERE $whereSql
        ORDER BY created_at DESC
        LIMIT $limit
    ");
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $quests = [];
    foreach ($rows as $row) {
        $qLat = (float)$row['latitude'];
        $qLon = (float)$row['longitude'];
        $distMeters = null;
        if ($userLat !== null && $userLon !== null && $qLat != 0.0 && $qLon != 0.0) {
            $earthRadius = 6371000.0;
            $dLat = deg2rad($qLat - $userLat);
            $dLon = deg2rad($qLon - $userLon);
            $a = sin($dLat / 2) * sin($dLat / 2) +
                 cos(deg2rad($userLat)) * cos(deg2rad($qLat)) *
                 sin($dLon / 2) * sin($dLon / 2);
            $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
            $distMeters = round($earthRadius * $c, 1);
        }

        $sourceType = (string)($row['source_type'] ?? 'admin');
        $isLocationQuest = ($sourceType === 'location' || $sourceType === 'location_generated');

        // Global admin quests are ALWAYS visible to everyone across all cities.
        // Location quests are only visible if within 10 km (10000 meters) of the user's current GPS.
        if ($isLocationQuest && $distMeters !== null && $distMeters > 10000) {
            continue;
        }

        $quests[] = [
            'id' => (string)$row['id'],
            'title' => (string)$row['title'],
            'description' => (string)$row['description'],
            'storyline' => (string)($row['storyline'] ?? $row['description']),
            'category' => (string)$row['category'],
            'verificationType' => (string)$row['verification_type'],
            'latitude' => $qLat,
            'longitude' => $qLon,
            'radiusMeters' => (float)$row['radius_meters'],
            'xpReward' => (int)$row['xp_reward'],
            'coinReward' => (int)$row['coins_reward'],
            'locationName' => (string)($row['location_name'] ?? 'Current Area'),
            'placeType' => (string)($row['place_type'] ?? 'landmark'),
            'photoUrl' => $row['image_asset_path'] ?: 'assets/images/logo.png',
            'imageUrl' => $row['image_asset_path'] ?: 'assets/images/logo.png',
            'difficulty' => (string)($row['difficulty'] ?? 'medium'),
            'isActive' => (bool)$row['is_active'],
            'iconKey' => (string)($row['icon_key'] ?? 'landmark'),
            'sourceType' => (string)($row['source_type'] ?? 'admin'),
            'googlePlaceId' => $row['google_place_id'] ?? null,
            'generationLatitude' => isset($row['generation_latitude']) ? (float)$row['generation_latitude'] : null,
            'generationLongitude' => isset($row['generation_longitude']) ? (float)$row['generation_longitude'] : null,
            'userId' => $row['user_id'] ?? null,
            'distanceMeters' => $distMeters,
            'requiredObject' => $row['required_object'] ?: null,
            'requiredDrawingSubject' => $row['required_drawing_subject'] ?: null,
            'requiredPlace' => $row['required_place'] ?: null,
            'requiredTarget' => $row['required_target'] ?: null,
            'requiredWords' => (int)($row['required_words'] ?? 0),
            'requiredDurationSeconds' => (int)($row['required_duration_seconds'] ?? 0),
            'requiredDistanceMeters' => (float)($row['required_distance_meters'] ?? 0.0),
            'requiredLines' => (int)($row['required_lines'] ?? 0),
            'requiredRepetitions' => (int)($row['required_repetitions'] ?? 0),
            'requiresGPS' => (bool)($row['requires_gps'] ?? false),
            'requiresPhoto' => (bool)($row['requires_photo'] ?? false),
            'requiresFreshPhoto' => (bool)($row['requires_fresh_photo'] ?? false),
            'requiresVideo' => (bool)($row['requires_video'] ?? false),
            'requiresDrawing' => (bool)($row['requires_drawing'] ?? false),
            'requiresText' => (bool)($row['requires_text'] ?? false),
            'requiresGameSession' => (bool)($row['requires_game_session'] ?? false),
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
