<?php
require __DIR__ . '/../backend/config/database.php';
$db = db();

$start = microtime(true);
$sql = "
SELECT 
  u.id AS user_id,
  COALESCE(u.player_id, 'QST-0000') AS player_id,
  u.name AS username,
  COALESCE(up.name, u.name) AS display_name,
  COALESCE(up.avatar_key, 'avatar_ranger') AS avatar_key,
  COALESCE(up.level, 1) AS level,
  (COALESCE(up.current_xp, 0) + (COALESCE(up.level, 1) - 1) * 500) AS total_xp,
  (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id AND status = 'verified') AS completed_quests_count
FROM users u
LEFT JOIN user_profiles up ON up.user_id = u.id
ORDER BY total_xp DESC, completed_quests_count DESC, u.created_at ASC
LIMIT 50";
$stmt = $db->query($sql);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
$end = microtime(true);

echo "Query time: " . round(($end - $start) * 1000, 2) . " ms. Rows: " . count($rows) . "\n";
