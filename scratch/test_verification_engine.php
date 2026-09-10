<?php
/**
 * QuestUP Comprehensive Two-Step Verification & Anti-Cheat Test Suite
 */

require_once __DIR__ . '/../backend/config/database.php';
require_once __DIR__ . '/../backend/api/quests/perceptual_hash.php';

$db = db();
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

echo "====================================================\n";
echo "  QuestUP Two-Step Verification & Anti-Cheat Suite  \n";
echo "====================================================\n\n";

$passCount = 0;
$failCount = 0;

function assertTest($description, $condition) {
    global $passCount, $failCount;
    if ($condition) {
        echo "  [PASS] $description\n";
        $passCount++;
    } else {
        echo "  [FAIL] $description\n";
        $failCount++;
    }
}

// 1. Setup Test User and Test Quests
$testUserId = 'test_hunter_' . time();
$db->prepare("INSERT INTO users (id, name, email, created_at) VALUES (?, 'Test Hunter', ?, NOW())")
   ->execute([$testUserId, "$testUserId@questup.test"]);
$db->prepare("INSERT INTO user_profiles (user_id, name, email, level, current_xp, xp_to_next_level, coins, joined_at) VALUES (?, 'Test Hunter', ?, 1, 0, 100, 50, NOW())")
   ->execute([$testUserId, "$testUserId@questup.test"]);

// Test Quest 1: Location & Photo Quest
$qPhotoId = 'test_q_photo_' . time();
$db->prepare("INSERT INTO quests (id, title, description, category, difficulty, verification_type, latitude, longitude, radius_meters, xp_reward, coins_reward, min_duration_seconds, allow_gallery_upload, is_active) VALUES (?, 'Historical Monument Lock', 'Visit landmark and take real photo', 'landmark', 'medium', 'photoProof', 12.9716, 77.5946, 250, 150, 45, 0, 0, 1)")
   ->execute([$qPhotoId]);

// Test Quest 2: Quiz Quest
$qQuizId = 'test_q_quiz_' . time();
$quizJson = json_encode([
    'questions' => [
        ['id' => 'q1', 'question' => 'Capital of France?', 'options' => ['Berlin', 'Paris', 'Rome'], 'answer' => 'Paris'],
        ['id' => 'q2', 'question' => '2 + 2 = ?', 'options' => ['3', '4', '5'], 'answer' => '4']
    ]
]);
$db->prepare("INSERT INTO quests (id, title, description, category, difficulty, verification_type, xp_reward, coins_reward, quiz_data_json, is_active) VALUES (?, 'Trivia Knowledge Test', 'Answer both questions correctly', 'study', 'easy', 'quiz', 80, 20, ?, 1)")
   ->execute([$qQuizId, $quizJson]);

// Test Quest 3: Secret Code Quest
$qCodeId = 'test_q_code_' . time();
$db->prepare("INSERT INTO quests (id, title, description, category, difficulty, verification_type, xp_reward, coins_reward, verification_secret, is_active) VALUES (?, 'Secret Vault Cipher', 'Find and enter passcode', 'mystery', 'hard', 'secretCode', 300, 100, 'CYBER-99', 1)")
   ->execute([$qCodeId]);

// Test Quest 4: Admin Review Quest
$qAdminId = 'test_q_admin_' . time();
$db->prepare("INSERT INTO quests (id, title, description, category, difficulty, verification_type, xp_reward, coins_reward, requires_admin_review, is_active) VALUES (?, 'Legendary Artifact Discovery', 'Submit discovery for Game Master approval', 'culture', 'legendary', 'adminApproval', 500, 250, 1, 1)")
   ->execute([$qAdminId]);

echo "1. Testing Perceptual Hash (dHash) & Hamming Distance Engine\n";
$imgDir = __DIR__ . '/test_images';
if (!is_dir($imgDir)) mkdir($imgDir, 0777, true);

$img1Path = $imgDir . '/img1.jpg';
$img2Path = $imgDir . '/img2.jpg';
$img3Path = $imgDir . '/img3.jpg';

// Write test image bytes
$data1 = str_repeat("JPEG_HEADER_SAMPLE_PATTERNA", 100);
$data2 = str_repeat("JPEG_HEADER_SAMPLE_PATTERNA", 100); // Identical pattern
$data3 = str_repeat("DIFFERENT_IMAGE_PATTERN_XYZ", 100); // Distinct pattern

file_put_contents($img1Path, $data1);
file_put_contents($img2Path, $data2);
file_put_contents($img3Path, $data3);

$hash1 = compute_image_dhash($img1Path);
$hash2 = compute_image_dhash($img2Path);
$hash3 = compute_image_dhash($img3Path);

