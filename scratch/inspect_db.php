<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

echo "=== QUEST_VERIFICATION_ATTEMPTS COLUMNS ===\n";
$acols = $db->query("SHOW COLUMNS FROM quest_verification_attempts")->fetchAll(PDO::FETCH_ASSOC);
foreach ($acols as $c) {
    echo "  {$c['Field']} ({$c['Type']})\n";
}

echo "\n=== QUESTS VERIFICATION_TYPE DISTINCT VALUES ===\n";
$types = $db->query("SELECT DISTINCT verification_type, COUNT(*) as cnt FROM quests GROUP BY verification_type")->fetchAll(PDO::FETCH_ASSOC);
print_r($types);

echo "\n=== QUEST_COMPLETIONS COLUMNS ===\n";
$cols = $db->query("SHOW COLUMNS FROM quest_completions")->fetchAll(PDO::FETCH_ASSOC);
foreach ($cols as $c) {
    echo "  {$c['Field']} ({$c['Type']})\n";
}

echo "\n=== QUESTS COLUMNS ===\n";
$qcols = $db->query("SHOW COLUMNS FROM quests")->fetchAll(PDO::FETCH_ASSOC);
foreach ($qcols as $c) {
    echo "  {$c['Field']} ({$c['Type']})\n";
}

echo "\n=== ADMIN USERS ===\n";
$admins = $db->query("SELECT id, username, email, role FROM admin_users")->fetchAll(PDO::FETCH_ASSOC);
print_r($admins);
