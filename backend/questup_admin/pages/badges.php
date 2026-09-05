<?php
/**
 * QuestUP Admin - Badges & Achievements Management
 */

declare(strict_types=1);

$pageTitle = 'Badges & Achievement Vault';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Fetch all badges with user count
$stmt = $db->query("
    SELECT b.*,
           (SELECT COUNT(*) FROM user_badges WHERE badge_id = b.id) as unlocked_count
    FROM badges b
    ORDER BY b.created_at ASC
");
$badges = $stmt->fetchAll();

// Fetch all users for manual badge assignment dropdown
$userStmt = $db->query("SELECT id, name, email FROM users WHERE status = 'active' OR status IS NULL ORDER BY name ASC");
$allUsers = $userStmt->fetchAll();
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Achievement & Badge Vault</h2>
        <p class="text-secondary small mb-0">Manage unlockable honors, badges, and award manual trophies</p>
    </div>
    <div class="d-flex gap-2">
        <button type="button" class="btn btn-gaming btn-gaming-purple" data-bs-toggle="modal" data-bs-target="#assignBadgeModal">
            <i class="fas fa-gift me-1"></i> Grant Badge to User
        </button>
        <button type="button" class="btn btn-gaming btn-gaming-cyan" data-bs-toggle="modal" data-bs-target="#addBadgeModal">
            <i class="fas fa-plus me-1"></i> Create New Badge
        </button>
    </div>
</div>

<!-- Badges Catalog Table -->
<div class="glass-card mb-4">
    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th>Badge Honor</th>
                    <th>Category</th>
                    <th>XP Honorarium</th>
                    <th>Explorers Unlocked</th>
                    <th>Status</th>
                    <th class="text-end table-actions-cell">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($badges)): ?>
                    <tr>
                        <td colspan="6" class="text-center py-5 text-muted">
                            <i class="fas fa-medal fs-2 mb-2 d-block opacity-50"></i>
                            No badges in catalog. Click "Create New Badge" to add one.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($badges as $b): ?>
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-3">
                                    <div class="kpi-icon-box gold" style="width: 44px; height: 44px; font-size: 1.2rem;">
                                        <i class="fas fa-certificate text-gold"></i>
                                    </div>
                                    <div>
                                        <div class="fw-bold text-light"><?= e($b['name']) ?></div>
                                        <div class="small text-secondary"><?= e($b['description']) ?></div>
                                    </div>
                                </div>
                            </td>
                            <td><?= get_category_badge($b['category'] ?? 'exploration') ?></td>
                            <td>
                                <span class="text-cyan fw-bold">+<?= (int)$b['xp_bonus'] ?> XP</span>
                            </td>
                            <td>
                                <span class="badge bg-purple bg-opacity-25 text-purple border border-purple border-opacity-25">
                                    <i class="fas fa-users me-1"></i><?= (int)$b['unlocked_count'] ?> Explorers
                                </span>
                            </td>
                            <td><?= get_status_badge((int)$b['is_active']) ?></td>
                            <td class="text-end table-actions-cell">
                                <div class="d-inline-flex gap-1 justify-content-end">
                                    <form method="POST" action="../actions/badge_actions.php" class="d-inline">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="toggle_badge">
                                        <input type="hidden" name="badge_id" value="<?= e($b['id']) ?>">
                                        <input type="hidden" name="current_status" value="<?= (int)$b['is_active'] ?>">
                                        <button type="submit" class="btn-action-icon" title="<?= (int)$b['is_active'] === 1 ? 'Deactivate' : 'Activate' ?>">
                                            <i class="fas <?= (int)$b['is_active'] === 1 ? 'fa-toggle-on text-success' : 'fa-toggle-off text-muted' ?>"></i>
                                        </button>
                                    </form>
                                    <form method="POST" action="../actions/badge_actions.php" class="d-inline" onsubmit="return confirm('Delete badge <?= e($b['name']) ?>?');">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="delete_badge">
                                        <input type="hidden" name="badge_id" value="<?= e($b['id']) ?>">
                                        <button type="submit" class="btn-action-icon text-danger" title="Delete Badge">
                                            <i class="fas fa-trash-alt"></i>
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<!-- Modal: Create New Badge -->
<div class="modal fade" id="addBadgeModal" tabindex="-1" aria-labelledby="addBadgeModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content" style="background: var(--bg-card); border: 1px solid var(--border-cyan-glow); color: var(--text-primary); border-radius: 20px;">
            <div class="modal-header border-bottom" style="border-color: var(--border-subtle) !important;">
                <h5 class="modal-title display-font" id="addBadgeModalLabel">
                    <i class="fas fa-medal text-cyan me-2"></i> Create New Achievement Badge
                </h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form method="POST" action="../actions/badge_actions.php">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="create_badge">
                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label-gaming" for="badge_name">Badge Name *</label>
                        <input type="text" class="form-control-gaming" id="badge_name" name="name" placeholder="e.g. Skyline Mountaineer" required>
                    </div>

                    <div class="form-group">
                        <label class="form-label-gaming" for="badge_description">Description / Unlock Requirement *</label>
                        <textarea class="form-control-gaming" id="badge_description" name="description" rows="3" placeholder="Describe how an adventurer earns this badge..." required></textarea>
                    </div>

                    <div class="row g-3">
                        <div class="col-md-6">
                            <label class="form-label-gaming" for="badge_category">Category</label>
                            <select class="form-control-gaming" id="badge_category" name="category">
                                <option value="exploration">Exploration</option>
                                <option value="fitness">Fitness</option>
                                <option value="wealth">Wealth & Coins</option>
                                <option value="elite">Elite / Hardcore</option>
                                <option value="intellect">Intellect</option>
                            </select>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label-gaming" for="badge_xp">XP Bonus Award</label>
                            <input type="number" min="0" max="10000" class="form-control-gaming" id="badge_xp" name="xp_bonus" value="250" required>
                        </div>
                    </div>
                </div>
                <div class="modal-footer border-top" style="border-color: var(--border-subtle) !important;">
                    <button type="button" class="btn btn-gaming btn-gaming-outline" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-gaming btn-gaming-cyan">Save Badge</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Modal: Grant Badge to User -->
