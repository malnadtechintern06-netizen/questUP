<?php
/**
 * QuestUP Admin - Quest Management
 */

declare(strict_types=1);

$pageTitle = 'Quest Catalog & Quests';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Filter & Search Parameters
$search = trim($_GET['search'] ?? '');
$category = trim($_GET['category'] ?? 'all');
$difficulty = trim($_GET['difficulty'] ?? 'all');
$vtype = trim($_GET['verification_type'] ?? 'all');
$status = trim($_GET['status'] ?? 'all');

$page = max(1, (int)($_GET['page'] ?? 1));
$limit = 12;
$offset = ($page - 1) * $limit;

// Build Query Filters
$where = [];
$params = [];

if ($search !== '') {
    $where[] = "(title LIKE :search OR description LIKE :search OR location_name LIKE :search)";
    $params['search'] = '%' . $search . '%';
}

if ($category !== 'all') {
    $where[] = "category = :category";
    $params['category'] = $category;
}

if ($difficulty !== 'all') {
    $where[] = "difficulty = :difficulty";
    $params['difficulty'] = $difficulty;
}

if ($vtype !== 'all') {
    $where[] = "verification_type = :vtype";
    $params['vtype'] = $vtype;
}

if ($status !== 'all') {
    $where[] = "is_active = :status";
    $params['status'] = ($status === 'active') ? 1 : 0;
}

$whereSql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

// Count Total Quests
$countStmt = $db->prepare("SELECT COUNT(*) as total FROM quests $whereSql");
$countStmt->execute($params);
$totalQuests = (int)($countStmt->fetch()['total'] ?? 0);
$totalPages = max(1, (int)ceil($totalQuests / $limit));

// Fetch Quests
$query = "
    SELECT q.*,
           (SELECT COUNT(*) FROM quest_completions WHERE quest_id = q.id) as completions_count
    FROM quests q
    $whereSql
    ORDER BY created_at DESC
    LIMIT $limit OFFSET $offset
";
$stmt = $db->prepare($query);
$stmt->execute($params);
$quests = $stmt->fetchAll();
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Live Quest Registry</h2>
        <p class="text-secondary small mb-0">Create, balance, and manage real-world adventures</p>
    </div>
    <a href="quest_add.php" class="btn btn-gaming btn-gaming-cyan">
        <i class="fas fa-plus me-1"></i> Create New Quest
    </a>
</div>

