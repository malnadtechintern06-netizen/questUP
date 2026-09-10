<?php
$ch = curl_init('http://127.0.0.1/questUP/backend/api/friends/search.php?query=' . urlencode('QST-9762'));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$res = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Search QST-9762 -> Code: $code\nResponse: $res\n";

$ch2 = curl_init('http://127.0.0.1/questUP/backend/api/friends/search.php?query=' . urlencode('9762'));
curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
$res2 = curl_exec($ch2);
curl_close($ch2);

echo "Search 9762 -> Response: $res2\n";

$ch3 = curl_init('http://127.0.0.1/questUP/backend/api/friends/search.php?query=' . urlencode('Sujan'));
curl_setopt($ch3, CURLOPT_RETURNTRANSFER, true);
$res3 = curl_exec($ch3);
curl_close($ch3);

echo "Search Sujan -> Response: $res3\n";
