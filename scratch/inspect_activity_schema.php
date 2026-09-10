<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

foreach (['activity_logs', 'quest_completions', 'quest_verification_attempts'] as $t) {
    echo "\n=== SCHEMA OF $t ===\n";
    $cols = $db->query("SHOW COLUMNS FROM `$t`")->fetchAll(PDO::FETCH_ASSOC);
    foreach ($cols as $c) {
        echo "{$c['Field']} ({$c['Type']})\n";
    }
    echo "--- SAMPLE DATA ---\n";
    $sample = $db->query("SELECT * FROM `$t` ORDER BY 1 DESC LIMIT 3")->fetchAll(PDO::FETCH_ASSOC);
    print_r($sample);
}
