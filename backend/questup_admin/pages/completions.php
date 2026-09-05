<?php
/**
 * QuestUP Admin - Quest Completions Log
 */

declare(strict_types=1);

$pageTitle = 'Quest Completion Records';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Filter parameters
$search = trim($_GET['search'] ?? '');
$statusFilter = trim($_GET['status'] ?? 'all');
$vtypeFilter = trim($_GET['verification_type'] ?? 'all');

$page = max(1, (int)($_GET['page'] ?? 1));
$limit = 15;
$offset = ($page - 1) * $limit;

$where = [];
$params = [];

if ($search !== '') {
    $where[] = "(u.name LIKE :search OR u.email LIKE :search OR q.title LIKE :search OR c.id LIKE :search)";
    $params['search'] = '%' . $search . '%';
}

if ($statusFilter !== 'all') {
    $where[] = "c.status = :status";
    $params['status'] = $statusFilter;
}

if ($vtypeFilter !== 'all') {
    $where[] = "c.verification_type = :vtype";
    $params['vtype'] = $vtypeFilter;
}

$whereSql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

// Total count
$countStmt = $db->prepare("
    SELECT COUNT(*) as total
    FROM quest_completions c
    LEFT JOIN users u ON c.user_id = u.id
    LEFT JOIN quests q ON c.quest_id = q.id
    $whereSql
");
$countStmt->execute($params);
$totalRecords = (int)($countStmt->fetch()['total'] ?? 0);
$totalPages = max(1, (int)ceil($totalRecords / $limit));

// Fetch Records
$stmt = $db->prepare("
    SELECT c.*, u.name as user_name, u.email as user_email,
           q.title as quest_title, q.category, q.difficulty, q.location_name
    FROM quest_completions c
    LEFT JOIN users u ON c.user_id = u.id
    LEFT JOIN quests q ON c.quest_id = q.id
    $whereSql
    ORDER BY c.completed_at DESC
    LIMIT $limit OFFSET $offset
");
$stmt->execute($params);
$completions = $stmt->fetchAll();
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Adventure Completion Registry</h2>
        <p class="text-secondary small mb-0">Auditable log of all quest milestones achieved by players</p>
    </div>
    <a href="verification.php" class="btn btn-gaming btn-gaming-purple">
        <i class="fas fa-shield-alt me-1"></i> Open Verification Center
    </a>
</div>

<!-- Filter Toolbar -->
<div class="glass-card mb-4">
    <form method="GET" action="completions.php" class="row g-2 g-md-3 align-items-center">
        <div class="col-12 col-md-4 col-xl-4">
            <div class="position-relative">
                <input type="text" 
                       name="search" 
                       class="form-control-gaming ps-5" 
                       placeholder="Search player, quest title, completion ID..." 
                       value="<?= e($search) ?>">
                <i class="fas fa-search position-absolute text-muted" style="left: 16px; top: 50%; transform: translateY(-50%);"></i>
            </div>
        </div>

        <div class="col-6 col-md-3 col-xl-3">
            <select name="status" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $statusFilter === 'all' ? 'selected' : '' ?>>All Verification Statuses</option>
                <option value="verified" <?= $statusFilter === 'verified' ? 'selected' : '' ?>>Verified / Approved</option>
                <option value="pending" <?= $statusFilter === 'pending' ? 'selected' : '' ?>>Pending Review</option>
                <option value="review" <?= $statusFilter === 'review' ? 'selected' : '' ?>>Flagged for Review</option>
                <option value="rejected" <?= $statusFilter === 'rejected' ? 'selected' : '' ?>>Rejected</option>
            </select>
        </div>

        <div class="col-6 col-md-3 col-xl-3">
            <select name="verification_type" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $vtypeFilter === 'all' ? 'selected' : '' ?>>All Verification Types</option>
                <option value="locationGps" <?= $vtypeFilter === 'locationGps' ? 'selected' : '' ?>>GPS Location</option>
                <option value="photo" <?= $vtypeFilter === 'photo' ? 'selected' : '' ?>>Photo</option>
                <option value="drawing" <?= $vtypeFilter === 'drawing' ? 'selected' : '' ?>>Drawing</option>
                <option value="writing" <?= $vtypeFilter === 'writing' ? 'selected' : '' ?>>Writing</option>
                <option value="qrCode" <?= $vtypeFilter === 'qrCode' ? 'selected' : '' ?>>QR Code</option>
            </select>
        </div>

        <div class="col-12 col-md-2 col-xl-2">
            <div class="d-flex gap-2">
                <button type="submit" class="btn btn-gaming btn-gaming-cyan w-100">
                    <i class="fas fa-filter me-1"></i> Filter
                </button>
                <?php if ($search !== '' || $statusFilter !== 'all' || $vtypeFilter !== 'all'): ?>
                    <a href="completions.php" class="btn btn-gaming btn-gaming-outline" title="Reset Filters">
                        <i class="fas fa-redo"></i>
                    </a>
                <?php endif; ?>
            </div>
        </div>
    </form>
</div>

<!-- Completions Table -->
<div class="glass-card">
    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th>Explorer</th>
                    <th>Quest Conquered</th>
                    <th>Method</th>
                    <th>Rewards Awarded</th>
                    <th>Status</th>
                    <th>Completed Date</th>
                    <th class="text-end table-actions-cell">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($completions)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="fas fa-check-circle fs-2 mb-2 d-block opacity-50"></i>
                            No completion records found.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($completions as $c): ?>
                        <tr>
                            <td>
                                <a href="user_view.php?id=<?= urlencode($c['user_id']) ?>" class="fw-bold text-light text-decoration-none hover-cyan">
                                    <?= e($c['user_name'] ?? 'Explorer') ?>
                                </a>
                                <div class="small text-secondary"><?= e($c['user_email'] ?? '') ?></div>
                            </td>
                            <td>
                                <a href="quest_view.php?id=<?= urlencode($c['quest_id']) ?>" class="fw-semibold text-cyan text-decoration-none">
                                    <?= e($c['quest_title'] ?? 'Landmark Quest') ?>
                                </a>
                                <div class="small text-muted"><i class="fas fa-map-marker-alt me-1 text-cyan"></i><?= e($c['location_name'] ?? 'Local') ?></div>
                            </td>
                            <td><?= get_verification_badge($c['verification_type'] ?? 'locationGps') ?></td>
                            <td>
                                <span class="text-cyan fw-bold">+<?= (int)$c['xp_earned'] ?> XP</span><br>
                                <span class="text-gold small fw-bold">+<?= (int)$c['coins_earned'] ?> Coins</span>
                            </td>
                            <td><?= get_status_badge($c['status'] ?? 'verified') ?></td>
                            <td class="text-secondary small"><?= date('M j, Y H:i', strtotime($c['completed_at'])) ?></td>
                            <td class="text-end table-actions-cell">
                                <div class="d-inline-flex gap-1 justify-content-end">
                                    <a href="verification.php?search=<?= urlencode($c['id']) ?>" class="btn-action-icon" title="View Submission & Proof">
                                        <i class="fas fa-search-plus text-cyan"></i>
                                    </a>
                                    <form method="POST" action="../actions/completion_actions.php" class="d-inline" onsubmit="return confirm('Delete this completion log? Note: This will not automatically revoke player XP/Coins.');">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="delete_completion">
                                        <input type="hidden" name="completion_id" value="<?= e($c['id']) ?>">
                                        <button type="submit" class="btn-action-icon text-danger" title="Delete Completion Log">
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

    <!-- Pagination -->
    <?php if ($totalPages > 1): ?>
        <div class="d-flex justify-content-between align-items-center mt-4 pt-3 border-top" style="border-color: var(--border-subtle) !important;">
            <div class="text-muted small">
                Showing page <strong><?= $page ?></strong> of <strong><?= $totalPages ?></strong>
            </div>
            <nav>
                <ul class="pagination pagination-sm mb-0">
                    <li class="page-item <?= $page <= 1 ? 'disabled' : '' ?>">
                        <a class="page-link bg-dark text-secondary border-secondary" href="?page=<?= $page - 1 ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>&verification_type=<?= urlencode($vtypeFilter) ?>">Previous</a>
                    </li>
                    <?php for ($i = max(1, $page - 2); $i <= min($totalPages, $page + 2); $i++): ?>
                        <li class="page-item <?= $i === $page ? 'active' : '' ?>">
                            <a class="page-link <?= $i === $page ? 'bg-info border-info text-dark fw-bold' : 'bg-dark text-secondary border-secondary' ?>" 
                               href="?page=<?= $i ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>&verification_type=<?= urlencode($vtypeFilter) ?>"><?= $i ?></a>
                        </li>
                    <?php endfor; ?>
                    <li class="page-item <?= $page >= $totalPages ? 'disabled' : '' ?>">
                        <a class="page-link bg-dark text-secondary border-secondary" href="?page=<?= $page + 1 ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>&verification_type=<?= urlencode($vtypeFilter) ?>">Next</a>
                    </li>
                </ul>
            </nav>
        </div>
    <?php endif; ?>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
