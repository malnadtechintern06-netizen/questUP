<?php
$pdo = new PDO('mysql:host=127.0.0.1;dbname=questup_db', 'root', '');
$stmt = $pdo->query('SELECT id, player_id, name, email FROM users ORDER BY created_at DESC LIMIT 20');
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));

$nullPidStmt = $pdo->query("SELECT COUNT(*) FROM users WHERE player_id IS NULL OR player_id = ''");
echo "Users with NULL/empty player_id: " . $nullPidStmt->fetchColumn() . "\n";