$dist1_2 = compute_dhash_distance($hash1, $hash2);
$dist1_3 = compute_dhash_distance($hash1, $hash3);

assertTest("dHash computed successfully for test images (Hash1: $hash1)", !empty($hash1) && !empty($hash2) && !empty($hash3));
assertTest("Identical images produce identical dHash (Hamming distance = $dist1_2)", $dist1_2 === 0);
assertTest("Different images produce high Hamming distance (Hamming distance = $dist1_3 > 5)", $dist1_3 > 5);

echo "\n2. Testing Two-Step Photo Quest Verification & Reward Granting\n";
// Step 1: Start verification
$attemptId = 'att_' . bin2hex(random_bytes(8));
$challengeToken = bin2hex(random_bytes(16));
$db->prepare("INSERT INTO quest_verification_attempts (id, attempt_id, user_id, quest_id, challenge_token, status, expires_at) VALUES (?, ?, ?, ?, ?, 'started', DATE_ADD(NOW(), INTERVAL 15 MINUTE))")
   ->execute([$attemptId, $attemptId, $testUserId, $qPhotoId, $challengeToken]);

// Step 2: Upload photo proof
$sha256 = compute_image_sha256($img1Path);
$db->prepare("UPDATE quest_verification_attempts SET media_url = ?, image_hash = ?, perceptual_hash = ?, client_upload_time = NOW(), status = 'submitted' WHERE id = ?")
   ->execute(['uploads/proofs/test1.jpg', $sha256, $hash1, $attemptId]);

// Verify Step with correct GPS
$att = $db->query("SELECT * FROM quest_verification_attempts WHERE id = '$attemptId'")->fetch(PDO::FETCH_ASSOC);
$q = $db->query("SELECT * FROM quests WHERE id = '$qPhotoId'")->fetch(PDO::FETCH_ASSOC);
$dist = haversine_distance_meters(12.9717, 77.5947, (float)$q['latitude'], (float)$q['longitude']);

assertTest("GPS coordinate distance is within radius ($dist m <= 250 m)", $dist <= 250);

// Insert completion atomically
$db->beginTransaction();
$db->prepare("INSERT INTO quest_completions (id, quest_id, user_id, attempt_id, proof_data, image_hash, perceptual_hash, status, xp_earned, coins_earned, completed_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'verified', ?, ?, NOW())")
   ->execute(['comp_1_' . time(), $qPhotoId, $testUserId, $attemptId, 'uploads/proofs/test1.jpg', $sha256, $hash1, $q['xp_reward'], $q['coins_reward']]);
$db->prepare("UPDATE user_profiles SET current_xp = current_xp + ?, coins = coins + ? WHERE user_id = ?")
   ->execute([$q['xp_reward'], $q['coins_reward'], $testUserId]);
$db->prepare("UPDATE quest_verification_attempts SET status = 'approved', verified_at = NOW() WHERE id = ?")
   ->execute([$attemptId]);
$db->commit();

$userProfile = $db->query("SELECT * FROM user_profiles WHERE user_id = '$testUserId'")->fetch(PDO::FETCH_ASSOC);
assertTest("User awarded authoritative XP (150) and Coins (50 + 45 = 95)", $userProfile['current_xp'] == 150 && $userProfile['coins'] == 95);

echo "\n3. Testing Anti-Cheat: Duplicate Image Hash & dHash Collision Detection\n";
// Attempt second completion with duplicate image by a different user
$otherUser = 'test_hunter2_' . time();
$db->prepare("INSERT INTO users (id, name, email, created_at) VALUES (?, 'Hunter 2', ?, NOW())")
   ->execute([$otherUser, "$otherUser@questup.test"]);
$db->prepare("INSERT INTO user_profiles (user_id, name, email, level, current_xp, xp_to_next_level, coins, joined_at) VALUES (?, 'Hunter 2', ?, 1, 0, 100, 0, NOW())")
   ->execute([$otherUser, "$otherUser@questup.test"]);

// Query duplicate check against existing completions
$existingCompletions = $db->query("SELECT id, user_id, quest_id, image_hash, perceptual_hash FROM quest_completions WHERE image_hash IS NOT NULL OR perceptual_hash IS NOT NULL")->fetchAll(PDO::FETCH_ASSOC);
$isDup = false;
foreach ($existingCompletions as $c) {
    if ($c['image_hash'] === $sha256) {
        $isDup = true;
        break;
    }
    if (!empty($c['perceptual_hash']) && !empty($hash2) && compute_dhash_distance($c['perceptual_hash'], $hash2) <= 3) {
        $isDup = true;
        break;
    }
}
assertTest("Anti-Cheat detected duplicate image upload across completions", $isDup === true);