<div class="modal fade" id="assignBadgeModal" tabindex="-1" aria-labelledby="assignBadgeModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content" style="background: var(--bg-card); border: 1px solid var(--border-bright); color: var(--text-primary); border-radius: 20px;">
            <div class="modal-header border-bottom" style="border-color: var(--border-subtle) !important;">
                <h5 class="modal-title display-font" id="assignBadgeModalLabel">
                    <i class="fas fa-gift text-purple me-2"></i> Bestow Badge Upon Explorer
                </h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form method="POST" action="../actions/badge_actions.php">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="assign_badge">
                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label-gaming" for="target_user_id">Select Explorer *</label>
                        <select class="form-control-gaming" id="target_user_id" name="user_id" required>
                            <option value="">-- Choose Explorer --</option>
                            <?php foreach ($allUsers as $u): ?>
                                <option value="<?= e($u['id']) ?>"><?= e($u['name']) ?> (<?= e($u['email']) ?>)</option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label-gaming" for="target_badge_id">Select Badge Honor *</label>
                        <select class="form-control-gaming" id="target_badge_id" name="badge_id" required>
                            <option value="">-- Choose Badge --</option>
                            <?php foreach ($badges as $b): ?>
                                <option value="<?= e($b['id']) ?>"><?= e($b['name']) ?> (+<?= (int)$b['xp_bonus'] ?> XP)</option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-check mt-3">
                        <input class="form-check-input" type="checkbox" id="grant_xp" name="grant_xp" value="1" checked style="background-color: var(--bg-surface); border-color: var(--border-bright);">
                        <label class="form-check-label text-secondary small" for="grant_xp">
                            Automatically credit badge XP bonus to player profile
                        </label>
                    </div>
                </div>
                <div class="modal-footer border-top" style="border-color: var(--border-subtle) !important;">
                    <button type="button" class="btn btn-gaming btn-gaming-outline" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-gaming btn-gaming-purple">Bestow Honor</button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
