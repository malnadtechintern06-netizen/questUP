<?php
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

echo "--- TOTAL USERS ---\n";
$stmt = $db->query('SELECT COUNT(*) FROM users');
echo "Count: " . $stmt->fetchColumn() . "\n\n";

echo "--- RECENT USERS ---\n";
$stmt = $db->query('SELECT u.id, u.player_id, u.name, u.email, up.name as profile_name, u.created_at FROM users u LEFT JOIN user_profiles up ON up.user_id = u.id ORDER BY u.created_at DESC LIMIT 20');
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($rows as $r) {
    echo "ID: {$r['id']} | Tag: {$r['player_id']} | Name: {$r['name']} | ProfileName: {$r['profile_name']} | Email: {$r['email']}\n";
}

echo "\n--- USERS WITH NULL OR EMPTY PLAYER_ID ---\n";
$stmt = $db->query("SELECT id, name, email, player_id FROM users WHERE player_id IS NULL OR player_id = ''");
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($rows as $r) {
    echo "ID: {$r['id']} | Tag: '{$r['player_id']}' | Name: {$r['name']} | Email: {$r['email']}\n";
}
