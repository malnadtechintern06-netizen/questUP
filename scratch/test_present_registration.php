<?php
$payload = json_encode([
    'name' => 'Present Data Test',
    'email' => 'present.test@questup.app',
    'password' => 'TestPass123!',
    'avatar_key' => 'avatar_warrior',
    'coins' => 150
]);
$ch = curl_init('http://127.0.0.1/questUP/backend/api/auth/register.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
$resp = curl_exec($ch);
echo "REGISTER RESPONSE:\n" . $resp . "\n";

// Verify directly from MySQL
$pdo = new PDO('mysql:host=127.0.0.1;dbname=questup_db', 'root', '');
$stmt = $pdo->prepare('SELECT u.id, u.player_id, u.name, u.email, up.coins, up.joined_at, up.updated_at FROM users u JOIN user_profiles up ON u.id = up.user_id WHERE u.email = ?');
$stmt->execute(['present.test@questup.app']);
$row = $stmt->fetch(PDO::FETCH_ASSOC);
echo "\nDIRECT MYSQL VERIFICATION:\n";
print_r($row);
