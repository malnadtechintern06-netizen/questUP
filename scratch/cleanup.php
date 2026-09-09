<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();
$db->exec("DELETE FROM friend_requests WHERE receiver_id = 'comp_3' OR sender_id = 'comp_3'");
echo "CLEANED_REQ_OK\n";
