<?php
/**
 * QuestUP REST API - Secure Photo Proof Upload & Perceptual Hashing Engine
 * Endpoint: POST /api/quests/upload_proof.php
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
require_once __DIR__ . '/perceptual_hash.php';

$attemptId = trim($_POST['attempt_id'] ?? '');
$userId = trim($_POST['user_id'] ?? '');
$clientCaptureTime = trim($_POST['client_capture_time'] ?? '');

if (empty($attemptId) || empty($userId)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'attempt_id and user_id are required for proof upload.',
    ]);
    exit;
}

// 1. Check file upload in $_FILES
$fileKey = null;
foreach (['image', 'photo', 'file', 'proof'] as $key) {
    if (isset($_FILES[$key]) && is_array($_FILES[$key]) && $_FILES[$key]['error'] === UPLOAD_ERR_OK) {
        $fileKey = $key;
        break;
    }
}

if (!$fileKey) {
    $errCode = isset($_FILES) ? json_encode($_FILES) : 'No file received';
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'No valid photo proof file uploaded or upload error occurred. ' . $errCode,
    ]);
    exit;
}

$uploadedFile = $_FILES[$fileKey];

// Check file size (max 10MB)
if ($uploadedFile['size'] > 10 * 1024 * 1024) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Photo size exceeds maximum allowed limit of 10MB.',
    ]);
    exit;
}

// Check MIME type via finfo
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $uploadedFile['tmp_name']);
finfo_close($finfo);

$allowedMimes = [
    'image/jpeg' => 'jpg',
    'image/jpg'  => 'jpg',
    'image/png'  => 'png',
    'image/webp' => 'webp',
];

if (!isset($allowedMimes[$mimeType])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid image format. Allowed formats: JPEG, PNG, WEBP.',
    ]);
    exit;
}

$db = db();

try {
    // 2. Validate attempt ownership & status
    $attStmt = $db->prepare("
        SELECT id, attempt_id, user_id, quest_id, status, expires_at, started_at
        FROM quest_verification_attempts
        WHERE attempt_id = :aid AND user_id = :uid
        LIMIT 1
    ");
    $attStmt->execute(['aid' => $attemptId, 'uid' => $userId]);
    $attempt = $attStmt->fetch();

    if (!$attempt) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Verification attempt not found or does not belong to this user.',
        ]);
        exit;
    }

    if (strtotime($attempt['expires_at']) < time()) {
        $db->prepare("UPDATE quest_verification_attempts SET status = 'rejected', failure_reason = 'Attempt expired before upload' WHERE attempt_id = :aid")
           ->execute(['aid' => $attemptId]);

        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Verification challenge has expired. Please initiate a fresh attempt.',
        ]);
        exit;
    }

    // 3. Prepare upload directory
    $uploadDir = __DIR__ . '/../../uploads/proofs';
    if (!is_dir($uploadDir)) {
        @mkdir($uploadDir, 0755, true);
    }

    $ext = $allowedMimes[$mimeType];
    $cleanAttempt = preg_replace('/[^a-zA-Z0-9_]/', '', $attemptId);
    $safeFileName = 'proof_' . $cleanAttempt . '_' . bin2hex(random_bytes(8)) . '.' . $ext;
    $targetPath = $uploadDir . '/' . $safeFileName;

    if (!move_uploaded_file($uploadedFile['tmp_name'], $targetPath)) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Failed to store proof file on server.',
        ]);
        exit;
    }

    // 4. Compute Image Hashes & Metadata on Server
    $sha256Hash = compute_image_sha256($targetPath);
    $dHash = compute_image_dhash($targetPath) ?? '0000000000000000';
    $metadata = extract_image_metadata_safely($targetPath);
    $metadataJson = json_encode($metadata);

    $relativeMediaUrl = 'uploads/proofs/' . $safeFileName;

    // 5. Update Attempt record
    $parsedCaptureTime = !empty($clientCaptureTime) ? date('Y-m-d H:i:s', strtotime($clientCaptureTime)) : null;

    $updStmt = $db->prepare("
        UPDATE quest_verification_attempts
        SET media_url = :url,
            image_hash = :imghash,
            perceptual_hash = :phash,
            exif_metadata_json = :exif,
            client_capture_time = :captime,
            client_upload_time = NOW(),
            status = 'submitted'
        WHERE attempt_id = :aid
    ");

    $updStmt->execute([
        'url' => $relativeMediaUrl,
        'imghash' => $sha256Hash,
        'phash' => $dHash,
        'exif' => $metadataJson,
        'captime' => $parsedCaptureTime,
        'aid' => $attemptId,
    ]);

    echo json_encode([
        'success' => true,
        'message' => 'Photo proof securely uploaded and analyzed.',
        'attempt_id' => $attemptId,
        'media_url' => $relativeMediaUrl,
        'image_hash' => $sha256Hash,
        'perceptual_hash' => $dHash,
        'metadata_summary' => [
            'width' => $metadata['width'],
            'height' => $metadata['height'],
            'has_exif' => $metadata['has_exif'],
            'camera_model' => $metadata['camera_model'],
        ],
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error during photo proof processing: ' . $e->getMessage(),
    ]);
}
