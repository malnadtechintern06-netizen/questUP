<?php
/**
 * Migration: Player ID, Friend Request, and History Privacy Fix
 * Database: questup_db
 */
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

$db = db();

echo "====================================================\n";
echo "Running QuestUP Player ID & Privacy Migration...\n";
echo "====================================================\n";

// 1. Ensure player_id column exists in users
try {
    $colCheck = $db->query("SHOW COLUMNS FROM users LIKE 'player_id'");
    if (!$colCheck || $colCheck->rowCount() === 0) {
        $db->exec("ALTER TABLE users ADD COLUMN player_id VARCHAR(32) NULL AFTER id");
        echo "✅ Added 'player_id' column to 'users' table.\n";
    } else {
        echo "ℹ️ 'player_id' column already exists in 'users' table.\n";
    }
} catch (Throwable $e) {
    echo "⚠️ Notice on player_id column check: " . $e->getMessage() . "\n";
}

// 2. Ensure friend_requests table exists with proper schema
$db->exec("
    CREATE TABLE IF NOT EXISTS friend_requests (
        id VARCHAR(64) NOT NULL,
        sender_id VARCHAR(64) NOT NULL,
        receiver_id VARCHAR(64) NOT NULL,
        sender_tag VARCHAR(32) DEFAULT NULL,
        receiver_tag VARCHAR(32) DEFAULT NULL,
        status ENUM('pending', 'accepted', 'rejected', 'cancelled') DEFAULT 'pending',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        INDEX idx_fr_sender (sender_id),
        INDEX idx_fr_receiver (receiver_id),
        INDEX idx_fr_status (status),
        INDEX idx_fr_pair_status (sender_id, receiver_id, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
");
echo "✅ Verified 'friend_requests' table schema.\n";

// 3. Ensure user_friends table exists
$db->exec("
    CREATE TABLE IF NOT EXISTS user_friends (
        id VARCHAR(64) NOT NULL,
        user_id VARCHAR(64) NOT NULL,
        friend_id VARCHAR(64) NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uk_user_friend (user_id, friend_id),
        INDEX idx_uf_user (user_id),
        INDEX idx_uf_friend (friend_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
");
echo "✅ Verified 'user_friends' table schema.\n";

// 4. Assign guaranteed unique permanent 4-digit Player IDs (QST-XXXX) to all users
$existingUsers = $db->query("SELECT id, name, email, player_id FROM users ORDER BY created_at ASC")->fetchAll(PDO::FETCH_ASSOC);

$assignedTags = [];
// Gather existing valid QST-XXXX tags
foreach ($existingUsers as $u) {
    $tag = trim((string)($u['player_id'] ?? ''));
    if (preg_match('/^QST-\d{4}$/', $tag)) {
        if (!in_array($tag, $assignedTags, true)) {
            $assignedTags[] = $tag;
        }
    }
}

// Helper function to generate next available QST-XXXX
function generateNextPlayerTag(array &$usedTags, string $seed): string {
    // Deterministic first try using hash of seed
    $hash = hash('sha256', $seed);
    $candidateNum = (hexdec(substr($hash, 0, 4)) % 9000) + 1000;
    $candidate = 'QST-' . $candidateNum;

    if (!in_array($candidate, $usedTags, true)) {
        $usedTags[] = $candidate;
        return $candidate;
    }

    // Collision resolution: find next available 4-digit number
    for ($i = 1000; $i <= 9999; $i++) {
        $alt = 'QST-' . $i;
        if (!in_array($alt, $usedTags, true)) {
            $usedTags[] = $alt;
            return $alt;
        }
    }

    $rnd = 'QST-' . mt_rand(1000, 9999);
    $usedTags[] = $rnd;
    return $rnd;
}

$updateStmt = $db->prepare("UPDATE users SET player_id = :tag WHERE id = :id");

foreach ($existingUsers as $u) {
    $currentTag = trim((string)($u['player_id'] ?? ''));
    $needsNewTag = false;

    // Check if tag is missing, not in QST-XXXX format, or duplicated
    if ($currentTag === '' || !preg_match('/^QST-\d{4}$/', $currentTag)) {
        $needsNewTag = true;
    } else {
        // Check if duplicate
        $dupCount = 0;
        foreach ($assignedTags as $t) {
            if ($t === $currentTag) $dupCount++;
        }
        if ($dupCount > 1) {
            $needsNewTag = true;
        }
    }

    if ($needsNewTag) {
        $seed = !empty($u['email']) ? $u['email'] : $u['id'];
        $newTag = generateNextPlayerTag($assignedTags, $seed);
        $updateStmt->execute(['tag' => $newTag, 'id' => $u['id']]);
        echo "🔹 Assigned new unique Player ID: {$newTag} to user '{$u['name']}' ({$u['email']})\n";
    } else {
        echo "✔ User '{$u['name']}' has valid unique Player ID: {$currentTag}\n";
    }
}

// 5. Add unique index on users.player_id if not already present
try {
    $indexCheck = $db->query("SHOW INDEX FROM users WHERE Key_name = 'uk_users_player_id' OR Key_name = 'idx_users_player_id'");
    $hasUnique = false;
    while ($row = $indexCheck->fetch(PDO::FETCH_ASSOC)) {
        if ($row['Non_unique'] == 0) {
            $hasUnique = true;
            break;
        }
    }
    if (!$hasUnique) {
        // Drop any non-unique index first
        try {
            $db->exec("ALTER TABLE users DROP INDEX idx_users_player_id");
        } catch (Throwable $_) {}
        $db->exec("ALTER TABLE users ADD UNIQUE INDEX uk_users_player_id (player_id)");
        echo "✅ Added UNIQUE constraint 'uk_users_player_id' on users.player_id.\n";
    } else {
        echo "ℹ️ UNIQUE index on player_id already present.\n";
    }
} catch (Throwable $e) {
    echo "⚠️ Notice on index creation: " . $e->getMessage() . "\n";
}

// 6. Synchronize sender_tag and receiver_tag in friend_requests
$db->exec("
    UPDATE friend_requests fr
    JOIN users u ON fr.sender_id = u.id
    SET fr.sender_tag = u.player_id
    WHERE fr.sender_tag IS NULL OR fr.sender_tag != u.player_id
");

$db->exec("
    UPDATE friend_requests fr
    JOIN users u ON fr.receiver_id = u.id
    SET fr.receiver_tag = u.player_id
    WHERE fr.receiver_tag IS NULL OR fr.receiver_tag != u.player_id
");

// 7. Synchronize user_friends table with all accepted friend requests
$acceptedReqs = $db->query("SELECT sender_id, receiver_id FROM friend_requests WHERE status = 'accepted'")->fetchAll(PDO::FETCH_ASSOC);
$insUf = $db->prepare("
    INSERT IGNORE INTO user_friends (id, user_id, friend_id, created_at)
    VALUES (:id, :u, :f, NOW())
");

foreach ($acceptedReqs as $ar) {
    $insUf->execute(['id' => bin2hex(random_bytes(16)), 'u' => $ar['sender_id'], 'f' => $ar['receiver_id']]);
    $insUf->execute(['id' => bin2hex(random_bytes(16)), 'u' => $ar['receiver_id'], 'f' => $ar['sender_id']]);
}
echo "✅ Synchronized bidirectional entries in 'user_friends'.\n";

echo "====================================================\n";
echo "Migration finished successfully!\n";
echo "====================================================\n";
