<?php
/**
 * QuestUP Admin - View User Profile & Quest History
 */

declare(strict_types=1);

$userId = trim($_GET['id'] ?? '');
if (empty($userId)) {
    header('Location: users.php');
    exit;
}

$pageTitle = 'Explorer Dossier';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Fetch User & Profile
$stmt = $db->prepare("
    SELECT u.id, u.name, u.email, u.status, u.created_at, u.updated_at,
           p.avatar_key, p.level, p.current_xp, p.xp_to_next_level, p.coins, p.joined_at
    FROM users u
    LEFT JOIN user_profiles p ON u.id = p.user_id
    WHERE u.id = :id
    LIMIT 1
");
$stmt->execute(['id' => $userId]);
$user = $stmt->fetch();

if (!$user) {
    echo '<div class="alert alert-danger">Explorer record not found. <a href="users.php" class="alert-link">Return to Users</a></div>';
    require_once __DIR__ . '/../includes/footer.php';
    exit;
}

// Fetch Completed Quests History
$stmt = $db->prepare("
    SELECT c.id, c.quest_id, c.xp_earned, c.coins_earned, c.completed_at, c.status, c.verification_type, c.proof_data,
           q.title as quest_title, q.category, q.difficulty, q.location_name
    FROM quest_completions c
    LEFT JOIN quests q ON c.quest_id = q.id
    WHERE c.user_id = :id
    ORDER BY c.completed_at DESC
");
$stmt->execute(['id' => $userId]);
$completions = $stmt->fetchAll();

// Fetch Earned Badges
$stmt = $db->prepare("
    SELECT ub.badge_id, ub.earned_at, b.name, b.description, b.icon, b.category, b.xp_bonus
    FROM user_badges ub
    LEFT JOIN badges b ON ub.badge_id = b.id
    WHERE ub.user_id = :id
    ORDER BY ub.earned_at DESC
");
$stmt->execute(['id' => $userId]);
$badges = $stmt->fetchAll();

$level = (int)($user['level'] ?? 1);
$currentXp = (int)($user['current_xp'] ?? 0);
$xpNext = max(1, (int)($user['xp_to_next_level'] ?? 500));
$xpPercent = min(100, (int)round(($currentXp / $xpNext) * 100));
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <a href="users.php" class="text-secondary small text-decoration-none mb-1 d-inline-block">
            <i class="fas fa-arrow-left me-1"></i> Back to Explorers List
        </a>
        <h2 class="display-font fs-3 mb-0"><?= e($user['name']) ?>'s Dossier</h2>
    </div>
    <div class="d-flex gap-2">
        <a href="user_edit.php?id=<?= urlencode($user['id']) ?>" class="btn btn-gaming btn-gaming-cyan">
            <i class="fas fa-edit me-1"></i> Edit Stats
        </a>
    </div>
</div>

<div class="row g-4 mb-4">
    <!-- Profile Card -->
    <div class="col-lg-4">
        <div class="glass-card text-center mb-4">
            <div class="podium-avatar-wrapper mb-3">
                <div class="admin-avatar" style="width: 80px; height: 80px; font-size: 2rem; margin: 0 auto; box-shadow: 0 0 25px var(--accent-cyan-glow);">
                    <?= strtoupper(substr($user['name'] ?? 'U', 0, 1)) ?>
                </div>
            </div>
            <h3 class="fs-4 mb-1"><?= e($user['name']) ?></h3>
            <p class="text-secondary small mb-2"><?= e($user['email']) ?></p>
            <div class="mb-3">
                <?= get_status_badge($user['status'] ?? 'active') ?>
                <span class="custom-badge badge-category ms-1">ID: <?= substr(e($user['id']), 0, 8) ?>...</span>
            </div>

            <div class="p-3 rounded mb-3 text-start" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                <div class="d-flex justify-content-between mb-1 small text-secondary">
                    <span>Level <?= $level ?> Explorer</span>
                    <span class="text-cyan fw-bold"><?= $currentXp ?> / <?= $xpNext ?> XP (<?= $xpPercent ?>%)</span>
                </div>
                <div class="progress" style="height: 10px; background-color: var(--bg-card);">
                    <div class="progress-bar bg-info progress-bar-striped progress-bar-animated" role="progressbar" style="width: <?= $xpPercent ?>%"></div>
                </div>
            </div>

            <div class="row g-2 text-center">
                <div class="col-6">
                    <div class="p-2 rounded" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                        <div class="text-gold fw-bold fs-5"><i class="fas fa-coins me-1"></i><?= format_number((int)($user['coins'] ?? 100)) ?></div>
                        <div class="text-muted small">Gold Coins</div>
                    </div>
                </div>
                <div class="col-6">
                    <div class="p-2 rounded" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                        <div class="text-success fw-bold fs-5"><i class="fas fa-trophy me-1"></i><?= count($completions) ?></div>
                        <div class="text-muted small">Quests Won</div>
                    </div>
                </div>
            </div>

            <hr class="my-3" style="border-color: var(--border-subtle);">
            <div class="text-start text-muted small">
                <div><i class="fas fa-calendar-alt me-2 text-cyan"></i> Registered: <?= date('M j, Y H:i', strtotime($user['created_at'])) ?></div>
                <div class="mt-1"><i class="fas fa-id-badge me-2 text-purple"></i> User UUID: <span class="font-monospace user-select-all"><?= e($user['id']) ?></span></div>
            </div>
        </div>

        <!-- Badges Card -->
        <div class="glass-card">
            <div class="card-header-clean">
                <h3 class="card-title-clean fs-6">
                    <i class="fas fa-medal text-gold"></i>
                    <span>Unlocked Badges (<?= count($badges) ?>)</span>
                </h3>
            </div>
            <?php if (empty($badges)): ?>
                <p class="text-muted small text-center my-3">No badges earned yet.</p>
            <?php else: ?>
                <div class="d-flex flex-wrap gap-2">
                    <?php foreach ($badges as $b): ?>
                        <div class="p-2 rounded d-flex align-items-center gap-2" style="background: var(--bg-surface); border: 1px solid var(--border-subtle); flex: 1 1 calc(50% - 8px);" title="<?= e($b['description'] ?? '') ?>">
                            <i class="fas fa-certificate text-gold fs-5"></i>
                            <div>
                                <div class="fw-bold small text-light"><?= e($b['name'] ?? $b['badge_id']) ?></div>
                                <div class="text-muted" style="font-size: 0.7rem;"><?= time_ago($b['earned_at']) ?></div>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>
    </div>

    <!-- Quest Completions History -->
    <div class="col-lg-8">
        <div class="glass-card h-100">
            <div class="card-header-clean">
                <h3 class="card-title-clean">
                    <i class="fas fa-history text-cyan"></i>
                    <span>Adventure Log & Quests Completed (<?= count($completions) ?>)</span>
                </h3>
            </div>

            <div class="table-responsive">
                <table class="table-custom">
                    <thead>
                        <tr>
                            <th>Quest</th>
                            <th>Verification</th>
                            <th>Rewards Earned</th>
                            <th>Status</th>
                            <th>Completed At</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($completions)): ?>
                            <tr>
                                <td colspan="5" class="text-center py-5 text-muted">
                                    <i class="fas fa-compass fs-2 mb-2 d-block opacity-50"></i>
                                    No completed adventures recorded for this user yet.
                                </td>
                            </tr>
                        <?php else: ?>
                            <?php foreach ($completions as $c): ?>
                                <tr>
                                    <td>
                                        <div class="fw-bold text-light"><?= e($c['quest_title'] ?? 'Landmark Quest') ?></div>
                                        <div class="small text-secondary"><i class="fas fa-map-marker-alt me-1 text-cyan"></i><?= e($c['location_name'] ?? 'Local Area') ?></div>
                                    </td>
                                    <td><?= get_verification_badge($c['verification_type'] ?? 'locationGps') ?></td>
                                    <td>
                                        <span class="text-cyan fw-bold">+<?= (int)$c['xp_earned'] ?> XP</span><br>
                                        <span class="text-gold small fw-bold">+<?= (int)$c['coins_earned'] ?> Coins</span>
                                    </td>
                                    <td><?= get_status_badge($c['status'] ?? 'verified') ?></td>
                                    <td class="text-secondary small"><?= date('M j, Y H:i', strtotime($c['completed_at'])) ?></td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
