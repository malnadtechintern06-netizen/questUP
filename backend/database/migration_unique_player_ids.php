<?php
/**
 * Migration: Ensure every user in questup_db has a guaranteed unique Player ID
 */
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
$db = db();

echo "Running Unique Player ID Migration...\n";

// 1. Ensure player_id column exists
try {
    $db->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS player_id VARCHAR(32) NULL AFTER id");
} catch (Throwable $e) {
    echo "Column check: " . $e->getMessage() . "\n";
}

// 2. Fetch all users
$users = $db->query("SELECT id, name, email, player_id FROM users ORDER BY created_at ASC")->fetchAll(PDO::FETCH_ASSOC);

$usedTags = [];
$assignedCount = 0;

// Pass 1: Collect already valid unique tags
foreach ($users as $u) {
    $tag = trim((string)($u['player_id'] ?? ''));
    if (!empty($tag) && preg_match('/^QST-\d{4,6}$/', $tag)) {
        if (!isset($usedTags[$tag])) {
            $usedTags[$tag] = $u['id'];
        }
    }
}

// Pass 2: Assign unique tags to users with missing or duplicate tags
foreach ($users as $u) {
    $id = $u['id'];
    $tag = trim((string)($u['player_id'] ?? ''));

    // Needs new tag if empty, invalid format, or duplicate
    $needsTag = empty($tag) || !preg_match('/^QST-\d{4,6}$/', $tag) || ($usedTags[$tag] ?? null) !== $id;

    if ($needsTag) {
        // Try deterministic hash first
        $source = !empty($u['email']) ? $u['email'] : $id;
        $hash = hash('sha256', $source);
        $num = (hexdec(substr($hash, 0, 4)) % 9000) + 1000;
        $candidate = 'QST-' . $num;

        if (isset($usedTags[$candidate]) && $usedTags[$candidate] !== $id) {
            // Find next available tag
            $found = false;
            for ($k = 1000; $k <= 9999; $k++) {
                $test = 'QST-' . $k;
                if (!isset($usedTags[$test])) {
                    $candidate = $test;
                    $found = true;
                    break;
                }
            }
            if (!$found) {
                $candidate = 'QST-' . mt_rand(10000, 99999);
            }
        }

        $usedTags[$candidate] = $id;

        $stmt = $db->prepare("UPDATE users SET player_id = :tag WHERE id = :id");
        $stmt->execute(['tag' => $candidate, 'id' => $id]);
        $assignedCount++;
        echo "Assigned unique tag {$candidate} to '{$u['name']}' ({$u['email']})\n";
    }
}

// 3. Apply Unique Index
try {
    // Drop non-unique or duplicate index if existing
    $db->exec("ALTER TABLE users DROP INDEX IF EXISTS idx_users_player_id");
    $db->exec("ALTER TABLE users ADD UNIQUE INDEX idx_users_player_id (player_id)");
    echo "Successfully created UNIQUE index idx_users_player_id on users(player_id)!\n";
} catch (Throwable $e) {
    echo "Index notice: " . $e->getMessage() . "\n";
}

echo "Migration complete! {$assignedCount} users assigned unique tags.\n";
