<?php
/**
 * Seed Featured / Community Players into MySQL users & user_profiles
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

$db = db();

$players = [
    [
        'id'        => 'comp_1',
        'player_id' => 'QST-1001',
        'name'      => 'Elena Shadowstride',
        'email'     => 'elena.shadowstride@questup.app',
        'avatar'    => 'avatar_mystic_sage',
        'level'     => 6,
        'xp'        => 3850,
        'coins'     => 1950,
    ],
    [
        'id'        => 'comp_2',
        'player_id' => 'QST-1002',
        'name'      => 'Kai Horizon',
        'email'     => 'kai.horizon@questup.app',
        'avatar'    => 'avatar_sky_pilot',
        'level'     => 5,
        'xp'        => 2900,
        'coins'     => 1400,
    ],
    [
        'id'        => 'comp_3',
        'player_id' => 'QST-1003',
        'name'      => 'Thorne Ironwood',
        'email'     => 'thorne.ironwood@questup.app',
        'avatar'    => 'avatar_cyber_knight',
        'level'     => 4,
        'xp'        => 2100,
        'coins'     => 980,
    ],
    [
        'id'        => 'comp_4',
        'player_id' => 'QST-1004',
        'name'      => 'Aria Silverleaf',
        'email'     => 'aria.silverleaf@questup.app',
        'avatar'    => 'avatar_ranger',
        'level'     => 3,
        'xp'        => 1400,
        'coins'     => 650,
    ],
    [
        'id'        => 'comp_5',
        'player_id' => 'QST-1005',
        'name'      => 'Vesper Nova',
        'email'     => 'vesper.nova@questup.app',
        'avatar'    => 'avatar_ranger',
        'level'     => 4,
        'xp'        => 2350,
        'coins'     => 1120,
    ],
];

foreach ($players as $p) {
    // 1. Insert into users
    $uStmt = $db->prepare("
        INSERT INTO users (id, player_id, name, email, password_hash, status)
        VALUES (:id, :pid, :name, :email, :pw, 'active')
        ON DUPLICATE KEY UPDATE 
            player_id = VALUES(player_id),
            name = VALUES(name),
            status = 'active'
    ");
    $uStmt->execute([
        'id'    => $p['id'],
        'pid'   => $p['player_id'],
        'name'  => $p['name'],
        'email' => $p['email'],
        'pw'    => password_hash('questup_explorer_pass', PASSWORD_BCRYPT),
    ]);

    // 2. Insert into user_profiles
    $pStmt = $db->prepare("
        INSERT INTO user_profiles (user_id, name, email, avatar_key, level, current_xp, xp_to_next_level, coins)
        VALUES (:uid, :name, :email, :avatar, :level, :xp, 500, :coins)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            avatar_key = VALUES(avatar_key),
            level = VALUES(level),
            current_xp = VALUES(current_xp),
            coins = VALUES(coins)
    ");
    $pStmt->execute([
        'uid'    => $p['id'],
        'name'   => $p['name'],
        'email'  => $p['email'],
        'avatar' => $p['avatar'],
        'level'  => $p['level'],
        'xp'     => $p['xp'],
        'coins'  => $p['coins'],
    ]);

    echo "Seeded {$p['player_id']} - {$p['name']}\n";
}

echo "ALL_SEEDED_SUCCESSFULLY\n";
