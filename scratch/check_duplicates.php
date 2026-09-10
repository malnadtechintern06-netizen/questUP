<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

echo "=== CHECKING DUPLICATE PLAYER IDs ===\n";
$stmt = $db->query("
    SELECT player_id, COUNT(*) as cnt, GROUP_CONCAT(name SEPARATOR ', ') as names, GROUP_CONCAT(email SEPARATOR ', ') as emails
    FROM users 
    WHERE player_id IS NOT NULL AND player_id != ''
    GROUP BY player_id 
    HAVING cnt > 1
");
$dups = $stmt->fetchAll(PDO::FETCH_ASSOC);
print_r($dups);

echo "\n=== TOTAL USERS WITH NULL OR EMPTY PLAYER_ID ===\n";
$stmt = $db->query("SELECT id, name, email FROM users WHERE player_id IS NULL OR player_id = ''");
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
