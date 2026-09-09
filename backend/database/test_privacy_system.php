<?php
/**
 * Test Harness: Zero-Trust Verification for Player ID & Friend History Privacy
 */
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

$db = db();

echo "=========================================================\n";
echo "Testing QuestUP Player ID & Friend Privacy System (PHP)\n";
echo "=========================================================\n";

function callEndpoint(string $endpoint, string $method, array $params): array {
    $phpExe = 'C:\\xampp\\php\\php.exe';
    $runner = __DIR__ . '/api_runner.php';
    @unlink(__DIR__ . '/last_response_code.txt');
    
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];
    $process = proc_open("\"$phpExe\" -d display_errors=off \"$runner\" \"$endpoint\" \"$method\"", $descriptors, $pipes);
    fwrite($pipes[0], json_encode($params));
    fclose($pipes[0]);
    $output = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    proc_close($process);

    $code = (int)@file_get_contents(__DIR__ . '/last_response_code.txt');
    $json = json_decode(trim((string)$output), true);
    return [
        'http_code' => $code > 0 ? $code : 200,
        'raw_output' => $output,
        'json' => $json,
    ];
}

// 1. Create or reset 3 distinct test players with unique Player IDs
$db->exec("DELETE FROM users WHERE email LIKE 'test_privacy_%@questup.com'");

$testUsers = [
    [
        'id'        => 'usr_priv_1',
        'player_id' => 'QST-2794',
        'name'      => 'Test Player One',
        'email'     => 'test_privacy_1@questup.com',
    ],
    [
        'id'        => 'usr_priv_2',
        'player_id' => 'QST-1409',
        'name'      => 'Test Player Two',
        'email'     => 'test_privacy_2@questup.com',
    ],
    [
        'id'        => 'usr_priv_3',
        'player_id' => 'QST-8888',
        'name'      => 'Test Player Three',
        'email'     => 'test_privacy_3@questup.com',
    ],
];

foreach ($testUsers as $u) {
    $db->prepare("DELETE FROM users WHERE player_id = :tag OR id = :id")->execute(['tag' => $u['player_id'], 'id' => $u['id']]);
    
    $ins = $db->prepare("
        INSERT INTO users (id, player_id, name, email, password_hash, salt, status, created_at)
        VALUES (:id, :player_id, :name, :email, 'hash', 'salt', 'active', NOW())
    ");
    $ins->execute([
        'id'        => $u['id'],
        'player_id' => $u['player_id'],
        'name'      => $u['name'],
        'email'     => $u['email'],
    ]);

    $insP = $db->prepare("
        INSERT INTO user_profiles (user_id, name, email, level, current_xp, coins)
        VALUES (:uid, :name, :email, 3, 500, 200)
        ON DUPLICATE KEY UPDATE name = :name2
    ");
    $insP->execute([
        'uid'   => $u['id'],
        'name'  => $u['name'],
        'email' => $u['email'],
        'name2' => $u['name'],
    ]);
}

// Fetch an existing quest ID from the database
$qRow = $db->query("SELECT id FROM quests LIMIT 1")->fetch();
$questId = $qRow ? $qRow['id'] : 'quest_1';

// Add completed quest for Player 2
$db->prepare("DELETE FROM quest_completions WHERE user_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3')")->execute();
$insQc = $db->prepare("
    INSERT INTO quest_completions (id, user_id, quest_id, status, xp_earned, coins_earned, completed_at)
    VALUES ('qc_test_p2', 'usr_priv_2', :qid, 'verified', 150, 75, NOW())
");
$insQc->execute(['qid' => $questId]);

// Clear any friend requests between test players
$db->exec("DELETE FROM friend_requests WHERE sender_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3') OR receiver_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3')");
$db->exec("DELETE FROM user_friends WHERE user_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3') OR friend_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3')");

echo "✅ Test accounts and sample quest completions initialized.\n";

// TEST 1: Requesting history without friendship (Status: NONE)
echo "\n--- TEST 1: History without friendship ---\n";
$res1 = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_1',
    'target_player_id' => 'QST-1409',
]);

if ($res1['http_code'] === 403 && ($res1['json']['error'] ?? '') === 'Players are not friends') {
    echo "✔ PASSED: Non-friend access was strictly BLOCKED with HTTP 403 Forbidden.\n";
} else {
    echo "❌ FAILED: Expected 403, got {$res1['http_code']}: {$res1['raw_output']}\n";
    exit(1);
}

// TEST 2: Send friend request (QST-2794 -> QST-1409)
echo "\n--- TEST 2: Send Friend Request ---\n";
$res2 = callEndpoint('friends/send_request.php', 'POST', [
    'sender_id' => 'usr_priv_1',
    'target_tag' => 'QST-1409',
]);

if ($res2['http_code'] === 200 && ($res2['json']['success'] ?? false) === true) {
    echo "✔ PASSED: Friend request sent successfully (status = pending).\n";
} else {
    echo "❌ FAILED: Could not send request: {$res2['raw_output']}\n";
    exit(1);
}

// TEST 3: History while PENDING (both directions)
echo "\n--- TEST 3: History while PENDING ---\n";
// QST-2794 -> QST-1409
$res3a = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_1',
    'target_player_id' => 'QST-1409',
]);

