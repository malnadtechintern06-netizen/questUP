<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$cols = $db->query("DESCRIBE quests")->fetchAll(PDO::FETCH_ASSOC);
foreach ($cols as $c) {
    echo $c['Field'] . ' (' . $c['Type'] . ')' . PHP_EOL;
}
