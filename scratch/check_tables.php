<?php
require __DIR__ . '/../backend/config/database.php';
$db = db();
$tables = $db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);
echo "Tables in questup_db:\n" . implode("\n", $tables) . "\n";
