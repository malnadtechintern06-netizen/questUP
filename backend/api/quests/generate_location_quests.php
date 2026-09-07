<?php
/**
 * QuestUP REST API - Generate Dynamic Location-Based Quests
 * Endpoint: POST /api/quests/generate_location_quests.php or /backend/api/quests/generate_location_quests.php
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/google_places.php';

$rawBody = file_get_contents('php://input');
if (empty($rawBody)) {
    $rawBody = @file_get_contents('php://stdin');
}
$data = json_decode($rawBody ?? '', true) ?? $_POST;

$lat = isset($data['latitude']) ? (float)$data['latitude'] : null;
$lon = isset($data['longitude']) ? (float)$data['longitude'] : null;
$userId = isset($data['user_id']) ? trim((string)$data['user_id']) : null;
$config = google_places_config();
$searchRadius = isset($data['radius_meters']) ? max(1000, (int)$data['radius_meters']) : $config['search_radius_meters'];
$movementThreshold = $config['movement_regeneration_threshold_meters'];
$maxQuests = $config['max_quests_to_generate'];

if ($lat === null || $lon === null || $lat == 0.0 || $lon == 0.0) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Valid current GPS latitude and longitude are required.',
    ]);
    exit;
}

error_log("[QuestUP Location Quest] Requesting nearby landmarks...");

$db = db();

/**
 * Helper: Calculate Haversine distance in meters between two lat/lon points
 */
function haversine_distance(float $lat1, float $lon1, float $lat2, float $lon2): float {
    $earthRadius = 6371000.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a = sin($dLat / 2) * sin($dLat / 2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLon / 2) * sin($dLon / 2);
    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
    return $earthRadius * $c;
}

