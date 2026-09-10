<?php
/**
 * QuestUP REST API - Get User Profile
 * Endpoint: GET /api/profile/get.php?user_id=xyz
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

$userId = trim($_GET['user_id'] ?? ($_GET['id'] ?? ''));
if (empty($userId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required.',
    ]);
    exit;
}

$db = db();

try {
    $stmt = $db->prepare("
        SELECT up.*, u.player_id, u.status as account_status
        FROM user_profiles up
        LEFT JOIN users u ON u.id = up.user_id
        WHERE up.user_id = :uid LIMIT 1
    ");
    $stmt->execute(['uid' => $userId]);
    $profile = $stmt->fetch();

    if (!$profile) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Profile not found.',
        ]);
        exit;
    }

    // Fetch completed quest IDs
    $cmpStmt = $db->prepare("SELECT quest_id FROM quest_completions WHERE user_id = :uid AND status = 'verified'");
    $cmpStmt->execute(['uid' => $userId]);
    $completedQuests = $cmpStmt->fetchAll(PDO::FETCH_COLUMN) ?: [];

    // Fetch earned badge IDs
    $bdgStmt = $db->prepare("SELECT badge_id FROM user_badges WHERE user_id = :uid");
    $bdgStmt->execute(['uid' => $userId]);
    $earnedBadges = $bdgStmt->fetchAll(PDO::FETCH_COLUMN) ?: [];

    echo json_encode([
        'success' => true,
        'profile' => [
            'user_id' => $profile['user_id'],
            'player_id' => $profile['player_id'] ?? 'QST-0000',
            'name' => $profile['name'],
            'email' => $profile['email'],
            'avatar_key' => $profile['avatar_key'] ?? 'avatar_ranger',
            'level' => (int)($profile['level'] ?? 1),
            'current_xp' => (int)($profile['current_xp'] ?? 0),
            'xp_to_next_level' => (int)($profile['xp_to_next_level'] ?? 500),
            'coins' => (int)($profile['coins'] ?? 100),
            'completed_quest_ids' => $completedQuests,
            'earned_badge_ids' => $earnedBadges,
            'joined_at' => $profile['joined_at'],
        ],
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage(),
    ]);
}
