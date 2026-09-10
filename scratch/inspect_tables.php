<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

echo "=== TABLES IN questup_db ===\n";
$tables = $db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $t) {
    $count = $db->query("SELECT COUNT(*) FROM `$t`")->fetchColumn();
    echo "- $t: $count rows\n";
}
