<?php
/**
 * QuestUP REST API - Server-Authoritative Two-Step Verification & Anti-Cheat Engine
 * Endpoint: POST /api/quests/verify.php and /api/quests/complete.php
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/activity_logger.php';
require_once __DIR__ . '/perceptual_hash.php';

$rawBody = file_get_contents('php://input');
$data = json_decode($rawBody, true) ?? $_POST;

$attemptId = trim($data['attempt_id'] ?? '');
$challengeToken = trim($data['challenge_token'] ?? '');
$questId = trim($data['quest_id'] ?? '');
$userId = trim($data['user_id'] ?? '');
$proofPayload = $data['proof_payload'] ?? $data['proof_data'] ?? [];
if (is_string($proofPayload)) {
    $decoded = json_decode($proofPayload, true);
    $proofPayload = is_array($decoded) ? $decoded : ['raw' => $proofPayload];
}

$userLat = isset($data['latitude']) ? (float)$data['latitude'] : (isset($proofPayload['latitude']) ? (float)$proofPayload['latitude'] : null);
$userLon = isset($data['longitude']) ? (float)$data['longitude'] : (isset($proofPayload['longitude']) ? (float)$proofPayload['longitude'] : null);
$deviceId = trim($data['device_id'] ?? ($proofPayload['device_id'] ?? ''));

if (empty($questId) || empty($userId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'quest_id and user_id are required.',
    ]);
    exit;
}

$db = db();

try {
    // ==========================================
    // 1. AUTHENTICATE USER
    // ==========================================
    $userStmt = $db->prepare("SELECT id, name, email, status FROM users WHERE id = :uid LIMIT 1");
    $userStmt->execute(['uid' => $userId]);
    $user = $userStmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Authentication failed: User does not exist.']);
        exit;
    }

    if (($user['status'] ?? 'active') === 'banned') {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Account is suspended.']);
        exit;
    }

    // ==========================================
    // 2. FETCH QUEST AUTHORITATIVELY
    // ==========================================
    $qStmt = $db->prepare("SELECT * FROM quests WHERE id = :qid LIMIT 1");
    $qStmt->execute(['qid' => $questId]);
    $quest = $qStmt->fetch();

    if (!$quest) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Quest not found on server.']);
        exit;
    }

    if ((int)($quest['is_active'] ?? 1) !== 1) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Quest is not active.']);
        exit;
    }

    $verificationType = $quest['verification_type'] ?? 'locationGps';
    $serverXpReward = max(0, (int)($quest['xp_reward'] ?? 100));
    $serverCoinsReward = max(0, (int)($quest['coins_reward'] ?? 50));

    // ==========================================
    // 3. DUPLICATE COMPLETION GUARD
    // ==========================================
    $dupStmt = $db->prepare("SELECT id, status, completed_at FROM quest_completions WHERE quest_id = :qid AND user_id = :uid LIMIT 1");
    $dupStmt->execute(['qid' => $questId, 'uid' => $userId]);
    $existingCompletion = $dupStmt->fetch();

    if ($existingCompletion) {
        echo json_encode([
            'success' => false,
            'is_duplicate' => true,
            'message' => 'Quest already completed by explorer. Duplicate rewards are prohibited.',
            'completion_status' => $existingCompletion['status'],
        ]);
        exit;
    }

    // ==========================================
    // 4. VERIFICATION ATTEMPT & CHALLENGE VALIDATION
    // ==========================================
    $attempt = null;
    if (!empty($attemptId)) {
        $attStmt = $db->prepare("SELECT * FROM quest_verification_attempts WHERE attempt_id = :aid AND user_id = :uid LIMIT 1");
        $attStmt->execute(['aid' => $attemptId, 'uid' => $userId]);
        $attempt = $attStmt->fetch();
    }

    // If no attempt provided, find the most recent unexpired attempt for this quest and user
    if (!$attempt) {
        $recentAttStmt = $db->prepare("
            SELECT * FROM quest_verification_attempts 
            WHERE quest_id = :qid AND user_id = :uid AND status IN ('started', 'submitted') AND expires_at > NOW()
            ORDER BY created_at DESC LIMIT 1
        ");
        $recentAttStmt->execute(['qid' => $questId, 'uid' => $userId]);
        $attempt = $recentAttStmt->fetch();
    }

    // If still no attempt, create a transparent in-line challenge attempt for direct requests
    if (!$attempt) {
        $newAttemptId = 'att_' . bin2hex(random_bytes(16));
        $newChallenge = bin2hex(random_bytes(32));
        $db->prepare("
            INSERT INTO quest_verification_attempts (
                id, attempt_id, user_id, quest_id, verification_type,
                challenge_token, device_id, status, started_at, expires_at, created_at
            ) VALUES (
                :id, :aid, :uid, :qid, :vtype,
                :token, :dev, 'started', NOW(), NOW() + INTERVAL 15 MINUTE, NOW()
            )
        ")->execute([
            'id' => 'rec_' . bin2hex(random_bytes(16)),
            'aid' => $newAttemptId,
            'uid' => $userId,
            'qid' => $questId,
            'vtype' => $verificationType,
            'token' => $newChallenge,
            'dev' => $deviceId ?: null,
        ]);

        $attemptStmt = $db->prepare("SELECT * FROM quest_verification_attempts WHERE attempt_id = :aid LIMIT 1");
        $attemptStmt->execute(['aid' => $newAttemptId]);
        $attempt = $attemptStmt->fetch();
    }

    $attemptId = $attempt['attempt_id'];

    // Check challenge token match if supplied
    if (!empty($challengeToken) && !empty($attempt['challenge_token'])) {
        if (!hash_equals($attempt['challenge_token'], $challengeToken)) {
            http_response_code(403);
            echo json_encode([
                'success' => false,
                'message' => 'Security challenge validation failed (Invalid token).',
            ]);
            exit;
        }
    }

    // Check expiration
    if (strtotime($attempt['expires_at']) < time()) {
        $db->prepare("UPDATE quest_verification_attempts SET status = 'rejected', failure_reason = 'Challenge expired before completion' WHERE attempt_id = :aid")
           ->execute(['aid' => $attemptId]);

        echo json_encode([
            'success' => false,
            'message' => 'Verification attempt expired. Please restart the quest verification.',
        ]);
        exit;
    }

    // Check if already approved/consumed
    if (($attempt['status'] ?? '') === 'approved') {
        echo json_encode([
            'success' => false,
            'message' => 'Verification attempt has already been completed and consumed.',
        ]);
        exit;
    }

    // ==========================================
    // 5. TWO-STEP VERIFICATION & ANTI-CHEAT CHECKS
    // ==========================================
    $step1Passed = true;
    $step2Passed = true;
    $failureReasons = [];
    $isSuspicious = 0;
    $suspiciousReasons = [];
    $requiresAdminApproval = (int)($quest['requires_admin_review'] ?? 0) === 1 || ($verificationType === 'admin' || $verificationType === 'adminApproval');
    $locationResultStr = null;
    $analysisResultStr = null;
    $imgHash = $attempt['image_hash'] ?? null;
    $pHash = $attempt['perceptual_hash'] ?? null;

    // --- STEP 1: PROOF VALIDATION BY TYPE ---
    switch ($verificationType) {
        case 'location':
        case 'locationGps':
        case 'walking':
        case 'walkingGps':
            $qLat = (float)($quest['latitude'] ?? 0.0);
            $qLon = (float)($quest['longitude'] ?? 0.0);
            $allowedRadius = (float)($quest['radius_meters'] ?? 150.0);

            if ($userLat === null || $userLon === null) {
                $step1Passed = false;
                $failureReasons[] = 'Real-time GPS coordinates are required for location verification.';
                $locationResultStr = 'Missing GPS coordinates';
            } else {
                $distance = haversine_distance_meters($userLat, $userLon, $qLat, $qLon);
                $locationResultStr = sprintf("Distance: %.1fm (Target: %s, Max Radius: %.1fm)", $distance, $quest['location_name'], $allowedRadius);

                if ($distance > $allowedRadius) {
                    $step1Passed = false;
                    $failureReasons[] = sprintf("Location check failed: You are %.0fm away from \"%s\" (must be within %.0fm).", $distance, $quest['location_name'], $allowedRadius);
                }
            }
            break;

        case 'photo':
        case 'photoProof':
            $mediaUrl = $attempt['media_url'] ?? ($proofPayload['media_url'] ?? ($proofPayload['photo_url'] ?? ''));
            if (empty($mediaUrl)) {
                $step1Passed = false;
                $failureReasons[] = 'In-app camera photo proof is required. Please capture a live photo.';
            } else {
                $fullImgPath = __DIR__ . '/../../' . ltrim($mediaUrl, '/\\');
                if (file_exists($fullImgPath)) {
                    if (empty($imgHash)) {
                        $imgHash = compute_image_sha256($fullImgPath);
                    }
                    if (empty($pHash)) {
                        $pHash = compute_image_dhash($fullImgPath);
                    }

                    // Multi-Signal Duplicate Image Detection: Check cryptographic hash against prior approved completions
                    if (!empty($imgHash)) {
                        $dupImgStmt = $db->prepare("
                            SELECT c.id, c.user_id, c.quest_id, c.completed_at 
                            FROM quest_completions c
                            WHERE c.image_hash = :hash AND (c.user_id != :uid OR c.quest_id != :qid)
                            LIMIT 1
                        ");
                        $dupImgStmt->execute(['hash' => $imgHash, 'uid' => $userId, 'qid' => $questId]);
                        $dupImg = $dupImgStmt->fetch();

                        if ($dupImg) {
                            $step1Passed = false;
                            $isSuspicious = 1;
                            $suspiciousReasons[] = "Duplicate photo submitted (Exact SHA-256 matched previous completion {$dupImg['id']}).";
                            $failureReasons[] = 'Duplicate photo detected: This exact image has already been submitted on QuestUP.';
                        }
                    }

                    // Perceptual duplicate detection: check dHash Hamming distance
                    if ($step1Passed && !empty($pHash) && $pHash !== '0000000000000000') {
                        $pHashStmt = $db->prepare("
                            SELECT perceptual_hash, id, user_id 
                            FROM quest_completions 
                            WHERE perceptual_hash IS NOT NULL AND perceptual_hash != '0000000000000000' AND user_id != :uid
                            ORDER BY completed_at DESC LIMIT 50
                        ");
                        $pHashStmt->execute(['uid' => $userId]);
                        while ($row = $pHashStmt->fetch()) {
                            $dist = compute_dhash_distance($pHash, (string)$row['perceptual_hash']);
                            if ($dist <= 3) {
                                $step1Passed = false;
                                $isSuspicious = 1;
                                $suspiciousReasons[] = "Perceptually identical photo matched previous completion {$row['id']} (Hamming distance: {$dist}).";
                                $failureReasons[] = 'Duplicate image detected: A visually identical photo was already uploaded by another explorer.';
                                break;
                            }
                        }
                    }

                    // Heuristic & Metadata Analysis
                    $meta = extract_image_metadata_safely($fullImgPath);
                    $analysis = analyze_image_proof_heuristics($fullImgPath, $quest, $meta);
                    $analysisResultStr = json_encode($analysis);

                    if (!$analysis['passed']) {
                        $step1Passed = false;
                        $failureReasons[] = $analysis['notes'];
                    }

                    // Location verification if quest has GPS coordinate requirements
                    if ($quest['latitude'] && $quest['longitude'] && (int)($quest['requires_gps'] ?? 0) === 1) {
                        if ($userLat !== null && $userLon !== null) {
                            $distance = haversine_distance_meters($userLat, $userLon, (float)$quest['latitude'], (float)$quest['longitude']);
                            $allowedRadius = (float)($quest['radius_meters'] ?? 250.0);
                            $locationResultStr = sprintf("Distance: %.1fm (Target: %s)", $distance, $quest['location_name']);
                            if ($distance > $allowedRadius) {
                                $step1Passed = false;
                                $failureReasons[] = sprintf("Location mismatch: Photo was captured %.0fm away from target area (limit: %.0fm).", $distance, $allowedRadius);
                            }
                        }
                    }
                }
            }
            break;

        case 'quiz':
            $quizRaw = $quest['quiz_data_json'] ?? '';
            $quizQuestions = json_decode($quizRaw, true) ?: [];
            $submittedAnswers = $proofPayload['answers'] ?? ($data['answers'] ?? []);

            if (empty($quizQuestions)) {
                $step1Passed = true;
            } else {
                $totalQuestions = count($quizQuestions);
                $correctCount = 0;

                foreach ($quizQuestions as $q) {
                    $qId = (string)($q['id'] ?? '');
                    $correctIndex = (int)($q['correct_index'] ?? 0);
                    $correctAnswer = trim((string)($q['correct_answer'] ?? ''));

                    // Look for matching submitted answer
                    foreach ($submittedAnswers as $sub) {
                        if ((string)($sub['question_id'] ?? '') === $qId || (string)($sub['id'] ?? '') === $qId) {
                            $selIndex = isset($sub['selected_index']) ? (int)$sub['selected_index'] : -1;
                            $selAns = trim((string)($sub['answer'] ?? ''));

                            if ($selIndex === $correctIndex || ($correctAnswer !== '' && strcasecmp($selAns, $correctAnswer) === 0)) {
                                $correctCount++;
                            }
                            break;
                        }
                    }
                }

                $scorePercent = $totalQuestions > 0 ? (int)round(($correctCount / $totalQuestions) * 100) : 100;
                $analysisResultStr = "Quiz Score: {$scorePercent}% ({$correctCount}/{$totalQuestions} correct)";

                if ($scorePercent < 60) {
                    $step1Passed = false;
                    $failureReasons[] = "Quiz evaluation failed: Scored {$scorePercent}% (60% minimum required to conquer quest).";
                }
            }
            break;

        case 'qr':
        case 'qrCode':
            $secret = trim((string)($quest['verification_secret'] ?? ''));
            $scannedQr = trim((string)($proofPayload['qr_code'] ?? ($proofPayload['token'] ?? ($data['qr_code'] ?? ''))));

            if ($secret !== '') {
                if (strcasecmp($scannedQr, $secret) !== 0) {
                    $step1Passed = false;
                    $failureReasons[] = 'Invalid QR code scanned. The QR code does not match this quest.';
                }
            } else {
                if (empty($scannedQr)) {
                    $step1Passed = false;
                    $failureReasons[] = 'QR Code scan payload is required.';
                }
            }
            break;

        case 'code':
        case 'secretCode':
            $secret = trim((string)($quest['verification_secret'] ?? ''));
            $enteredCode = trim((string)($proofPayload['secret_code'] ?? ($data['secret_code'] ?? '')));

            if ($secret !== '') {
                if (strcasecmp($enteredCode, $secret) !== 0) {
                    $step1Passed = false;
                    $failureReasons[] = 'Secret verification code is incorrect.';
                }
            } else {
                if (empty($enteredCode)) {
                    $step1Passed = false;
                    $failureReasons[] = 'Secret verification code is required.';
                }
            }
            break;

        case 'task':
        case 'taskConfirmation':
            // Task self-acknowledgment validated with timing below
            $confirmed = (bool)($proofPayload['confirmed'] ?? ($data['confirmed'] ?? true));
            if (!$confirmed) {
                $step1Passed = false;
                $failureReasons[] = 'Task confirmation checklist must be confirmed.';
            }
            break;

        case 'admin':
        case 'adminApproval':
            $requiresAdminApproval = true;
            break;

        case 'writingText':
            $text = trim((string)($proofPayload['text_content'] ?? ''));
            $words = str_word_count($text);
            $reqWords = (int)($quest['required_words'] ?? 0);
            if ($reqWords > 0 && $words < $reqWords) {
                $step1Passed = false;
                $failureReasons[] = "Writing journal contains {$words} words (minimum required: {$reqWords} words).";
            }
            break;

        case 'drawingCanvas':
            $drawingSummary = trim((string)($proofPayload['drawing_summary'] ?? ($proofPayload['drawing_proof'] ?? '')));
            if (empty($drawingSummary)) {
                $step1Passed = false;
                $failureReasons[] = 'Drawing sketch canvas proof is required.';
            }
            break;

        default:
            // Fallback: GPS location check if quest specifies coordinates
            if ($quest['latitude'] && $quest['longitude']) {
                if ($userLat !== null && $userLon !== null) {
                    $distance = haversine_distance_meters($userLat, $userLon, (float)$quest['latitude'], (float)$quest['longitude']);
                    $allowedRadius = (float)($quest['radius_meters'] ?? 200.0);
                    if ($distance > $allowedRadius) {
                        $step1Passed = false;
                        $failureReasons[] = sprintf("Distance check failed (%.0fm from target).", $distance);
                    }
                }
            }
            break;
    }

    // --- STEP 2: SERVER-SIDE ANTI-CHEAT & TIMING VERIFICATION ---
    $startedTimestamp = strtotime($attempt['started_at']);
    $elapsedSeconds = time() - $startedTimestamp;
    $minRequiredSeconds = (int)($quest['min_duration_seconds'] ?? ($quest['required_duration_seconds'] ?? 0));

    if ($minRequiredSeconds > 0) {
        // Enforce minimum completion duration with 15% tolerance
        if ($elapsedSeconds < (int)($minRequiredSeconds * 0.85)) {
            $step2Passed = false;
            $isSuspicious = 1;
            $suspiciousReasons[] = "Impossibly fast completion (Elapsed {$elapsedSeconds}s vs required {$minRequiredSeconds}s).";
            $failureReasons[] = "Anti-cheat alert: Mission was completed abnormally fast ({$elapsedSeconds}s). Minimum required duration is {$minRequiredSeconds}s.";
        }
    }

    // Check rapid repeated failure bursts (> 6 rejected attempts in 3 minutes)
    $burstStmt = $db->prepare("
        SELECT COUNT(*) as fail_cnt FROM quest_verification_attempts 
        WHERE user_id = :uid AND status = 'rejected' AND created_at >= NOW() - INTERVAL 3 MINUTE
    ");
    $burstStmt->execute(['uid' => $userId]);
    $failCount = (int)($burstStmt->fetch()['fail_cnt'] ?? 0);

    if ($failCount >= 6) {
        $isSuspicious = 1;
        $suspiciousReasons[] = "High burst of failed verification requests ({$failCount} fails in 3 mins).";
    }

    // ==========================================
    // 6. ATOMIC DATABASE TRANSACTION
    // ==========================================
    $db->beginTransaction();

    $combinedFailureReason = !empty($failureReasons) ? implode(' | ', $failureReasons) : null;
    $combinedSuspiciousReason = !empty($suspiciousReasons) ? implode(' | ', $suspiciousReasons) : null;
    $proofJson = json_encode($proofPayload);

    if (!$step1Passed || !$step2Passed) {
        // REJECTED
        $db->prepare("
            UPDATE quest_verification_attempts
            SET status = :status,
                submitted_at = NOW(),
                failure_reason = :fail,
                is_suspicious = :susp,
                suspicious_reason = :suspr,
                location_result = :loc,
                analysis_result = :analysis,
                proof_data = :proof
            WHERE attempt_id = :aid
        ")->execute([
            'status' => $isSuspicious ? 'flagged' : 'rejected',
            'fail' => $combinedFailureReason,
            'susp' => $isSuspicious,
            'suspr' => $combinedSuspiciousReason,
            'loc' => $locationResultStr,
            'analysis' => $analysisResultStr,
            'proof' => $proofJson,
            'aid' => $attemptId,
        ]);

        $db->commit();

        logActivity(
            $userId,
            'quest_attempt_failed',
            "Quest '{$quest['title']}' verification rejected: " . ($combinedFailureReason ?: 'Requirements not met'),
            $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
        );

        echo json_encode([
            'success' => false,
            'status' => 'rejected',
            'is_suspicious' => (bool)$isSuspicious,
            'message' => $combinedFailureReason ?: 'Quest verification failed.',
            'attempt_id' => $attemptId,
        ]);
        exit;
    }

    if ($requiresAdminApproval) {
        // PENDING ADMIN APPROVAL
        $completionId = 'cmp_' . bin2hex(random_bytes(12));

        $db->prepare("
            INSERT INTO quest_completions (
                id, quest_id, attempt_id, user_id, verification_type,
                proof_data, image_hash, perceptual_hash, xp_earned, coins_earned,
                completed_at, status, review_notes
            ) VALUES (
                :id, :qid, :aid, :uid, :vtype,
                :proof, :imghash, :phash, 0, 0,
                NOW(), 'pending', 'Awaiting administrator verification review'
            )
        ")->execute([
            'id' => $completionId,
            'qid' => $questId,
            'aid' => $attemptId,
            'uid' => $userId,
            'vtype' => $verificationType,
            'proof' => $proofJson,
            'imghash' => $imgHash,
            'phash' => $pHash,
        ]);

        $db->prepare("
            UPDATE quest_verification_attempts
            SET status = 'pending_admin',
                submitted_at = NOW(),
                location_result = :loc,
                analysis_result = :analysis,
                proof_data = :proof,
                image_hash = :imghash,
                perceptual_hash = :phash
            WHERE attempt_id = :aid
        ")->execute([
            'loc' => $locationResultStr,
            'analysis' => $analysisResultStr,
            'proof' => $proofJson,
            'imghash' => $imgHash,
            'phash' => $pHash,
            'aid' => $attemptId,
        ]);

        $db->commit();

        logActivity(
            $userId,
            'quest_submitted',
            "Submitted proof for quest '{$quest['title']}' - Awaiting admin review",
            $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
        );

        echo json_encode([
            'success' => true,
            'status' => 'pending_admin',
            'is_pending_review' => true,
            'message' => 'Proof submitted successfully! Awaiting administrator review before reward grant.',
            'attempt_id' => $attemptId,
            'completion_id' => $completionId,
            'xp_earned' => 0,
            'coins_earned' => 0,
        ]);
        exit;
    }

    // ==========================================
    // APPROVED: GRANT COMPLETION & REWARDS
    // ==========================================
    $completionId = 'cmp_' . bin2hex(random_bytes(12));

    // 1. Insert completion record
    $insCmp = $db->prepare("
        INSERT INTO quest_completions (
            id, quest_id, attempt_id, user_id, verification_type,
            proof_data, image_hash, perceptual_hash, xp_earned, coins_earned,
            completed_at, status
        ) VALUES (
            :id, :qid, :aid, :uid, :vtype,
            :proof, :imghash, :phash, :xp, :coins,
            NOW(), 'verified'
        )
    ");
    $insCmp->execute([
        'id' => $completionId,
        'qid' => $questId,
        'aid' => $attemptId,
        'uid' => $userId,
        'vtype' => $verificationType,
        'proof' => $proofJson,
        'imghash' => $imgHash,
        'phash' => $pHash,
        'xp' => $serverXpReward,
        'coins' => $serverCoinsReward,
    ]);

    // 2. Update verification attempt record
    $db->prepare("
        UPDATE quest_verification_attempts
        SET status = 'approved',
            submitted_at = NOW(),
            verified_at = NOW(),
            location_result = :loc,
            analysis_result = :analysis,
            proof_data = :proof,
            image_hash = :imghash,
            perceptual_hash = :phash
        WHERE attempt_id = :aid
    ")->execute([
        'loc' => $locationResultStr,
        'analysis' => $analysisResultStr,
        'proof' => $proofJson,
        'imghash' => $imgHash,
        'phash' => $pHash,
        'aid' => $attemptId,
    ]);

    // 3. Atomically update user profile XP, Coins, and calculate Level
    $profStmt = $db->prepare("SELECT user_id, level, current_xp, xp_to_next_level, coins FROM user_profiles WHERE user_id = :uid FOR UPDATE");
    $profStmt->execute(['uid' => $userId]);
    $profile = $profStmt->fetch();

    $newLevel = 1;
    $didLevelUp = false;

    if ($profile) {
        $curXp = (int)$profile['current_xp'] + $serverXpReward;
        $curCoins = (int)$profile['coins'] + $serverCoinsReward;
        $lvl = (int)$profile['level'];
        $xpNext = (int)$profile['xp_to_next_level'];

        while ($curXp >= $xpNext && $xpNext > 0) {
            $curXp -= $xpNext;
            $lvl++;
            $xpNext = (int)round($xpNext * 1.35);
            $didLevelUp = true;
        }

        $newLevel = $lvl;

        $db->prepare("
            UPDATE user_profiles 
            SET current_xp = :xp,
                coins = :coins,
                level = :lvl,
                xp_to_next_level = :xpnext,
                updated_at = NOW()
            WHERE user_id = :uid
        ")->execute([
            'xp' => $curXp,
            'coins' => $curCoins,
            'lvl' => $lvl,
            'xpnext' => $xpNext,
            'uid' => $userId,
        ]);
    }

    // 4. Update Squad Co-op Assist if active
    try {
        $sqStmt = $db->prepare("
            SELECT id, quest_title, sender_id, receiver_id 
            FROM shared_quests 
            WHERE quest_id = :qid AND (receiver_id = :u1 OR sender_id = :u2) AND status != 'completed'
            LIMIT 1
        ");
        $sqStmt->execute(['qid' => $questId, 'u1' => $userId, 'u2' => $userId]);
        $shared = $sqStmt->fetch();

        if ($shared) {
            $db->prepare("UPDATE shared_quests SET status = 'completed', updated_at = NOW() WHERE id = :sid")
               ->execute(['sid' => $shared['id']]);
        }
    } catch (Throwable $_) {}

    // 5. Send System Notification to explorer
    try {
        $notifId = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );

        $db->prepare("
            INSERT INTO notifications (id, user_id, title, message, type, is_read, route_target, action_label, created_at)
            VALUES (:id, :uid, '🎉 Quest Conquered & Verified!', :msg, 'quest', 0, '/profile', 'View Rewards', NOW())
        ")->execute([
            'id' => $notifId,
            'uid' => $userId,
            'msg' => "Congratulations! '{$quest['title']}' verified! +{$serverXpReward} XP and +{$serverCoinsReward} Coins awarded.",
        ]);
    } catch (Throwable $_) {}

    $db->commit();

    logActivity(
        $userId,
        'quest_completed',
        "Completed quest '{$quest['title']}' (+{$serverXpReward} XP, +{$serverCoinsReward} Coins, Level: {$newLevel})",
        $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1'
    );

    // Authoritative Server Response
    echo json_encode([
        'success' => true,
        'status' => 'verified',
        'message' => 'Quest verified and completed successfully!',
        'completion_id' => $completionId,
        'attempt_id' => $attemptId,
        'xp_earned' => $serverXpReward,
        'coins_earned' => $serverCoinsReward,
        'did_level_up' => $didLevelUp,
        'new_level' => $newLevel,
        'location_result' => $locationResultStr,
    ]);

} catch (Throwable $e) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server database transaction error: ' . $e->getMessage(),
    ]);
}
