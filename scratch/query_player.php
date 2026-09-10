<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

$stmt = $db->query("SELECT id, player_id, name, email FROM users WHERE player_id LIKE '%1003%' OR id LIKE '%comp_3%'");
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
