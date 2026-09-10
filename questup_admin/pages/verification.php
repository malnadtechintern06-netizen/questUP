<?php
/**
 * QuestUP Admin - Verification Command Center & Anti-Cheat Review Engine
 */

declare(strict_types=1);

$pageTitle = 'Verification Command Center';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Filter parameters
$statusTab = trim($_GET['status'] ?? 'pending');
$search = trim($_GET['search'] ?? '');

$where = [];
$params = [];

if ($statusTab === 'flagged') {
    $where[] = "(c.status = 'flagged' OR a.is_suspicious = 1 OR a.status = 'flagged')";
} elseif ($statusTab !== 'all') {
    $where[] = "c.status = :status";
    $params['status'] = $statusTab;
}

if ($search !== '') {
    $where[] = "(u.name LIKE :search OR u.email LIKE :search OR q.title LIKE :search OR c.id LIKE :search OR a.attempt_id LIKE :search)";
    $params['search'] = '%' . $search . '%';
}

$whereSql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

// Counts per tab
$pendingCount = $verifiedCount = $flaggedCount = $rejectedCount = 0;
try {
    $cStmt = $db->query("SELECT status, COUNT(*) as cnt FROM quest_completions GROUP BY status");
    while ($row = $cStmt->fetch()) {
        $st = $row['status'] ?? 'verified';
        if ($st === 'pending') $pendingCount = (int)$row['cnt'];
        elseif ($st === 'verified') $verifiedCount = (int)$row['cnt'];
        elseif ($st === 'rejected') $rejectedCount = (int)$row['cnt'];
    }

    $flgStmt = $db->query("SELECT COUNT(*) as cnt FROM quest_verification_attempts WHERE is_suspicious = 1 OR status = 'flagged'");
    $flaggedCount = (int)($flgStmt->fetch()['cnt'] ?? 0);
} catch (Throwable $_) {}

// Fetch submissions
$query = "
    SELECT c.*, 
           a.attempt_id, a.challenge_token, a.image_hash as att_image_hash, a.perceptual_hash as att_phash,
           a.exif_metadata_json, a.analysis_result, a.location_result, a.is_suspicious, a.suspicious_reason,
           a.client_capture_time, a.started_at as attempt_started_at, a.media_url as attempt_media_url,
           u.name as user_name, u.email as user_email,
           p.level as user_level, p.current_xp, p.coins as user_coins,
           q.title as quest_title, q.category, q.difficulty, q.verification_type as expected_vtype,
           q.xp_reward, q.coins_reward, q.latitude as quest_lat, q.longitude as quest_lng, q.location_name
    FROM quest_completions c
    LEFT JOIN quest_verification_attempts a ON (c.attempt_id = a.attempt_id OR (c.quest_id = a.quest_id AND c.user_id = a.user_id))
    LEFT JOIN users u ON c.user_id = u.id
    LEFT JOIN user_profiles p ON u.id = p.user_id
    LEFT JOIN quests q ON c.quest_id = q.id
    $whereSql
    ORDER BY c.completed_at DESC
    LIMIT 60
";

$stmt = $db->prepare($query);
$stmt->execute($params);
$submissions = $stmt->fetchAll();
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Verification & Anti-Cheat Center</h2>
        <p class="text-secondary small mb-0">Evaluate photo proofs, perceptual hashes, geofences, and authorize reward grants</p>
    </div>
    <div class="text-muted small">
        <i class="fas fa-shield-alt text-cyan me-1"></i> Two-Step Anti-Spoofing & Fair Play Engine
    </div>
</div>

<!-- Status Filter Tabs -->
<div class="d-flex flex-wrap gap-2 mb-4">
    <a href="?status=pending" class="btn btn-gaming <?= $statusTab === 'pending' ? 'btn-gaming-cyan' : 'btn-gaming-outline' ?>">
        <i class="fas fa-clock me-1"></i> Pending Review (<?= $pendingCount ?>)
    </a>
    <a href="?status=flagged" class="btn btn-gaming <?= $statusTab === 'flagged' ? 'btn-gaming-danger' : 'btn-gaming-outline' ?>">
        <i class="fas fa-exclamation-triangle me-1"></i> Flagged / Anti-Cheat (<?= $flaggedCount ?>)
    </a>
    <a href="?status=verified" class="btn btn-gaming <?= $statusTab === 'verified' ? 'btn-gaming-cyan' : 'btn-gaming-outline' ?>">
        <i class="fas fa-check-circle me-1"></i> Verified & Awarded (<?= $verifiedCount ?>)
    </a>
    <a href="?status=rejected" class="btn btn-gaming <?= $statusTab === 'rejected' ? 'btn-gaming-danger' : 'btn-gaming-outline' ?>">
        <i class="fas fa-times-circle me-1"></i> Rejected (<?= $rejectedCount ?>)
    </a>
    <a href="?status=all" class="btn btn-gaming <?= $statusTab === 'all' ? 'btn-gaming-outline active' : 'btn-gaming-outline' ?> ms-auto">
        <i class="fas fa-list me-1"></i> All Records
    </a>
