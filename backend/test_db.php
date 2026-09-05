<?php
/**
 * QuestUP Database & API Diagnostic Tool
 * Access at: http://localhost/questUP/backend/test_db.php
 */

declare(strict_types=1);

require_once __DIR__ . '/config/database.php';

header('Content-Type: application/json; charset=utf-8');

try {
    $db = db();

    // Check quests table
    $stmt = $db->query("SHOW TABLES LIKE 'quests'");
    $tableExists = ($stmt && $stmt->rowCount() > 0) ? 'YES' : 'NO';

    $totalQuests = 0;
    $activeQuests = 0;
    $latestTitle = 'None';
    $latestId = 'None';
    $latestCreatedAt = 'None';

    if ($tableExists === 'YES') {
        $totStmt = $db->query("SELECT COUNT(*) FROM quests");
        $totalQuests = (int)$totStmt->fetchColumn();

        $actStmt = $db->query("SELECT COUNT(*) FROM quests WHERE is_active = 1");
        $activeQuests = (int)$actStmt->fetchColumn();

        $latStmt = $db->query("SELECT id, title, created_at FROM quests ORDER BY created_at DESC LIMIT 1");
        $latest = $latStmt->fetch(PDO::FETCH_ASSOC);
        if ($latest) {
            $latestTitle = $latest['title'];
            $latestId = $latest['id'];
            $latestCreatedAt = $latest['created_at'];
        }
    }

    echo json_encode([
        'status' => 'OK',
        'database' => 'questup_db',
        'quests_table_exists' => $tableExists,
        'total_quests' => $totalQuests,
        'active_quests' => $activeQuests,
        'latest_quest_title' => $latestTitle,
        'latest_quest_id' => $latestId,
        'latest_quest_created_at' => $latestCreatedAt,
        'api_url' => 'http://localhost/questUP/backend/api/quests/list.php',
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'ERROR',
        'database' => 'questup_db',
        'message' => $e->getMessage(),
    ], JSON_PRETTY_PRINT);
}
