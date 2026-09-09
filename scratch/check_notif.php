<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$res = $db->query("SELECT title, message, type, route_target FROM notifications WHERE user_id = 'comp_3'")->fetchAll();
echo json_encode($res, JSON_PRETTY_PRINT);
