<?php
/**
 * QuestUP Admin - Notification Dispatcher & Broadcast Management
 */

declare(strict_types=1);

$pageTitle = 'Notification Broadcast Center';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Fetch all users for targeted notification dropdown
$uStmt = $db->query("SELECT id, name, email FROM users WHERE status = 'active' OR status IS NULL ORDER BY name ASC");
$allUsers = $uStmt->fetchAll();

// Fetch recent notifications
$stmt = $db->query("
    SELECT n.*, u.name as recipient_name, u.email as recipient_email
    FROM notifications n
    LEFT JOIN users u ON n.user_id = u.id
    ORDER BY n.created_at DESC
    LIMIT 50
");
$notifications = $stmt->fetchAll();
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Broadcast & System Alerts</h2>
        <p class="text-secondary small mb-0">Dispatch notifications to all active explorers or target specific players</p>
    </div>
    <button type="button" class="btn btn-gaming btn-gaming-cyan" data-bs-toggle="modal" data-bs-target="#newNotificationModal">
        <i class="fas fa-paper-plane me-1"></i> Compose Notification
    </button>
</div>

<div class="row g-4">
    <!-- Notification Logs -->
    <div class="col-12">
        <div class="glass-card">
            <div class="card-header-clean">
                <h3 class="card-title-clean">
                    <i class="fas fa-bell text-cyan"></i>
                    <span>Dispatched System Notifications (<?= count($notifications) ?>)</span>
                </h3>
            </div>

            <div class="table-responsive">
                <table class="table-custom">
                    <thead>
                        <tr>
                            <th>Recipient</th>
                            <th>Notification Title & Body</th>
                            <th>Category</th>
                            <th>Route Target</th>
                            <th>Status</th>
                            <th>Sent Time</th>
                            <th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($notifications)): ?>
                            <tr>
                                <td colspan="7" class="text-center py-5 text-muted">
                                    <i class="fas fa-bell-slash fs-2 mb-2 d-block opacity-50"></i>
                                    No notifications recorded in database yet.
                                </td>
                            </tr>
                        <?php else: ?>
                            <?php foreach ($notifications as $n): ?>
                                <tr>
                                    <td>
                                        <?php if (empty($n['user_id'])): ?>
                                            <span class="badge bg-warning bg-opacity-25 text-gold border border-warning border-opacity-25">
                                                <i class="fas fa-bullhorn me-1"></i> Broadcast (All Users)
                                            </span>
                                        <?php else: ?>
                                            <a href="user_view.php?id=<?= urlencode($n['user_id']) ?>" class="fw-bold text-light text-decoration-none hover-cyan">
                                                <?= e($n['recipient_name'] ?? 'User') ?>
                                            </a>
                                            <div class="small text-secondary"><?= e($n['recipient_email'] ?? $n['user_id']) ?></div>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <div class="fw-bold text-light"><?= e($n['title']) ?></div>
                                        <div class="small text-secondary text-truncate" style="max-width: 320px;"><?= e($n['message']) ?></div>
                                    </td>
                                    <td>
                                        <span class="custom-badge badge-category"><?= e(ucfirst($n['type'] ?? 'system')) ?></span>
                                    </td>
                                    <td>
                                        <span class="small font-monospace text-cyan"><?= e($n['route_target'] ?? '/home') ?></span>
                                    </td>
                                    <td>
                                        <?= (int)$n['is_read'] === 1 ? '<span class="text-success small"><i class="fas fa-check-double me-1"></i>Read</span>' : '<span class="text-muted small"><i class="fas fa-envelope me-1"></i>Unread</span>' ?>
                                    </td>
                                    <td class="text-secondary small"><?= time_ago($n['created_at']) ?></td>
                                    <td class="text-end">
                                        <form method="POST" action="../actions/notification_actions.php" class="d-inline" onsubmit="return confirm('Delete this notification?');">
                                            <?= csrf_field() ?>
                                            <input type="hidden" name="action" value="delete_notification">
                                            <input type="hidden" name="notification_id" value="<?= e($n['id']) ?>">
                                            <button type="submit" class="btn-action-icon text-danger" title="Delete Notification">
                                                <i class="fas fa-trash-alt"></i>
                                            </button>
                                        </form>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<!-- Modal: Compose Notification -->
<div class="modal fade" id="newNotificationModal" tabindex="-1" aria-labelledby="newNotificationModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content" style="background: var(--bg-card); border: 1px solid var(--border-cyan-glow); color: var(--text-primary); border-radius: 20px;">
            <div class="modal-header border-bottom" style="border-color: var(--border-subtle) !important;">
                <h5 class="modal-title display-font" id="newNotificationModalLabel">
                    <i class="fas fa-paper-plane text-cyan me-2"></i> Compose Notification Broadcast
                </h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form method="POST" action="../actions/notification_actions.php">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="send_notification">
                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label-gaming" for="recipient_type">Target Audience *</label>
                        <select class="form-control-gaming" id="recipient_type" name="recipient_type" onchange="toggleRecipientField(this.value)" required>
                            <option value="broadcast">Broadcast to ALL Active Explorers</option>
                            <option value="specific">Target Specific Explorer</option>
                        </select>
                    </div>

                    <div class="form-group" id="specificUserContainer" style="display: none;">
                        <label class="form-label-gaming" for="target_user_id">Select Explorer *</label>
                        <select class="form-control-gaming" id="target_user_id" name="target_user_id">
                            <option value="">-- Choose User --</option>
                            <?php foreach ($allUsers as $u): ?>
                                <option value="<?= e($u['id']) ?>"><?= e($u['name']) ?> (<?= e($u['email']) ?>)</option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label-gaming" for="notif_title">Notification Title *</label>
                        <input type="text" class="form-control-gaming" id="notif_title" name="title" placeholder="e.g. Weekend Double XP Event Active!" required>
                    </div>

                    <div class="form-group">
                        <label class="form-label-gaming" for="notif_message">Message Body *</label>
                        <textarea class="form-control-gaming" id="notif_message" name="message" rows="3" placeholder="Write the announcement or alert details..." required></textarea>
                    </div>

                    <div class="row g-3">
                        <div class="col-md-4">
                            <label class="form-label-gaming" for="notif_type">Notification Type</label>
                            <select class="form-control-gaming" id="notif_type" name="type">
                                <option value="system">System Announcement</option>
                                <option value="quest">Quest Alert</option>
                                <option value="achievement">Achievement Honor</option>
                                <option value="alert">Critical Alert</option>
                            </select>
                        </div>
                        <div class="col-md-4">
                            <label class="form-label-gaming" for="route_target">In-App Route</label>
                            <input type="text" class="form-control-gaming" id="route_target" name="route_target" value="/home" placeholder="/home, /quests...">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label-gaming" for="action_label">Button Action Label</label>
                            <input type="text" class="form-control-gaming" id="action_label" name="action_label" value="Explore Now" placeholder="e.g. View Rewards">
                        </div>
                    </div>
                </div>
                <div class="modal-footer border-top" style="border-color: var(--border-subtle) !important;">
                    <button type="button" class="btn btn-gaming btn-gaming-outline" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-gaming btn-gaming-cyan">
                        <i class="fas fa-paper-plane me-1"></i> Send Notification
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php
$extraScripts = <<<HTML
<script>
function toggleRecipientField(val) {
    const el = document.getElementById('specificUserContainer');
    if (el) {
        el.style.display = (val === 'specific') ? 'block' : 'none';
    }
}
</script>
HTML;

require_once __DIR__ . '/../includes/footer.php';