</div>

<!-- Submissions Grid -->
<?php if (empty($submissions)): ?>
    <div class="glass-card text-center py-5">
        <i class="fas fa-clipboard-check fs-1 text-cyan mb-3 opacity-50"></i>
        <h3 class="fs-4">Queue is Clear!</h3>
        <p class="text-secondary mb-0">No submissions currently in the <?= e(strtoupper($statusTab)) ?> queue.</p>
    </div>
<?php else: ?>
    <div class="row g-4">
        <?php foreach ($submissions as $sub): ?>
            <?php
            $proofData = $sub['proof_data'] ?? '';
            $parsedProof = null;
            if (!empty($proofData)) {
                $decoded = json_decode($proofData, true);
                if (is_array($decoded)) {
                    $parsedProof = $decoded;
                }
            }

            $imgHash = $sub['image_hash'] ?: $sub['att_image_hash'];
            $pHash = $sub['perceptual_hash'] ?: $sub['att_phash'];
            $isSusp = (int)($sub['is_suspicious'] ?? 0) === 1;

            $photoUrl = null;
            if (!empty($sub['attempt_media_url'])) {
                $photoUrl = '../../' . ltrim($sub['attempt_media_url'], '/\\');
            } elseif (!empty($parsedProof['photo_url'])) {
                $photoUrl = $parsedProof['photo_url'];
            } elseif (!empty($parsedProof['proof']) && (strpos($parsedProof['proof'], '.jpg') !== false || strpos($parsedProof['proof'], '.png') !== false)) {
                $photoUrl = $parsedProof['proof'];
            }
            ?>
            <div class="col-lg-6">
                <div class="glass-card h-100 d-flex flex-column justify-content-between <?= $isSusp ? 'border border-danger' : '' ?>">
                    <div>
                        <!-- Header & Meta -->
                        <div class="d-flex justify-content-between align-items-start mb-3 border-bottom pb-3" style="border-color: var(--border-subtle) !important;">
                            <div>
                                <div class="d-flex align-items-center gap-2">
                                    <h4 class="fs-5 mb-0 text-white"><?= e($sub['quest_title'] ?? 'Unknown Mission') ?></h4>
                                    <?php if ($isSusp): ?>
                                        <span class="badge bg-danger"><i class="fas fa-shield-virus me-1"></i> Flagged</span>
                                    <?php endif; ?>
                                </div>
                                <div class="text-secondary small mt-1">
                                    <i class="fas fa-user text-cyan me-1"></i> <?= e($sub['user_name'] ?? 'Explorer') ?> (<?= e($sub['user_email'] ?? 'N/A') ?>)
                                    &bull; <span class="badge bg-secondary">Level <?= (int)($sub['user_level'] ?? 1) ?></span>
                                </div>
                            </div>
                            <div class="text-end">
                                <?php if ($sub['status'] === 'pending'): ?>
                                    <span class="badge bg-warning text-dark"><i class="fas fa-clock me-1"></i> Pending Review</span>
                                <?php elseif ($sub['status'] === 'verified'): ?>
                                    <span class="badge bg-success"><i class="fas fa-check-circle me-1"></i> Verified</span>
                                <?php elseif ($sub['status'] === 'rejected'): ?>
                                    <span class="badge bg-danger"><i class="fas fa-times-circle me-1"></i> Rejected</span>
                                <?php else: ?>
                                    <span class="badge bg-secondary"><?= e(strtoupper($sub['status'])) ?></span>
                                <?php endif; ?>
                                <div class="text-muted small mt-1"><?= e(date('M j, Y H:i', strtotime($sub['completed_at'] ?? 'now'))) ?></div>
                            </div>
                        </div>

                        <!-- Verification Protocol & Rewards -->
                        <div class="row g-2 mb-3 small">
                            <div class="col-6">
                                <span class="text-secondary">Type:</span> 
                                <span class="badge bg-dark border border-secondary text-cyan"><?= e($sub['verification_type'] ?? 'GPS') ?></span>
                            </div>
                            <div class="col-6 text-end">
                                <span class="text-secondary">Reward Value:</span> 
                                <span class="text-cyan fw-bold">+<?= (int)($sub['xp_reward'] ?? 100) ?> XP</span> &bull; 
                                <span class="text-gold fw-bold">+<?= (int)($sub['coins_reward'] ?? 50) ?> Coins</span>
                            </div>
                        </div>

                        <!-- Proof Evidence Inspection Card -->
                        <div class="p-3 rounded mb-3" style="background: rgba(0,0,0,0.3); border: 1px solid var(--border-subtle);">
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <div class="fw-bold text-white small"><i class="fas fa-fingerprint text-cyan me-1"></i> Telemetry & Proof Data</div>
                                <?php if ($pHash): ?>
                                    <span class="badge bg-dark border border-secondary text-light font-monospace small" title="Perceptual Difference Hash">dHash: <?= e(substr($pHash, 0, 8)) ?>...</span>
                                <?php endif; ?>
                            </div>

                            <!-- Photo Viewer if present -->
                            <?php if ($photoUrl): ?>
                                <div class="mb-3 text-center">
                                    <a href="<?= e($photoUrl) ?>" target="_blank" title="View Full Proof Image">
                                        <img src="<?= e($photoUrl) ?>" alt="Quest Proof" class="img-fluid rounded border border-secondary" style="max-height: 180px; object-fit: cover;">
                                    </a>
                                    <div class="text-muted small mt-1">
                                        <i class="fas fa-search-plus me-1"></i> Click photo to expand full resolution
                                    </div>
                                </div>
                            <?php endif; ?>

                            <!-- Cryptographic Fingerprint -->
                            <?php if ($imgHash): ?>
                                <div class="text-secondary small font-monospace text-truncate mb-1" title="<?= e($imgHash) ?>">
                                    <i class="fas fa-key text-gold me-1"></i> SHA-256: <?= e(substr($imgHash, 0, 24)) ?>...
                                </div>
                            <?php endif; ?>

                            <!-- Location or Analysis Result -->
                            <?php if (!empty($sub['location_result'])): ?>
                                <div class="text-info small mb-1">
                                    <i class="fas fa-map-marker-alt me-1"></i> <?= e($sub['location_result']) ?>
                                </div>
                            <?php endif; ?>

                            <?php if (!empty($sub['analysis_result'])): ?>
                                <div class="text-cyan small mb-1">
                                    <i class="fas fa-brain me-1"></i> <?= e($sub['analysis_result']) ?>
                                </div>
                            <?php endif; ?>

                            <?php if ($isSusp && !empty($sub['suspicious_reason'])): ?>
                                <div class="alert alert-danger py-1 px-2 small mb-1">
                                    <i class="fas fa-exclamation-circle me-1"></i> <strong>Security Flag:</strong> <?= e($sub['suspicious_reason']) ?>
                                </div>
                            <?php endif; ?>

                            <?php if (!empty($sub['review_notes'])): ?>
                                <div class="text-secondary small mt-1">
                                    <strong>Admin Notes:</strong> <?= e($sub['review_notes']) ?>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>

                    <!-- Action Controls -->
                    <div class="d-flex justify-content-between align-items-center pt-2 border-top" style="border-color: var(--border-subtle) !important;">
                        <span class="text-muted small">Attempt: <?= e(substr($sub['attempt_id'] ?? $sub['id'], 0, 16)) ?></span>

                        <?php if ($sub['status'] === 'pending' || $sub['status'] === 'flagged'): ?>
                            <div class="d-flex gap-2">
                                <!-- Reject Form -->
                                <form action="../actions/completion_actions.php" method="POST" class="d-inline" onsubmit="return confirm('Reject this verification submission?');">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="action" value="reject_verification">
                                    <input type="hidden" name="completion_id" value="<?= e($sub['id']) ?>">
                                    <input type="hidden" name="attempt_id" value="<?= e($sub['attempt_id'] ?? '') ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-danger">
                                        <i class="fas fa-times me-1"></i> Reject
                                    </button>
                                </form>

                                <!-- Approve Form -->
                                <form action="../actions/completion_actions.php" method="POST" class="d-inline">
                                    <?= csrf_field() ?>
                                    <input type="hidden" name="action" value="approve_verification">
                                    <input type="hidden" name="completion_id" value="<?= e($sub['id']) ?>">
                                    <input type="hidden" name="attempt_id" value="<?= e($sub['attempt_id'] ?? '') ?>">
                                    <input type="hidden" name="user_id" value="<?= e($sub['user_id']) ?>">
                                    <input type="hidden" name="xp_reward" value="<?= (int)($sub['xp_reward'] ?? 100) ?>">
                                    <input type="hidden" name="coins_reward" value="<?= (int)($sub['coins_reward'] ?? 50) ?>">
                                    <button type="submit" class="btn btn-sm btn-gaming btn-gaming-cyan">
                                        <i class="fas fa-check me-1"></i> Approve & Award
                                    </button>
                                </form>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
