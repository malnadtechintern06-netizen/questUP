<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$sample = $db->query("SELECT id, title, category, verification_type, requirements_json FROM quests LIMIT 5")->fetchAll(PDO::FETCH_ASSOC);
print_r($sample);
