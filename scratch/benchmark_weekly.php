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
  COALESCE((SELECT SUM(qc.xp_earned) FROM quest_completions qc WHERE qc.user_id = u.id AND qc.status = 'verified' AND qc.completed_at >= (NOW() - INTERVAL 7 DAY)), 0) AS verified_weekly_xp,
  (SELECT COUNT(*) FROM quest_completions qc WHERE qc.user_id = u.id AND qc.status = 'verified' AND qc.completed_at >= (NOW() - INTERVAL 7 DAY)) AS weekly_completed_count
FROM users u
LEFT JOIN user_profiles up ON up.user_id = u.id
ORDER BY total_xp DESC
LIMIT 50";
$stmt = $db->query($sql);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
$end = microtime(true);

echo "Weekly query time: " . round(($end - $start) * 1000, 2) . " ms. Rows: " . count($rows) . "\n";
