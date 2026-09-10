<?php
require __DIR__ . '/../backend/config/database.php';
$db = db();

echo "--- ALL USERS WITH XP & LEVEL ---\n";
$stmt = $db->query("
    SELECT 
        u.id,
        u.player_id,
        u.name,
        COALESCE(up.name, u.name) AS display_name,
        COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
        COALESCE(up.level, 1) AS level,
        COALESCE(up.current_xp, 0) AS current_xp,
        (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS total_xp,
        (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_count
    FROM users u
    LEFT JOIN user_profiles up ON up.user_id = u.id
    ORDER BY total_xp DESC
");
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($users as $idx => $u) {
    echo "#" . ($idx + 1) . " [{$u['player_id']}] {$u['display_name']} (Lvl {$u['level']}, {$u['total_xp']} XP, {$u['completed_count']} Quests)\n";
}

echo "\n--- FRIEND REQUESTS (ACCEPTED) ---\n";
$fStmt = $db->query("SELECT * FROM friend_requests WHERE status = 'accepted'");
$fReqs = $fStmt->fetchAll(PDO::FETCH_ASSOC);
print_r($fReqs);
