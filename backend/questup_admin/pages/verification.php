<?php
/**
 * QuestUP Admin - Verification Center & Anti-Cheat Review
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

if ($statusTab !== 'all') {
    $where[] = "c.status = :status";
    $params['status'] = $statusTab;
}

if ($search !== '') {
    $where[] = "(u.name LIKE :search OR u.email LIKE :search OR q.title LIKE :search OR c.id LIKE :search)";
    $params['search'] = '%' . $search . '%';
}

$whereSql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

// Counts per tab
$pendingCount = $verifiedCount = $reviewCount = $rejectedCount = 0;
try {
    $cStmt = $db->query("SELECT status, COUNT(*) as cnt FROM quest_completions GROUP BY status");
    while ($row = $cStmt->fetch()) {
        $st = $row['status'] ?? 'verified';
        if ($st === 'pending') $pendingCount = (int)$row['cnt'];
        elseif ($st === 'verified') $verifiedCount = (int)$row['cnt'];
        elseif ($st === 'review') $reviewCount = (int)$row['cnt'];
        elseif ($st === 'rejected') $rejectedCount = (int)$row['cnt'];
    }
} catch (Throwable $_) {}

// Fetch submissions
$query = "
    SELECT c.*, u.name as user_name, u.email as user_email,
           p.level as user_level, p.current_xp, p.coins as user_coins,
           q.title as quest_title, q.category, q.difficulty, q.verification_type as expected_vtype,
           q.xp_reward, q.coins_reward, q.latitude as quest_lat, q.longitude as quest_lng, q.location_name
    FROM quest_completions c
    LEFT JOIN users u ON c.user_id = u.id
    LEFT JOIN user_profiles p ON u.id = p.user_id
    LEFT JOIN quests q ON c.quest_id = q.id
    $whereSql
    ORDER BY c.completed_at DESC
    LIMIT 50
";
$stmt = $db->prepare($query);
$stmt->execute($params);
$submissions = $stmt->fetchAll();
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Verification & Proof Inspection</h2>
        <p class="text-secondary small mb-0">Evaluate player proof submissions and authorize reward grants</p>
    </div>
    <div class="text-muted small">
        <i class="fas fa-shield-alt text-cyan me-1"></i> Human-in-the-loop Anti-Spoofing & Fair Play
    </div>
</div>

<!-- Status Filter Tabs -->
<div class="d-flex flex-wrap gap-2 mb-4">
    <a href="?status=pending" class="btn btn-gaming <?= $statusTab === 'pending' ? 'btn-gaming-cyan' : 'btn-gaming-outline' ?>">
        <i class="fas fa-clock me-1"></i> Pending (<?= $pendingCount ?>)
    </a>
    <a href="?status=review" class="btn btn-gaming <?= $statusTab === 'review' ? 'btn-gaming-purple' : 'btn-gaming-outline' ?>">
        <i class="fas fa-eye me-1"></i> Review Required (<?= $reviewCount ?>)
    </a>
    <a href="?status=verified" class="btn btn-gaming <?= $statusTab === 'verified' ? 'btn-gaming-cyan' : 'btn-gaming-outline' ?>">
        <i class="fas fa-check-circle me-1"></i> Verified (<?= $verifiedCount ?>)
    </a>
    <a href="?status=rejected" class="btn btn-gaming <?= $statusTab === 'rejected' ? 'btn-gaming-danger' : 'btn-gaming-outline' ?>">
        <i class="fas fa-times-circle me-1"></i> Rejected (<?= $rejectedCount ?>)
    </a>
    <a href="?status=all" class="btn btn-gaming <?= $statusTab === 'all' ? 'btn-gaming-outline active' : 'btn-gaming-outline' ?> ms-auto">
        <i class="fas fa-list me-1"></i> All Submissions
    </a>
</div>

<!-- Submissions List -->
<?php if (empty($submissions)): ?>
    <div class="glass-card text-center py-5">
        <i class="fas fa-clipboard-check fs-1 text-cyan mb-3 opacity-50"></i>
        <h3 class="fs-4">Queue is Clear!</h3>
        <p class="text-secondary mb-0">No submissions currently in the <?= e(strtoupper($statusTab)) ?> state.</p>
    </div>
<?php else: ?>
    <div class="row g-4">
        <?php foreach ($submissions as $sub): ?>
            <?php
            $proofData = $sub['proof_data'] ?? '';
            $parsedProof = null;
            if (!empty($proofData)) {
                $decoded = json_decode($proofData, true);
                if (json_last_error() === JSON_ERROR_NONE) {
                    $parsedProof = $decoded;
                }
            }
            ?>
            <div class="col-lg-6">
                <div class="glass-card h-100 d-flex flex-direction-column justify-content-between">
                    <div>
                        <!-- Header & Meta -->
                        <div class="d-flex justify-content-between align-items-start mb-3 border-bottom pb-3" style="border-color: var(--border-subtle) !important;">
                            <div>
                                <span class="badge bg-primary bg-opacity-25 text-cyan border border-info border-opacity-25 small mb-1">
                                    ID: <?= substr(e($sub['id']), 0, 8) ?>
                                </span>
                                <h4 class="fs-5 mb-0 text-light"><?= e($sub['quest_title'] ?? 'Landmark Discovery') ?></h4>
                                <div class="small text-secondary mt-1">
                                    <i class="fas fa-map-pin text-cyan me-1"></i><?= e($sub['location_name'] ?? 'Target Area') ?>
                                </div>
                            </div>
                            <div class="text-end">
                                <?= get_status_badge($sub['status'] ?? 'pending') ?>
                                <div class="small text-muted mt-1"><?= time_ago($sub['completed_at']) ?></div>
                            </div>
                        </div>

                        <!-- Explorer Dossier -->
                        <div class="p-3 rounded mb-3" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                            <div class="d-flex justify-content-between align-items-center">
                                <div>
                                    <div class="fw-bold text-light"><?= e($sub['user_name'] ?? 'Adventurer') ?></div>
                                    <div class="small text-secondary"><?= e($sub['user_email'] ?? $sub['user_id']) ?></div>
                                </div>
                                <div class="text-end">
                                    <span class="badge bg-info bg-opacity-25 text-cyan border border-info border-opacity-25">Lvl <?= (int)($sub['user_level'] ?? 1) ?></span>
                                    <div class="small text-gold fw-bold mt-1"><i class="fas fa-coins me-1"></i><?= format_number((int)($sub['user_coins'] ?? 100)) ?></div>
                                </div>
                            </div>
                        </div>

                        <!-- Proof & Evidence Inspector -->
                        <div class="p-3 rounded mb-3" style="background: var(--bg-core); border: 1px solid var(--border-bright);">
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span class="text-uppercase small fw-bold text-secondary">
                                    <i class="fas fa-fingerprint text-purple me-1"></i> Verification Evidence
                                </span>
                                <?= get_verification_badge($sub['verification_type'] ?? 'locationGps') ?>
                            </div>

                            <?php if ($parsedProof): ?>
                                <div class="small text-light font-monospace" style="font-size: 0.82rem;">
                                    <?php foreach ($parsedProof as $k => $v): ?>
                                        <div class="mb-1">
                                            <span class="text-secondary"><?= e(ucwords(str_replace('_', ' ', (string)$k))) ?>:</span>
                                            <?php if (is_array($v)): ?>
                                                <pre class="m-0 text-cyan"><?= e(json_encode($v, JSON_PRETTY_PRINT)) ?></pre>
                                            <?php elseif (str_starts_with((string)$v, 'data:image')): ?>
                                                <div class="mt-2 text-center">
                                                    <img src="<?= e($v) ?>" alt="Submitted Drawing/Photo" class="rounded border border-secondary" style="max-height: 140px; max-width: 100%;">
                                                </div>
                                            <?php else: ?>
                                                <strong class="text-cyan"><?= e((string)$v) ?></strong>
                                            <?php endif; ?>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            <?php elseif (!empty($proofData)): ?>
                                <div class="small text-secondary font-monospace" style="max-height: 100px; overflow-y: auto;">
                                    <?= nl2br(e($proofData)) ?>
                                </div>
                            <?php else: ?>
                                <div class="small text-muted fst-italic">
                                    <i class="fas fa-check-circle text-success me-1"></i> GPS Geofence Check validated on-device.
                                </div>
                            <?php endif; ?>

                            <?php if (!empty($sub['review_notes'])): ?>
                                <div class="mt-2 pt-2 border-top border-secondary text-warning small">
                                    <i class="fas fa-comment-dots me-1"></i> <strong>Admin Note:</strong> <?= e($sub['review_notes']) ?>
                                </div>
                            <?php endif; ?>
                        </div>

                        <!-- Rewards to Award -->
                        <div class="d-flex justify-content-between align-items-center p-2 rounded mb-3" style="background: rgba(0, 229, 255, 0.05); border: 1px dashed rgba(0, 229, 255, 0.3);">
                            <span class="small text-secondary fw-semibold">Rewards on Approval:</span>
                            <div>
                                <span class="text-cyan fw-bold me-2">+<?= (int)($sub['xp_reward'] ?? $sub['xp_earned'] ?? 100) ?> XP</span>
                                <span class="text-gold fw-bold">+<?= (int)($sub['coins_reward'] ?? $sub['coins_earned'] ?? 50) ?> Coins</span>
                            </div>
                        </div>
                    </div>

                    <!-- Authorization Actions -->
                    <div class="pt-2 border-top d-flex gap-2 justify-content-end" style="border-color: var(--border-subtle) !important;">
                        <!-- Review Action Form -->
                        <form method="POST" action="../actions/completion_actions.php" class="d-inline">
                            <?= csrf_field() ?>
                            <input type="hidden" name="action" value="flag_review">
                            <input type="hidden" name="completion_id" value="<?= e($sub['id']) ?>">
                            <button type="submit" class="btn btn-gaming btn-gaming-outline py-2 px-3" style="font-size: 0.8rem;" title="Flag for further review">
                                <i class="fas fa-eye me-1"></i> Flag
                            </button>
                        </form>

                        <!-- Reject Action Form -->
                        <form method="POST" action="../actions/completion_actions.php" class="d-inline" onsubmit="return confirm('Reject this proof submission? Rewards will not be granted.');">
                            <?= csrf_field() ?>
                            <input type="hidden" name="action" value="reject_verification">
                            <input type="hidden" name="completion_id" value="<?= e($sub['id']) ?>">
                            <button type="submit" class="btn btn-gaming btn-gaming-danger py-2 px-3" style="font-size: 0.8rem;" title="Reject submission">
                                <i class="fas fa-times-circle me-1"></i> Reject
                            </button>
                        </form>

                        <!-- Approve & Award Rewards Action Form -->
                        <form method="POST" action="../actions/completion_actions.php" class="d-inline" onsubmit="return confirm('Approve verification and grant +<?= (int)($sub['xp_reward'] ?? $sub['xp_earned']) ?> XP and +<?= (int)($sub['coins_reward'] ?? $sub['coins_earned']) ?> Coins to explorer?');">
                            <?= csrf_field() ?>
                            <input type="hidden" name="action" value="approve_verification">
                            <input type="hidden" name="completion_id" value="<?= e($sub['id']) ?>">
                            <input type="hidden" name="user_id" value="<?= e($sub['user_id']) ?>">
                            <input type="hidden" name="xp_reward" value="<?= (int)($sub['xp_reward'] ?? $sub['xp_earned'] ?? 100) ?>">
                            <input type="hidden" name="coins_reward" value="<?= (int)($sub['coins_reward'] ?? $sub['coins_earned'] ?? 50) ?>">
                            <button type="submit" class="btn btn-gaming btn-gaming-cyan py-2 px-3" style="font-size: 0.8rem;">
                                <i class="fas fa-check-circle me-1"></i> Approve & Award
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
