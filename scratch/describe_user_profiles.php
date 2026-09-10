<?php
$pdo = new PDO('mysql:host=127.0.0.1;dbname=questup_db', 'root', '');
$stmt = $pdo->query('DESCRIBE user_profiles');
foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
    echo "{$row['Field']} - {$row['Type']} - Default: {$row['Default']} - Extra: {$row['Extra']}\n";
}
