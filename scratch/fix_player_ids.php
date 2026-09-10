<?php
/**
 * Migration: Ensure all users in questup_db have a valid, unique player_id (QST-XXXX)
 */
require_once __DIR__ . '/../backend/config/database.php';
$db = db();

echo "Running player_id integrity migration...\n";

// 1. Fetch all users
$stmt = $db->query("SELECT id, name, email, player_id FROM users");
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

$existingTags = [];
foreach ($users as $u) {
    $tag = trim((string)($u['player_id'] ?? ''));
    if ($tag !== '' && preg_match('/^QST-\d{4}$/', $tag)) {
        $existingTags[$tag] = true;
    }
}

$fixedCount = 0;
foreach ($users as $u) {
    $id = $u['id'];
    $tag = trim((string)($u['player_id'] ?? ''));
    $email = trim((string)($u['email'] ?? ''));
    $name = trim((string)($u['name'] ?? ''));

    if ($tag === '' || !preg_match('/^QST-\d{4}$/', $tag) || (isset($existingTags[$tag]) && $existingTags[$tag] > 1)) {
        // Generate a new unique player tag
        $hash = hash('sha256', $email ?: ($name . $id));
        $num = (hexdec(substr($hash, 0, 4)) % 9000) + 1000;
        $newTag = 'QST-' . $num;

        while (isset($existingTags[$newTag])) {
            $newTag = 'QST-' . mt_rand(1000, 9999);
        }

        $existingTags[$newTag] = 1;

        $upd = $db->prepare("UPDATE users SET player_id = :pid WHERE id = :id");
        $upd->execute(['pid' => $newTag, 'id' => $id]);
        $fixedCount++;
        echo "Assigned player_id {$newTag} to user {$name} ({$id})\n";
    }
}

echo "Migration finished. Total player_id fixed: {$fixedCount}\n";
