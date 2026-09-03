<?php
/**
 * QuestUP Admin - User Management
 */

declare(strict_types=1);

$pageTitle = 'Explorers & Player Management';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Filter & Search Parameters
$search = trim($_GET['search'] ?? '');
$statusFilter = trim($_GET['status'] ?? 'all');
$levelFilter = trim($_GET['level'] ?? 'all');
$sortBy = trim($_GET['sort'] ?? 'created_at');
$sortOrder = strtoupper(trim($_GET['order'] ?? 'DESC')) === 'ASC' ? 'ASC' : 'DESC';

$page = max(1, (int)($_GET['page'] ?? 1));
$limit = 15;
$offset = ($page - 1) * $limit;

// Build Query
$where = [];
$params = [];

if ($search !== '') {
    $where[] = "(u.name LIKE :search OR u.email LIKE :search OR u.id LIKE :search)";
    $params['search'] = '%' . $search . '%';
}

if ($statusFilter !== 'all' && in_array($statusFilter, ['active', 'disabled'])) {
    if ($statusFilter === 'active') {
        $where[] = "(u.status = 'active' OR u.status IS NULL)";
    } else {
        $where[] = "u.status = 'disabled'";
    }
}

if ($levelFilter !== 'all' && is_numeric($levelFilter)) {
    $where[] = "p.level = :level";
    $params['level'] = (int)$levelFilter;
}

$whereSql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

// Valid Sort Columns
$sortMap = [
    'name' => 'u.name',
    'email' => 'u.email',
    'level' => 'p.level',
    'xp' => 'p.current_xp',
    'coins' => 'p.coins',
    'created_at' => 'u.created_at',
];
$orderColumn = $sortMap[$sortBy] ?? 'u.created_at';

// Total Count for Pagination
$countQuery = "
    SELECT COUNT(*) as total
    FROM users u
    LEFT JOIN user_profiles p ON u.id = p.user_id
    $whereSql
";
$stmt = $db->prepare($countQuery);
$stmt->execute($params);
$totalRecords = (int)($stmt->fetch()['total'] ?? 0);
$totalPages = max(1, (int)ceil($totalRecords / $limit));

// Fetch Users List
$dataQuery = "
    SELECT u.id, u.player_id, u.name, u.email, u.status, u.created_at,
           p.avatar_key, p.level, p.current_xp, p.xp_to_next_level, p.coins,
           (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id) as completed_count,
           (SELECT COUNT(*) FROM user_badges WHERE user_id = u.id) as badge_count
    FROM users u
    LEFT JOIN user_profiles p ON u.id = p.user_id
    $whereSql
    ORDER BY $orderColumn $sortOrder
    LIMIT $limit OFFSET $offset
";
$stmt = $db->prepare($dataQuery);
$stmt->execute($params);
$users = $stmt->fetchAll();
?>

<div class="glass-card mb-4">
    <!-- Filter & Search Toolbar -->
    <form method="GET" action="users.php" class="row g-3 align-items-center">
        <div class="col-lg-4 col-md-6">
            <div class="position-relative">
                <input type="text" 
                       name="search" 
                       class="form-control-gaming ps-5" 
                       placeholder="Search by name, email, or ID..." 
                       value="<?= e($search) ?>">
                <i class="fas fa-search position-absolute text-muted" style="left: 16px; top: 50%; transform: translateY(-50%);"></i>
            </div>
        </div>

        <div class="col-lg-2 col-md-3">
            <select name="status" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $statusFilter === 'all' ? 'selected' : '' ?>>All Statuses</option>
                <option value="active" <?= $statusFilter === 'active' ? 'selected' : '' ?>>Active Only</option>
                <option value="disabled" <?= $statusFilter === 'disabled' ? 'selected' : '' ?>>Disabled Only</option>
            </select>
        </div>

        <div class="col-lg-2 col-md-3">
            <select name="sort" class="form-control-gaming" onchange="this.form.submit()">
                <option value="created_at" <?= $sortBy === 'created_at' ? 'selected' : '' ?>>Sort: Joined Date</option>
                <option value="level" <?= $sortBy === 'level' ? 'selected' : '' ?>>Sort: Level</option>
                <option value="xp" <?= $sortBy === 'xp' ? 'selected' : '' ?>>Sort: Current XP</option>
                <option value="coins" <?= $sortBy === 'coins' ? 'selected' : '' ?>>Sort: Coins</option>
                <option value="name" <?= $sortBy === 'name' ? 'selected' : '' ?>>Sort: Name (A-Z)</option>
            </select>
        </div>

        <div class="col-lg-2 col-md-6">
            <div class="d-flex gap-2">
                <button type="submit" class="btn btn-gaming btn-gaming-cyan w-100">
                    <i class="fas fa-filter me-1"></i> Filter
                </button>
                <?php if ($search !== '' || $statusFilter !== 'all' || $levelFilter !== 'all'): ?>
                    <a href="users.php" class="btn btn-gaming btn-gaming-outline" title="Reset Filters">
                        <i class="fas fa-redo"></i>
                    </a>
                <?php endif; ?>
            </div>
        </div>

        <div class="col-lg-2 col-md-6 text-lg-end text-muted small">
            Found <strong><?= number_format($totalRecords) ?></strong> explorers
        </div>
    </form>
