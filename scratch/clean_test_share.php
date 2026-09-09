<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$db->exec("DELETE FROM shared_quests WHERE quest_id = 'test_quest_101'");
$db->exec("DELETE FROM notifications WHERE user_id = 'comp_3'");
echo "CLEANUP_TEST_OK\n";
