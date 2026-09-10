<?php
$pdo = new PDO('mysql:host=127.0.0.1;dbname=questup_db', 'root', '');
$stmt = $pdo->query('SELECT user_id, name, email, level, current_xp, coins, joined_at, updated_at FROM user_profiles ORDER BY joined_at DESC LIMIT 15');
foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
    echo "{$r['joined_at']} | {$r['user_id']} | {$r['name']} | {$r['email']} | lvl:{$r['level']} | xp:{$r['current_xp']} | coins:{$r['coins']}\n";
}