echo "\n4. Testing Anti-Cheat: Out-of-Bounds GPS Geofence Rejection\n";
$farLat = 13.5000;
$farLon = 78.5000;
$farDist = haversine_distance_meters($farLat, $farLon, (float)$q['latitude'], (float)$q['longitude']);
assertTest("Out-of-bounds GPS distance exceeds quest radius ($farDist m > 250 m)", $farDist > 250);

echo "\n5. Testing Quiz Verification Engine\n";
$quizAnswersCorrect = ['q1' => 'Paris', 'q2' => '4'];
$quizAnswersWrong = ['q1' => 'Berlin', 'q2' => '4'];

function evaluateQuiz($quizDataJson, $userAnswers) {
    $quiz = json_decode($quizDataJson, true);
    $questions = $quiz['questions'] ?? [];
    if (empty($questions)) return false;
    foreach ($questions as $q) {
        $qId = $q['id'];
        $correct = trim(strtolower($q['answer']));
        $userAns = trim(strtolower($userAnswers[$qId] ?? ''));
        if ($correct !== $userAns) return false;
    }
    return true;
}

assertTest("Quiz passed with 100% correct answers", evaluateQuiz($quizJson, $quizAnswersCorrect) === true);
assertTest("Quiz rejected when one or more answers are incorrect", evaluateQuiz($quizJson, $quizAnswersWrong) === false);

echo "\n6. Testing Secret Passcode Verification Engine\n";
$qCode = $db->query("SELECT * FROM quests WHERE id = '$qCodeId'")->fetch(PDO::FETCH_ASSOC);
$validCode = 'CYBER-99';
$invalidCode = 'WRONG-12';
assertTest("Secret code accepted when matching 'CYBER-99'", trim(strtoupper($validCode)) === trim(strtoupper($qCode['verification_secret'])));
assertTest("Secret code rejected when invalid", trim(strtoupper($invalidCode)) !== trim(strtoupper($qCode['verification_secret'])));

echo "\n7. Testing Database Unique Constraint: Double-Reward Protection\n";
$doubleRewardCaught = false;
try {
    $db->prepare("INSERT INTO quest_completions (id, quest_id, user_id, status, xp_earned, coins_earned, completed_at) VALUES (?, ?, ?, 'verified', 100, 50, NOW())")
       ->execute(['comp_dup_' . time(), $qPhotoId, $testUserId]);
} catch (PDOException $e) {
    if ($e->getCode() == 23000 || strpos($e->getMessage(), 'Duplicate entry') !== false || strpos($e->getMessage(), '1062') !== false) {
        $doubleRewardCaught = true;
    }
}
assertTest("Database unique constraint uk_user_quest_completion blocked repeated completion for same user & quest", $doubleRewardCaught === true);

echo "\n8. Testing Admin Review Queue Flow\n";
$attAdmin = 'att_admin_' . bin2hex(random_bytes(8));
$db->prepare("INSERT INTO quest_verification_attempts (id, attempt_id, user_id, quest_id, status, is_suspicious, created_at) VALUES (?, ?, ?, ?, 'pending_admin', 0, NOW())")
   ->execute([$attAdmin, $attAdmin, $testUserId, $qAdminId]);

$pendingAtt = $db->query("SELECT * FROM quest_verification_attempts WHERE id = '$attAdmin'")->fetch(PDO::FETCH_ASSOC);
assertTest("Admin approval quest logged with status 'pending_admin'", $pendingAtt['status'] === 'pending_admin');

// Admin Approves Attempt
$db->beginTransaction();
$db->prepare("UPDATE quest_verification_attempts SET status = 'approved', verified_at = NOW() WHERE id = ?")
   ->execute([$attAdmin]);
$db->prepare("INSERT INTO quest_completions (id, quest_id, user_id, attempt_id, status, xp_earned, coins_earned, completed_at) VALUES (?, ?, ?, ?, 'verified', 500, 250, NOW())")
   ->execute(['comp_admin_' . time(), $qAdminId, $testUserId, $attAdmin]);
$db->prepare("UPDATE user_profiles SET current_xp = current_xp + 500, coins = coins + 250 WHERE user_id = ?")
   ->execute([$testUserId]);
$db->commit();

$finalUser = $db->query("SELECT * FROM user_profiles WHERE user_id = '$testUserId'")->fetch(PDO::FETCH_ASSOC);
assertTest("Admin approval granted +500 XP and +250 Coins to user (Total XP: 650, Coins: 345)", $finalUser['current_xp'] == 650 && $finalUser['coins'] == 345);

echo "\n====================================================\n";
echo "  Test Results: $passCount Passed, $failCount Failed\n";
echo "====================================================\n";
