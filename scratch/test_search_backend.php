<?php
$_GET['query'] = '2794';
$_GET['current_user_id'] = 'fe9bcb4b-880d-4ae8-b0f1-9317c1306afa'; // sujusujans700 searching for days58490
ob_start();
require __DIR__ . '/../backend/api/friends/search.php';
$output = ob_get_clean();
echo "SEARCH FOR 2794 OUTPUT:\n" . $output . "\n";