<!-- Filters Toolbar Card -->
<div class="glass-card mb-4">
    <form method="GET" action="quests.php" class="row g-2 g-md-3 align-items-center">
        <div class="col-12 col-md-6 col-lg-4 col-xxl-3">
            <div class="position-relative">
                <input type="text" 
                       name="search" 
                       class="form-control-gaming ps-5" 
                       placeholder="Search title, description, location..." 
                       value="<?= e($search) ?>">
                <i class="fas fa-search position-absolute text-muted" style="left: 16px; top: 50%; transform: translateY(-50%);"></i>
            </div>
        </div>

        <div class="col-6 col-sm-6 col-md-3 col-lg-2 col-xxl-2">
            <select name="category" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $category === 'all' ? 'selected' : '' ?>>All Categories</option>
                <option value="exploration" <?= $category === 'exploration' ? 'selected' : '' ?>>Exploration</option>
                <option value="fitness" <?= $category === 'fitness' ? 'selected' : '' ?>>Fitness</option>
                <option value="creativity" <?= $category === 'creativity' ? 'selected' : '' ?>>Creativity</option>
                <option value="intellect" <?= $category === 'intellect' ? 'selected' : '' ?>>Intellect</option>
                <option value="social" <?= $category === 'social' ? 'selected' : '' ?>>Social</option>
            </select>
        </div>

        <div class="col-6 col-sm-6 col-md-3 col-lg-2 col-xxl-2">
            <select name="difficulty" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $difficulty === 'all' ? 'selected' : '' ?>>All Difficulties</option>
                <option value="easy" <?= $difficulty === 'easy' ? 'selected' : '' ?>>Easy</option>
                <option value="medium" <?= $difficulty === 'medium' ? 'selected' : '' ?>>Medium</option>
                <option value="hard" <?= $difficulty === 'hard' ? 'selected' : '' ?>>Hard</option>
                <option value="legendary" <?= $difficulty === 'legendary' ? 'selected' : '' ?>>Legendary</option>
            </select>
        </div>

        <div class="col-6 col-sm-6 col-md-3 col-lg-2 col-xxl-2">
            <select name="verification_type" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $vtype === 'all' ? 'selected' : '' ?>>All Verifications</option>
                <option value="locationGps" <?= $vtype === 'locationGps' ? 'selected' : '' ?>>GPS Location</option>
                <option value="photo" <?= $vtype === 'photo' ? 'selected' : '' ?>>Photo</option>
                <option value="drawing" <?= $vtype === 'drawing' ? 'selected' : '' ?>>Drawing Canvas</option>
                <option value="writing" <?= $vtype === 'writing' ? 'selected' : '' ?>>Writing / Log</option>
                <option value="qrCode" <?= $vtype === 'qrCode' ? 'selected' : '' ?>>QR Code</option>
                <option value="codePhrase" <?= $vtype === 'codePhrase' ? 'selected' : '' ?>>Code Phrase</option>
            </select>
        </div>

        <div class="col-6 col-sm-6 col-md-3 col-lg-2 col-xxl-2">
            <select name="status" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $status === 'all' ? 'selected' : '' ?>>All Statuses</option>
                <option value="active" <?= $status === 'active' ? 'selected' : '' ?>>Active Quests</option>
                <option value="inactive" <?= $status === 'inactive' ? 'selected' : '' ?>>Inactive Quests</option>
            </select>
        </div>

        <div class="col-12 col-sm-12 col-md-6 col-lg-2 col-xxl-1">
            <div class="d-flex gap-2">
                <button type="submit" class="btn btn-gaming btn-gaming-cyan w-100" title="Apply Filters">
                    <i class="fas fa-filter"></i>
                </button>
                <?php if ($search !== '' || $category !== 'all' || $difficulty !== 'all' || $vtype !== 'all' || $status !== 'all'): ?>
                    <a href="quests.php" class="btn btn-gaming btn-gaming-outline" title="Reset Filters">
                        <i class="fas fa-redo"></i>
                    </a>
                <?php endif; ?>
            </div>
        </div>
    </form>
</div>

