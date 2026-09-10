<?php
require __DIR__ . '/../backend/config/database.php';

try {
    $db = db();
    $dbName = $db->query('SELECT DATABASE()')->fetchColumn();
    $serverVer = $db->getAttribute(PDO::ATTR_SERVER_VERSION);
    $userCount = (int)$db->query('SELECT COUNT(*) FROM users')->fetchColumn();
    $profileCount = (int)$db->query('SELECT COUNT(*) FROM user_profiles')->fetchColumn();
    $questCount = (int)$db->query('SELECT COUNT(*) FROM quests WHERE is_active = 1')->fetchColumn();
    $completionCount = (int)$db->query('SELECT COUNT(*) FROM quest_completions')->fetchColumn();
    $friendRequestCount = (int)$db->query('SELECT COUNT(*) FROM friend_requests')->fetchColumn();

    $stmt = $db->query('SHOW TABLES');
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);

    echo "=== PHP DATABASE CONNECTION REPORT ===\n";
    echo "Connection Status: CONNECTED SUCCESSFULLY\n";
    echo "Connected Database: " . $dbName . "\n";
    echo "MySQL Server Version: " . $serverVer . "\n";
    echo "Total Database Tables: " . count($tables) . "\n";
    echo "Active Quests in MySQL: " . $questCount . "\n";
    echo "Registered Users in MySQL: " . $userCount . "\n";
    echo "User Profiles: " . $profileCount . "\n";
    echo "Verified Quest Completions: " . $completionCount . "\n";
    echo "Friend Requests: " . $friendRequestCount . "\n";
    echo "Tables List: " . implode(", ", $tables) . "\n";
    echo "=======================================\n";
} catch (Throwable $e) {
    echo "Connection Failed: " . $e->getMessage() . "\n";
}
