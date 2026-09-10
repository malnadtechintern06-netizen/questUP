<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$indices = $db->query("SHOW INDEX FROM quest_completions")->fetchAll(PDO::FETCH_ASSOC);
foreach ($indices as $idx) {
    echo "Index: {$idx['Key_name']} | Column: {$idx['Column_name']} | Non_unique: {$idx['Non_unique']}\n";
}
