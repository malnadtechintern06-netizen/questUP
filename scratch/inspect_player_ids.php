<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

echo "=== USER SEARCH FOR days58490@gmail.com ===\n";
$stmt = $db->prepare("SELECT id, player_id, name, email FROM users WHERE email LIKE '%days58490%' OR email LIKE '%suju%'");
$stmt->execute();
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));

echo "\n=== ALL DISTINCT player_id IN users TABLE ===\n";
$stmt = $db->query("SELECT player_id, count(*) as cnt FROM users GROUP BY player_id HAVING cnt > 1");
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));

echo "\n=== NULL OR EMPTY player_id IN users TABLE ===\n";
$stmt = $db->query("SELECT count(*) as null_or_empty FROM users WHERE player_id IS NULL OR player_id = ''");
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
