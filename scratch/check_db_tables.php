<?php
require __DIR__ . '/../backend/config/database.php';
$db = db();
$stmt = $db->query("SHOW TABLES");
$tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
echo "Existing tables in questup_db:\n" . implode("\n", $tables) . "\n";
