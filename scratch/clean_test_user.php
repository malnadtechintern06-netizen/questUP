<?php
$pdo = new PDO('mysql:host=127.0.0.1;dbname=questup_db', 'root', '');
$pdo->exec("DELETE FROM user_profiles WHERE email = 'present.test@questup.app'");
$pdo->exec("DELETE FROM users WHERE email = 'present.test@questup.app'");
echo "CLEANUP_DONE\n";