// 1. Check if active location quests were already generated near these coordinates (within movementThreshold)
try {
    $existingStmt = $db->prepare("
        SELECT * FROM quests 
        WHERE source_type = 'location_generated' 
          AND is_active = 1
          AND generation_latitude IS NOT NULL 
          AND generation_longitude IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 30
    ");
    $existingStmt->execute();
    $existingRows = $existingStmt->fetchAll(PDO::FETCH_ASSOC);

    $cachedQuests = [];
    foreach ($existingRows as $row) {
        $genLat = (float)$row['generation_latitude'];
        $genLon = (float)$row['generation_longitude'];
        $dist = haversine_distance($lat, $lon, $genLat, $genLon);
        if ($dist <= $movementThreshold) {
            $cachedQuests[] = $row;
        }
    }

    if (count($cachedQuests) >= 4) {
        // Reuse existing generated quests within current area
        error_log("[QuestUP Location Quest] Places found: " . count($cachedQuests) . " (cached in area)");
        error_log("[QuestUP Location Quest] Generated quest count: " . count($cachedQuests));
        echo json_encode([
            'success' => true,
            'message' => 'Reusing existing location-based quests for current area.',
            'count' => count($cachedQuests),
            'quests' => format_quests_response($cachedQuests, $lat, $lon),
        ]);
        exit;
    }
} catch (Throwable $e) {
    // Continue to fresh generation
}

// 2. Query landmarks from Google Places API or fallback
$discoveredPlaces = [];

// A. Attempt Google Places Nearby Search if API key is provided
if (!empty($config['api_key'])) {
    $apiKey = $config['api_key'];
    $googleTypes = ['tourist_attraction', 'point_of_interest', 'museum', 'park', 'place_of_worship', 'stadium', 'natural_feature'];
    
    foreach ($googleTypes as $gType) {
        if (count($discoveredPlaces) >= 12) break;
        $url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location={$lat},{$lon}&radius={$searchRadius}&type={$gType}&key={$apiKey}";
        
        $ctx = stream_context_create([
            'http' => [
                'timeout' => 4,
                'header' => "User-Agent: QuestUP-Backend\r\nAccept: application/json\r\n"
            ]
        ]);
        
        $resp = @file_get_contents($url, false, $ctx);
        if ($resp) {
            $json = json_decode($resp, true);
            if (isset($json['results']) && is_array($json['results'])) {
                foreach ($json['results'] as $place) {
                    $pId = $place['place_id'] ?? null;
                    $pName = trim($place['name'] ?? '');
                    $pLat = $place['geometry']['location']['lat'] ?? null;
                    $pLng = $place['geometry']['location']['lng'] ?? null;
                    $types = $place['types'] ?? [];

                    if (!$pId || empty($pName) || $pLat === null || $pLng === null) continue;
                    
                    // Filter out generic commercial or unwanted names
                    $nameLower = strtolower($pName);
                    if (str_contains($nameLower, "d'souza") || str_contains($nameLower, "#99")) continue;

                    // Deduplicate by place_id or name
                    $alreadyFound = false;
                    foreach ($discoveredPlaces as $existing) {
                        if ($existing['place_id'] === $pId || strcasecmp($existing['name'], $pName) === 0) {
                            $alreadyFound = true;
                            break;
                        }
                    }
                    if (!$alreadyFound) {
                        $discoveredPlaces[] = [
                            'place_id' => $pId,
                            'name' => $pName,
                            'latitude' => (float)$pLat,
                            'longitude' => (float)$pLng,
                            'types' => $types,
                            'vicinity' => $place['vicinity'] ?? 'Surrounding Area',
                            'source' => 'google_places',
                        ];
                    }
                }
            }
        }
    }
}

// B. If Google Places has no results or no API key, use OpenStreetMap Overpass as authentic live landmark fallback
if (count($discoveredPlaces) < 4) {
    $overpassMirrors = [
        'https://overpass-api.de/api/interpreter',
        'https://overpass.kumi.systems/api/interpreter',
    ];
    $radiusMeters = min(10000, max(2500, $searchRadius));

    // Fast around query focused on prominent landmarks (attractions, museums, parks, monuments, universities)
    $query = "[out:json][timeout:6];(
        node[\"tourism\"~\"attraction|museum|viewpoint\"](around:{$radiusMeters},{$lat},{$lon});
        node[\"historic\"~\"monument|memorial|castle|fort|heritage\"](around:{$radiusMeters},{$lat},{$lon});
        node[\"leisure\"~\"park|garden\"](around:{$radiusMeters},{$lat},{$lon});
        node[\"amenity\"~\"university|college|library\"](around:{$radiusMeters},{$lat},{$lon});
    );out 25;";

    foreach ($overpassMirrors as $mirror) {
        if (count($discoveredPlaces) >= 10) break;
        $ctx = stream_context_create([
            'http' => [
                'method' => 'POST',
                'timeout' => 6,
                'header' => "Content-Type: application/x-www-form-urlencoded\r\nUser-Agent: QuestUP-Backend/2.0\r\n",
                'content' => 'data=' . urlencode($query),
            ]
        ]);
        $resp = @file_get_contents($mirror, false, $ctx);
        if ($resp) {
            $json = json_decode($resp, true);
            if (isset($json['elements']) && is_array($json['elements'])) {
                foreach ($json['elements'] as $elem) {
                    $tags = $elem['tags'] ?? [];
                    $name = trim($tags['name'] ?? $tags['name:en'] ?? '');
                    if (empty($name) || strlen($name) < 3) continue;

                    $pLat = $elem['lat'] ?? $elem['center']['lat'] ?? null;
                    $pLon = $elem['lon'] ?? $elem['center']['lon'] ?? null;
                    if ($pLat === null || $pLon === null) continue;

                    $nameLower = strtolower($name);
                    if (str_contains($nameLower, "d'souza") || str_contains($nameLower, "#99")) continue;

                    $osmId = 'osm_' . ($elem['type'] ?? 'node') . '_' . ($elem['id'] ?? uniqid());

                    $alreadyFound = false;
                    foreach ($discoveredPlaces as $existing) {
                        if ($existing['place_id'] === $osmId || strcasecmp($existing['name'], $name) === 0) {
                            $alreadyFound = true;
                            break;
                        }
                    }
                    if (!$alreadyFound) {
                        $discoveredPlaces[] = [
                            'place_id' => $osmId,
                            'name' => $name,
                            'latitude' => (float)$pLat,
                            'longitude' => (float)$pLon,
                            'types' => array_keys($tags),
                            'vicinity' => $tags['addr:city'] ?? $tags['addr:suburb'] ?? 'Local Area',
                            'source' => 'osm_overpass',
                        ];
                    }
                }
            }
        }
    }
}

// Tier 2: If fewer than 4 landmarks found (e.g. smaller towns), supplement with local heritage/worship sites within 2.5km
if (count($discoveredPlaces) < 4) {
    $worshipQuery = "[out:json][timeout:5];(
        node[\"amenity\"=\"place_of_worship\"](around:2500,{$lat},{$lon});
    );out 15;";
    foreach ($overpassMirrors as $mirror) {
        if (count($discoveredPlaces) >= 6) break;
        $ctx = stream_context_create([
            'http' => [
                'method' => 'POST',
                'timeout' => 5,
                'header' => "Content-Type: application/x-www-form-urlencoded\r\nUser-Agent: QuestUP-Backend/2.0\r\n",
                'content' => 'data=' . urlencode($worshipQuery),
            ]
        ]);
        $resp = @file_get_contents($mirror, false, $ctx);
        if ($resp) {
            $json = json_decode($resp, true);
            if (isset($json['elements']) && is_array($json['elements'])) {
                foreach ($json['elements'] as $elem) {
                    $tags = $elem['tags'] ?? [];
                    $name = trim($tags['name'] ?? $tags['name:en'] ?? '');
                    if (empty($name) || strlen($name) < 3) continue;
                    $pLat = $elem['lat'] ?? null;
                    $pLon = $elem['lon'] ?? null;
                    if ($pLat === null || $pLon === null) continue;
                    $nameLower = strtolower($name);
                    if (str_contains($nameLower, "d'souza") || str_contains($nameLower, "#99")) continue;
                    $osmId = 'osm_node_' . ($elem['id'] ?? uniqid());
                    $alreadyFound = false;
                    foreach ($discoveredPlaces as $existing) {
                        if ($existing['place_id'] === $osmId || strcasecmp($existing['name'], $name) === 0) {
                            $alreadyFound = true;
                            break;
                        }
                    }
                    if (!$alreadyFound) {
                        $discoveredPlaces[] = [
                            'place_id' => $osmId,
                            'name' => $name,
                            'latitude' => (float)$pLat,
                            'longitude' => (float)$pLon,
                            'types' => ['place_of_worship'],
                            'vicinity' => 'Local Area',
                            'source' => 'osm_overpass',
                        ];
                    }
                }
            }
        }
    }
}

// Tier 3: If fewer than 6 landmarks found, reverse-geocode area and discover or anchor local exploration landmarks within 10km
if (count($discoveredPlaces) < 6) {
    try {
        $revUrl = "https://nominatim.openstreetmap.org/reverse?format=json&lat={$lat}&lon={$lon}&zoom=14&addressdetails=1";
        $ctx = stream_context_create([
            'http' => [
                'timeout' => 4,
                'header' => "User-Agent: QuestUP-Backend/2.0\r\nAccept: application/json\r\n"
            ]
        ]);
        $revResp = @file_get_contents($revUrl, false, $ctx);
        $revJson = json_decode($revResp ?? '', true);
        $addr = $revJson['address'] ?? [];
        $localArea = $addr['town'] ?? $addr['village'] ?? $addr['suburb'] ?? $addr['neighbourhood'] ?? $addr['county'] ?? $addr['city_district'] ?? 'Local';
        $state = $addr['state'] ?? 'Karnataka';

        // Search Nominatim for nearby places
        $searchUrl = "https://nominatim.openstreetmap.org/search?format=json&q=" . urlencode("{$localArea} {$state}") . "&limit=8&addressdetails=1";
        $searchResp = @file_get_contents($searchUrl, false, $ctx);
        $searchJson = json_decode($searchResp ?? '', true);

        if (!empty($searchJson) && is_array($searchJson)) {
            foreach ($searchJson as $item) {
                if (count($discoveredPlaces) >= 6) break;
                $pLat = (float)($item['lat'] ?? 0);
                $pLon = (float)($item['lon'] ?? 0);
                if ($pLat == 0.0 || $pLon == 0.0) continue;
                $dist = haversine_distance($lat, $lon, $pLat, $pLon);
                if ($dist <= $searchRadius) {
                    $pName = trim($item['name'] ?? $item['display_name'] ?? '');
                    if (empty($pName) || strlen($pName) < 3) continue;
                    $pId = 'nom_' . ($item['place_id'] ?? md5($pName));
                    $alreadyFound = false;
                    foreach ($discoveredPlaces as $existing) {
                        if ($existing['place_id'] === $pId || strcasecmp($existing['name'], $pName) === 0) {
                            $alreadyFound = true;
                            break;
                        }
                    }
                    if (!$alreadyFound) {
                        $discoveredPlaces[] = [
                            'place_id' => $pId,
                            'name' => $pName,
                            'latitude' => $pLat,
                            'longitude' => $pLon,
                            'types' => ['landmark'],
                            'vicinity' => $localArea,
                            'source' => 'nominatim',
                        ];
                    }
                }
            }
        }

        // If still under 6 places, generate tailored local exploration points anchored in the detected area
        if (count($discoveredPlaces) < 6) {
            $presets = [
                ['suffix' => 'Historic Heritage Landmark', 'dLat' => 0.0031, 'dLon' => -0.0022, 'type' => 'historic'],
                ['suffix' => 'Eco Botanical Park & Trail', 'dLat' => -0.0024, 'dLon' => 0.0028, 'type' => 'park'],
                ['suffix' => 'Public Library & Learning Center', 'dLat' => 0.0018, 'dLon' => 0.0014, 'type' => 'study'],
                ['suffix' => 'Central Station & Transit Hub', 'dLat' => -0.0033, 'dLon' => -0.0019, 'type' => 'landmark'],
                ['suffix' => 'Scenic Hilltop Viewpoint', 'dLat' => 0.0042, 'dLon' => 0.0035, 'type' => 'viewpoint'],
                ['suffix' => 'Community Center & Cultural Hub', 'dLat' => -0.0015, 'dLon' => -0.0038, 'type' => 'culture'],
            ];

            foreach ($presets as $p) {
                if (count($discoveredPlaces) >= 6) break;
                $pName = "{$localArea} {$p['suffix']}";
                $pLat = $lat + $p['dLat'];
                $pLon = $lon + $p['dLon'];
                $pId = 'local_' . strtolower(preg_replace('/[^a-zA-Z0-9]/', '_', $p['suffix'])) . '_' . round($lat, 3) . '_' . round($lon, 3);
                $discoveredPlaces[] = [
                    'place_id' => $pId,
                    'name' => $pName,
                    'latitude' => $pLat,
                    'longitude' => $pLon,
                    'types' => [$p['type']],
                    'vicinity' => $localArea,
                    'source' => 'local_area_anchor',
                ];
            }
        }
    } catch (Throwable $e) {
        error_log("[QuestUP Location Quest] Local fallback error: " . $e->getMessage());
    }
}

error_log("[QuestUP Location Quest] Places found: " . count($discoveredPlaces));

// 3. Sort by distance from user and select top 5–6 unique landmarks
usort($discoveredPlaces, function($a, $b) use ($lat, $lon) {
    $da = haversine_distance($lat, $lon, $a['latitude'], $a['longitude']);
    $db = haversine_distance($lat, $lon, $b['latitude'], $b['longitude']);
    return $da <=> $db;
});

$selectedPlaces = array_slice($discoveredPlaces, 0, $maxQuests);
error_log("[QuestUP Location Quest] Generating quests: " . count($selectedPlaces));

$generatedQuests = [];
$now = date('Y-m-d H:i:s');

foreach ($selectedPlaces as $index => $place) {
    $placeName = $place['name'];
    $placeLat = (float)$place['latitude'];
    $placeLon = (float)$place['longitude'];
    $placeId = $place['place_id'];
    $vicinity = $place['vicinity'] ?? 'Current Area';

    // Tailored questions and mission briefings based on the authentic landmark
    $title = "Explore " . $placeName;
    $description = "Navigate to {$placeName} located in {$vicinity}. Locate the landmark entrance or prominent structure and complete the photo verification.";
    $storyline = "A dynamic expedition has surfaced near your current location: venture to {$placeName}, explore its surroundings, and prove your arrival.";
    
    $questId = 'loc_quest_' . substr(md5($placeId . '_' . round($placeLat, 4) . '_' . round($placeLon, 4)), 0, 16);

    $xp = 250 + ($index * 30);
    $coins = 100 + ($index * 15);
    $radiusMeters = 85.0; // 85m geofence around the landmark
    $category = 'location';
    $vtype = 'photoProof';
    $difficulty = ($index < 2) ? 'easy' : (($index < 4) ? 'medium' : 'hard');

    // Check if quest already exists with this google_place_id or id
    $checkStmt = $db->prepare("SELECT id FROM quests WHERE google_place_id = :gpid OR id = :qid LIMIT 1");
    $checkStmt->execute(['gpid' => $placeId, 'qid' => $questId]);
    $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        $existingId = $existing['id'];
        $upStmt = $db->prepare("
            UPDATE quests SET
                title = :title,
                description = :description,
                storyline = :storyline,
                latitude = :lat,
                longitude = :lon,
                radius_meters = :radius,
                xp_reward = :xp,
                coins_reward = :coins,
                location_name = :loc_name,
                generation_latitude = :gen_lat,
                generation_longitude = :gen_lon,
                user_id = :uid,
                source_type = 'location_generated',
                is_active = 1
            WHERE id = :id
        ");
        $upStmt->execute([
            'id' => $existingId,
            'title' => $title,
            'description' => $description,
            'storyline' => $storyline,
            'lat' => $placeLat,
            'lon' => $placeLon,
            'radius' => $radiusMeters,
            'xp' => $xp,
            'coins' => $coins,
            'loc_name' => $placeName,
            'gen_lat' => $lat,
            'gen_lon' => $lon,
            'uid' => $userId,
        ]);
        $targetQuestId = $existingId;
    } else {
        $insStmt = $db->prepare("
            INSERT INTO quests (
                id, title, description, storyline, category, verification_type,
                latitude, longitude, radius_meters, xp_reward, coins_reward,
                location_name, place_type, image_asset_path, difficulty, is_active,
                required_object, required_drawing_subject, required_place, required_target,
                required_words, required_duration_seconds, required_distance_meters,
                required_lines, required_repetitions,
                requires_gps, requires_photo, requires_fresh_photo, requires_drawing,
                requires_text, requires_video, requires_game_session, icon_key,
                source_type, user_id, google_place_id, generation_latitude, generation_longitude,
                created_at
            ) VALUES (
                :id, :title, :description, :storyline, :category, :verification_type,
                :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward,
                :location_name, :place_type, :image_asset_path, :difficulty, 1,
                NULL, NULL, :required_place, 'Landmark Entrance',
                0, 0, 0,
                0, 0,
                1, 1, 1, 0,
                0, 0, 0, 'landmark',
                'location_generated', :user_id, :google_place_id, :gen_lat, :gen_lon,
                NOW()
            )
        ");
        $insStmt->execute([
            'id' => $questId,
            'title' => $title,
            'description' => $description,
            'storyline' => $storyline,
            'category' => $category,
            'verification_type' => $vtype,
            'latitude' => $placeLat,
            'longitude' => $placeLon,
            'radius_meters' => $radiusMeters,
            'xp_reward' => $xp,
            'coins_reward' => $coins,
            'location_name' => $placeName,
            'place_type' => 'landmark',
            'image_asset_path' => 'assets/images/logo.png',
            'difficulty' => $difficulty,
            'required_place' => $placeName,
            'user_id' => $userId,
            'google_place_id' => $placeId,
            'gen_lat' => $lat,
            'gen_lon' => $lon,
        ]);
        $targetQuestId = $questId;
    }

    $generatedQuests[] = [
        'id' => $targetQuestId,
        'title' => $title,
        'description' => $description,
        'storyline' => $storyline,
        'category' => $category,
        'verificationType' => $vtype,
        'latitude' => $placeLat,
        'longitude' => $placeLon,
        'radiusMeters' => $radiusMeters,
        'xpReward' => $xp,
        'coinReward' => $coins,
        'locationName' => $placeName,
        'placeType' => 'landmark',
        'photoUrl' => 'assets/images/logo.png',
        'imageUrl' => 'assets/images/logo.png',
        'difficulty' => $difficulty,
        'isActive' => true,
        'iconKey' => 'landmark',
        'sourceType' => 'location_generated',
        'googlePlaceId' => $placeId,
        'generationLatitude' => $lat,
        'generationLongitude' => $lon,
        'userId' => $userId,
        'distanceMeters' => round(haversine_distance($lat, $lon, $placeLat, $placeLon), 1),
        'requiresGPS' => true,
        'requiresPhoto' => true,
        'requiresFreshPhoto' => true,
        'createdAt' => $now,
    ];
}

error_log("[QuestUP Location Quest] Generated quest count: " . count($generatedQuests));

echo json_encode([
    'success' => true,
    'message' => 'Location-based quests generated successfully.',
    'count' => count($generatedQuests),
    'quests' => $generatedQuests,
]);

function format_quests_response(array $rows, float $userLat, float $userLon): array {
    $formatted = [];
    foreach ($rows as $r) {
        $qLat = (float)$r['latitude'];
        $qLon = (float)$r['longitude'];
        $formatted[] = [
            'id' => (string)$r['id'],
            'title' => (string)$r['title'],
            'description' => (string)$r['description'],
            'storyline' => (string)($r['storyline'] ?? $r['description']),
            'category' => (string)$r['category'],
            'verificationType' => (string)$r['verification_type'],
            'latitude' => $qLat,
            'longitude' => $qLon,
            'radiusMeters' => (float)$r['radius_meters'],
            'xpReward' => (int)$r['xp_reward'],
            'coinReward' => (int)$r['coins_reward'],
            'locationName' => (string)($r['location_name'] ?? 'Local Landmark'),
            'placeType' => (string)($r['place_type'] ?? 'landmark'),
            'photoUrl' => $r['image_asset_path'] ?: 'assets/images/logo.png',
            'imageUrl' => $r['image_asset_path'] ?: 'assets/images/logo.png',
            'difficulty' => (string)($r['difficulty'] ?? 'medium'),
            'isActive' => (bool)$r['is_active'],
            'iconKey' => (string)($r['icon_key'] ?? 'landmark'),
            'sourceType' => (string)($r['source_type'] ?? 'location_generated'),
            'googlePlaceId' => $r['google_place_id'] ?? null,
            'generationLatitude' => isset($r['generation_latitude']) ? (float)$r['generation_latitude'] : null,
            'generationLongitude' => isset($r['generation_longitude']) ? (float)$r['generation_longitude'] : null,
            'userId' => $r['user_id'] ?? null,
            'distanceMeters' => round(haversine_distance($userLat, $userLon, $qLat, $qLon), 1),
            'requiresGPS' => (bool)($r['requires_gps'] ?? true),
            'requiresPhoto' => (bool)($r['requires_photo'] ?? true),
            'requiresFreshPhoto' => (bool)($r['requires_fresh_photo'] ?? true),
            'createdAt' => (string)$r['created_at'],
        ];
    }
    return $formatted;
}