</div>

<!-- Users Table Card -->
<div class="glass-card">
    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th>Explorer</th>
                    <th>Level & XP</th>
                    <th>Coins</th>
                    <th>Quests Won</th>
                    <th>Badges</th>
                    <th>Status</th>
                    <th>Joined</th>
                    <th class="text-end">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($users)): ?>
                    <tr>
                        <td colspan="8" class="text-center py-5 text-muted">
                            <i class="fas fa-users-slash fs-2 mb-2 d-block opacity-50"></i>
                            No users found matching your criteria.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($users as $u): ?>
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-3">
                                    <div class="admin-avatar" style="width: 36px; height: 36px; font-size: 0.85rem;">
                                        <?= strtoupper(substr($u['name'] ?? 'U', 0, 1)) ?>
                                    </div>
                                    <div>
                                        <a href="user_view.php?id=<?= urlencode($u['id']) ?>" class="fw-bold text-light text-decoration-none hover-cyan">
                                            <?= e($u['name'] ?? 'Adventurer') ?>
                                        </a>
                                        <span class="badge bg-dark text-cyan border border-secondary font-monospace ms-1" style="font-size: 0.72rem;">
                                            <?= e($u['player_id'] ?? 'QST-0000') ?>
                                        </span>
                                        <div class="small text-secondary"><?= e($u['email']) ?></div>
                                    </div>
                                </div>
                            </td>
                            <td>
                                <span class="badge bg-info bg-opacity-25 text-cyan border border-info border-opacity-25">Lvl <?= (int)($u['level'] ?? 1) ?></span>
                                <div class="small text-muted mt-1"><?= format_number((int)($u['current_xp'] ?? 0)) ?> XP</div>
                            </td>
                            <td>
                                <span class="text-gold fw-bold"><i class="fas fa-coins me-1"></i><?= format_number((int)($u['coins'] ?? 100)) ?></span>
                            </td>
                            <td>
                                <span class="badge bg-success bg-opacity-25 text-success border border-success border-opacity-25">
                                    <i class="fas fa-trophy me-1"></i><?= (int)$u['completed_count'] ?>
                                </span>
                            </td>
                            <td>
                                <span class="badge bg-purple bg-opacity-25 text-purple border border-purple border-opacity-25">
                                    <i class="fas fa-medal me-1"></i><?= (int)$u['badge_count'] ?>
                                </span>
                            </td>
                            <td><?= get_status_badge($u['status'] ?? 'active') ?></td>
                            <td class="text-secondary small"><?= date('M j, Y', strtotime($u['created_at'])) ?></td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    <a href="user_view.php?id=<?= urlencode($u['id']) ?>" class="btn-action-icon" title="View Full Profile">
                                        <i class="fas fa-eye"></i>
                                    </a>
                                    <a href="user_edit.php?id=<?= urlencode($u['id']) ?>" class="btn-action-icon" title="Edit Stats / Level">
                                        <i class="fas fa-edit text-cyan"></i>
                                    </a>
                                    <form method="POST" action="../actions/user_actions.php" class="d-inline" onsubmit="return confirm('Change status for this user?');">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="toggle_status">
                                        <input type="hidden" name="user_id" value="<?= e($u['id']) ?>">
                                        <input type="hidden" name="current_status" value="<?= e($u['status'] ?? 'active') ?>">
                                        <button type="submit" class="btn-action-icon" title="<?= ($u['status'] ?? 'active') === 'disabled' ? 'Enable User' : 'Disable User' ?>">
                                            <i class="fas <?= ($u['status'] ?? 'active') === 'disabled' ? 'fa-check text-success' : 'fa-ban text-warning' ?>"></i>
                                        </button>
                                    </form>
                                    <form method="POST" action="../actions/user_actions.php" class="d-inline" onsubmit="return confirm('PERMANENTLY delete user <?= e($u['name']) ?> and all associated records? This cannot be undone!');">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="delete_user">
                                        <input type="hidden" name="user_id" value="<?= e($u['id']) ?>">
                                        <button type="submit" class="btn-action-icon text-danger" title="Delete User">
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
                        <a class="page-link bg-dark text-secondary border-secondary" href="?page=<?= $page - 1 ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>&sort=<?= urlencode($sortBy) ?>">Previous</a>
                    </li>
                    <?php for ($i = max(1, $page - 2); $i <= min($totalPages, $page + 2); $i++): ?>
                        <li class="page-item <?= $i === $page ? 'active' : '' ?>">
                            <a class="page-link <?= $i === $page ? 'bg-info border-info text-dark fw-bold' : 'bg-dark text-secondary border-secondary' ?>" 
                               href="?page=<?= $i ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>&sort=<?= urlencode($sortBy) ?>"><?= $i ?></a>
                        </li>
                    <?php endfor; ?>
                    <li class="page-item <?= $page >= $totalPages ? 'disabled' : '' ?>">
                        <a class="page-link bg-dark text-secondary border-secondary" href="?page=<?= $page + 1 ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>&sort=<?= urlencode($sortBy) ?>">Next</a>
                    </li>
                </ul>
            </nav>
        </div>
    <?php endif; ?>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
