<?php
/**
 * Migration: Populate player_id for all users in questup_db
 */
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

$db = db();

echo "Running Player ID migration for questup_db...\n";

// Add player_id column if not exists
$db->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS player_id VARCHAR(32) NULL AFTER id");
$db->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_player_id ON users(player_id)");

$users = $db->query("SELECT id, name, email, player_id FROM users")->fetchAll(PDO::FETCH_ASSOC);

foreach ($users as $u) {
    $source = !empty($u['email']) ? $u['email'] : $u['id'];
    $hash = hash('sha256', $source);
    $num = (hexdec(substr($hash, 0, 4)) % 9000) + 1000;
    $tag = 'QST-' . $num;

    $stmt = $db->prepare("UPDATE users SET player_id = :tag WHERE id = :id");
    $stmt->execute(['tag' => $tag, 'id' => $u['id']]);
    echo "Assigned {$tag} to user '{$u['name']}' ({$u['email']})\n";
}

echo "Migration completed successfully!\n";
