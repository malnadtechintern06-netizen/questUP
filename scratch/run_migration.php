<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$sql = file_get_contents(__DIR__ . '/../backend/database/anti_cheat_migration.sql');

// Split statements by semicolon where appropriate, or run with PDO multi-query
try {
    $db->setAttribute(PDO::ATTR_EMULATE_PREPARES, true);
    $db->exec($sql);
    echo "SUCCESS: anti_cheat_migration.sql applied successfully!\n";
} catch (PDOException $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}

// Verify tables and columns
$tables = $db->query("SHOW TABLES LIKE 'quest_verification_attempts'")->fetchAll();
if (!empty($tables)) {
    echo "VERIFIED: Table 'quest_verification_attempts' exists.\n";
}

$indices = $db->query("SHOW INDEX FROM quest_completions WHERE Key_name = 'uk_user_quest_completion'")->fetchAll();
if (!empty($indices)) {
    echo "VERIFIED: Unique constraint 'uk_user_quest_completion' exists on quest_completions.\n";
}

$cols = $db->query("SHOW COLUMNS FROM quests LIKE 'verification_secret'")->fetchAll();
if (!empty($cols)) {
    echo "VERIFIED: Column 'verification_secret' exists on quests.\n";
}
