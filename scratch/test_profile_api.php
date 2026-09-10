<?php
$pdo = new PDO('mysql:host=127.0.0.1;dbname=questup_db', 'root', '');
$pdo->exec("DELETE FROM user_profiles WHERE user_id = 'usr_test_verification_sync'");
$pdo->exec("DELETE FROM users WHERE id = 'usr_test_verification_sync'");
echo "Cleaned up!\n";
