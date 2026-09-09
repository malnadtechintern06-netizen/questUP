<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$res = $db->query("SELECT id, player_id, name FROM users WHERE player_id IN ('QST-1001', 'QST-1002', 'QST-1003', 'QST-1004')")->fetchAll();
echo json_encode($res, JSON_PRETTY_PRINT);