<!-- Quests Grid / List -->
<div class="glass-card">
    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th>Quest Title</th>
                    <th>Category</th>
                    <th>Difficulty</th>
                    <th>Verification</th>
                    <th>Location & Coordinates</th>
                    <th>Rewards</th>
                    <th>Completions</th>
                    <th>Status</th>
                    <th class="text-end table-actions-cell">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($quests)): ?>
                    <tr>
                        <td colspan="9" class="text-center py-5 text-muted">
                            <i class="fas fa-map-signs fs-2 mb-2 d-block opacity-50"></i>
                            No quests found. <a href="quest_add.php" class="text-cyan">Create your first quest</a>.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($quests as $q): ?>
                        <tr>
                            <td>
                                <a href="quest_view.php?id=<?= urlencode($q['id']) ?>" class="fw-bold text-light text-decoration-none hover-cyan">
                                    <?= e($q['title']) ?>
                                </a>
                                <div class="small text-muted text-truncate" style="max-width: 180px;">
                                    <?= e($q['description']) ?>
                                </div>
                            </td>
                            <td><?= get_category_badge($q['category'] ?? 'exploration') ?></td>
                            <td><?= get_difficulty_badge($q['difficulty'] ?? 'medium') ?></td>
                            <td><?= get_verification_badge($q['verification_type'] ?? 'locationGps') ?></td>
                            <td>
                                <div class="fw-semibold small text-truncate" style="max-width: 140px;"><i class="fas fa-map-pin text-cyan me-1"></i><?= e($q['location_name'] ?? 'Local Area') ?></div>
                                <div class="small text-muted font-monospace" style="font-size: 0.72rem;">
                                    <?= number_format((float)$q['latitude'], 4) ?>, <?= number_format((float)$q['longitude'], 4) ?> (±<?= (int)$q['radius_meters'] ?>m)
                                </div>
                            </td>
                            <td>
                                <span class="text-cyan fw-bold">+<?= (int)$q['xp_reward'] ?> XP</span><br>
                                <span class="text-gold small fw-bold">+<?= (int)$q['coins_reward'] ?> Coins</span>
                            </td>
                            <td>
                                <span class="badge bg-dark border border-secondary text-secondary">
                                    <i class="fas fa-users me-1"></i><?= (int)$q['completions_count'] ?>
                                </span>
                            </td>
                            <td><?= get_status_badge((int)$q['is_active']) ?></td>
                            <td class="text-end table-actions-cell">
                                <div class="d-inline-flex gap-1 justify-content-end">
                                    <a href="quest_view.php?id=<?= urlencode($q['id']) ?>" class="btn-action-icon" title="View Quest Details">
                                        <i class="fas fa-eye"></i>
                                    </a>
                                    <a href="quest_edit.php?id=<?= urlencode($q['id']) ?>" class="btn-action-icon" title="Edit Quest">
                                        <i class="fas fa-edit text-cyan"></i>
                                    </a>
                                    <form method="POST" action="../actions/quest_actions.php" class="d-inline">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="duplicate_quest">
                                        <input type="hidden" name="quest_id" value="<?= e($q['id']) ?>">
                                        <button type="submit" class="btn-action-icon" title="Duplicate Quest">
                                            <i class="fas fa-clone text-purple"></i>
                                        </button>
                                    </form>
                                    <form method="POST" action="../actions/quest_actions.php" class="d-inline">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="toggle_active">
                                        <input type="hidden" name="quest_id" value="<?= e($q['id']) ?>">
                                        <input type="hidden" name="current_status" value="<?= (int)$q['is_active'] ?>">
                                        <button type="submit" class="btn-action-icon" title="<?= (int)$q['is_active'] === 1 ? 'Deactivate' : 'Activate' ?>">
                                            <i class="fas <?= (int)$q['is_active'] === 1 ? 'fa-toggle-on text-success' : 'fa-toggle-off text-muted' ?>"></i>
                                        </button>
                                    </form>
                                    <form method="POST" action="../actions/quest_actions.php" class="d-inline" onsubmit="return confirm('Are you sure you want to delete quest: <?= e($q['title']) ?>?');">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="action" value="delete_quest">
                                        <input type="hidden" name="quest_id" value="<?= e($q['id']) ?>">
                                        <button type="submit" class="btn-action-icon text-danger" title="Delete Quest">
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
                        <a class="page-link bg-dark text-secondary border-secondary" href="?page=<?= $page - 1 ?>&search=<?= urlencode($search) ?>&category=<?= urlencode($category) ?>&difficulty=<?= urlencode($difficulty) ?>&verification_type=<?= urlencode($vtype) ?>&status=<?= urlencode($status) ?>">Previous</a>
                    </li>
                    <?php for ($i = max(1, $page - 2); $i <= min($totalPages, $page + 2); $i++): ?>
                        <li class="page-item <?= $i === $page ? 'active' : '' ?>">
                            <a class="page-link <?= $i === $page ? 'bg-info border-info text-dark fw-bold' : 'bg-dark text-secondary border-secondary' ?>" 
                               href="?page=<?= $i ?>&search=<?= urlencode($search) ?>&category=<?= urlencode($category) ?>&difficulty=<?= urlencode($difficulty) ?>&verification_type=<?= urlencode($vtype) ?>&status=<?= urlencode($status) ?>"><?= $i ?></a>
                        </li>
                    <?php endfor; ?>
                    <li class="page-item <?= $page >= $totalPages ? 'disabled' : '' ?>">
                        <a class="page-link bg-dark text-secondary border-secondary" href="?page=<?= $page + 1 ?>&search=<?= urlencode($search) ?>&category=<?= urlencode($category) ?>&difficulty=<?= urlencode($difficulty) ?>&verification_type=<?= urlencode($vtype) ?>&status=<?= urlencode($status) ?>">Next</a>
                    </li>
                </ul>
            </nav>
        </div>
    <?php endif; ?>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