// QST-1409 -> QST-2794
$res3b = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_2',
    'target_player_id' => 'QST-2794',
]);

if ($res3a['http_code'] === 403 && $res3b['http_code'] === 403) {
    echo "✔ PASSED: Both players strictly BLOCKED with HTTP 403 while request is pending.\n";
} else {
    echo "❌ FAILED: Pending history should return 403. Got {$res3a['http_code']} and {$res3b['http_code']}\n";
    exit(1);
}

// TEST 4: Respond to Request -> ACCEPT
echo "\n--- TEST 4: Accept Friend Request ---\n";
// Retrieve request ID
$rStmt = $db->query("SELECT id FROM friend_requests WHERE sender_id = 'usr_priv_1' AND receiver_id = 'usr_priv_2' LIMIT 1");
$reqRow = $rStmt->fetch();
$requestId = $reqRow['id'];

$res4 = callEndpoint('friends/respond_request.php', 'POST', [
    'request_id' => $requestId,
    'action' => 'accept',
    'user_id' => 'usr_priv_2',
]);

if ($res4['http_code'] === 200 && ($res4['json']['success'] ?? false) === true) {
    echo "✔ PASSED: Friend request accepted.\n";
} else {
    echo "❌ FAILED: Accept request failed: {$res4['raw_output']}\n";
    exit(1);
}

// TEST 5: History after ACCEPT (both directions unlocked!)
echo "\n--- TEST 5: History after ACCEPT ---\n";
// QST-2794 -> QST-1409
$res5a = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_1',
    'target_player_id' => 'QST-1409',
]);

// QST-1409 -> QST-2794
$res5b = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_2',
    'target_player_id' => 'QST-2794',
]);

if ($res5a['http_code'] === 200 && ($res5a['json']['success'] ?? false) === true && !empty($res5a['json']['history']) &&
    $res5b['http_code'] === 200 && ($res5b['json']['success'] ?? false) === true) {
    echo "✔ PASSED: Mutual accepted friends can view verified quest history in BOTH directions.\n";
    echo "   Quest completed: " . $res5a['json']['history'][0]['title'] . " (XP: " . $res5a['json']['history'][0]['xp_earned'] . ")\n";
} else {
    echo "❌ FAILED: Accepted friends history call failed. 5a: {$res5a['http_code']} {$res5a['raw_output']}, 5b: {$res5b['http_code']} {$res5b['raw_output']}\n";
    exit(1);
}

// TEST 6: 3rd Player (QST-8888) is strictly BLOCKED
echo "\n--- TEST 6: 3rd Party Player Access ---\n";
$res6 = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_3',
    'target_player_id' => 'QST-1409',
]);

if ($res6['http_code'] === 403) {
    echo "✔ PASSED: Non-friend 3rd player QST-8888 strictly BLOCKED with HTTP 403.\n";
} else {
    echo "❌ FAILED: 3rd player should be 403, got {$res6['http_code']}: {$res6['raw_output']}\n";
    exit(1);
}

// TEST 7: Remove friend relationship
echo "\n--- TEST 7: Remove Friend from Squad ---\n";
$res7 = callEndpoint('friends/remove_friend.php', 'POST', [
    'user_id' => 'usr_priv_1',
    'friend_user_id' => 'usr_priv_2',
]);

// Try viewing history again -> must be 403 blocked again!
$res7History = callEndpoint('friends/history.php', 'GET', [
    'user_id' => 'usr_priv_1',
    'target_player_id' => 'QST-1409',
]);

if ($res7History['http_code'] === 403) {
    echo "✔ PASSED: After removal, history is immediately RE-LOCKED with HTTP 403.\n";
} else {
    echo "❌ FAILED: Expected 403 after friend removal, got {$res7History['http_code']}\n";
    exit(1);
}

// Clean up
$db->exec("DELETE FROM users WHERE email LIKE 'test_privacy_%@questup.com'");
$db->exec("DELETE FROM friend_requests WHERE sender_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3') OR receiver_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3')");
$db->exec("DELETE FROM user_friends WHERE user_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3') OR friend_id IN ('usr_priv_1', 'usr_priv_2', 'usr_priv_3')");

echo "\n=========================================================\n";
echo "ALL ZERO-TRUST PRIVACY TESTS PASSED ON REAL BACKEND! 🚀\n";
echo "=========================================================\n";
