<?php
/**
 * QuestUP Backend - Google Places & Maps Configuration
 * Secure server-side configuration - never exposed to clients or printed in debug logs.
 */

declare(strict_types=1);

function google_places_config(): array {
    // 1. Read from system environment variable if set
    $apiKey = getenv('GOOGLE_MAPS_API_KEY') ?: '';
    
    // 2. Or fallback to local config constant if defined
    if (empty($apiKey) && defined('GOOGLE_MAPS_SERVER_KEY')) {
        $apiKey = (string)GOOGLE_MAPS_SERVER_KEY;
    }

    return [
        'api_key' => $apiKey,
        'search_radius_meters' => 10000, // 10 km search radius around user current GPS
        'movement_regeneration_threshold_meters' => 500, // 500 meters movement to regenerate
        'max_quests_to_generate' => 6, // 5–6 tailored quests total (LOCATION_QUEST_COUNT = 6)
    ];
}
