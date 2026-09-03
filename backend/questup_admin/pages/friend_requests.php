<?php
/**
 * QuestUP Admin - Friend Requests & Social Management
 */

declare(strict_types=1);

$pageTitle = 'Player Connections & Friend Requests';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Filter & Search Parameters
$search = trim($_GET['search'] ?? '');
$statusFilter = trim($_GET['status'] ?? 'all');

$page = max(1, (int)($_GET['page'] ?? 1));
$limit = 15;
$offset = ($page - 1) * $limit;

// Build Query
$where = [];
$params = [];

if ($search !== '') {
    $where[] = "(r.sender_tag LIKE :s1 OR r.receiver_tag LIKE :s2 OR u1.name LIKE :s3 OR u2.name LIKE :s4)";
    $params['s1'] = '%' . $search . '%';
    $params['s2'] = '%' . $search . '%';
    $params['s3'] = '%' . $search . '%';
    $params['s4'] = '%' . $search . '%';
}

if ($statusFilter !== 'all' && in_array($statusFilter, ['pending', 'accepted', 'rejected', 'cancelled'])) {
    $where[] = "r.status = :status";
    $params['status'] = $statusFilter;
}

$whereSql = !empty($where) ? 'WHERE ' . implode(' AND ', $where) : '';

// Count Query
$countQuery = "
    SELECT COUNT(*) as total
    FROM friend_requests r
    JOIN users u1 ON r.sender_id = u1.id
    JOIN users u2 ON r.receiver_id = u2.id
    $whereSql
";
$stmt = $db->prepare($countQuery);
$stmt->execute($params);
$totalRecords = (int)($stmt->fetch()['total'] ?? 0);
$totalPages = max(1, (int)ceil($totalRecords / $limit));

// Fetch Data
$dataQuery = "
    SELECT r.*,
           u1.name as sender_name, u1.email as sender_email,
           u2.name as receiver_name, u2.email as receiver_email
    FROM friend_requests r
    JOIN users u1 ON r.sender_id = u1.id
    JOIN users u2 ON r.receiver_id = u2.id
    $whereSql
    ORDER BY r.created_at DESC
    LIMIT $limit OFFSET $offset
";
$stmt = $db->prepare($dataQuery);
$stmt->execute($params);
$requests = $stmt->fetchAll();
?>

<div class="glass-card mb-4">
    <form method="GET" action="friend_requests.php" class="row g-3 align-items-center">
        <div class="col-lg-5 col-md-6">
            <div class="position-relative">
                <input type="text" 
                       name="search" 
                       class="form-control-gaming ps-5" 
                       placeholder="Search by Player Tag (e.g. QST-1108) or Explorer name..." 
                       value="<?= e($search) ?>">
                <i class="fas fa-search position-absolute text-muted" style="left: 16px; top: 50%; transform: translateY(-50%);"></i>
            </div>
        </div>

        <div class="col-lg-3 col-md-4">
            <select name="status" class="form-control-gaming" onchange="this.form.submit()">
                <option value="all" <?= $statusFilter === 'all' ? 'selected' : '' ?>>All Statuses</option>
                <option value="pending" <?= $statusFilter === 'pending' ? 'selected' : '' ?>>Pending Only</option>
                <option value="accepted" <?= $statusFilter === 'accepted' ? 'selected' : '' ?>>Accepted Only</option>
                <option value="rejected" <?= $statusFilter === 'rejected' ? 'selected' : '' ?>>Rejected Only</option>
            </select>
        </div>

        <div class="col-lg-4 col-md-2 text-lg-end text-muted small">
            Found <strong><?= number_format($totalRecords) ?></strong> friend requests
        </div>
    </form>
</div>

<div class="glass-card">
    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th>Sender (Player Tag)</th>
                    <th>Receiver (Player Tag)</th>
                    <th>Status</th>
                    <th>Sent At</th>
                    <th>Updated At</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($requests)): ?>
                    <tr>
                        <td colspan="5" class="text-center py-5 text-muted">
                            <i class="fas fa-user-friends fs-2 mb-2 d-block opacity-50"></i>
                            No friend requests recorded matching the criteria.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($requests as $r): ?>
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="admin-avatar" style="width: 32px; height: 32px; font-size: 0.8rem;">
                                        <?= strtoupper(substr($r['sender_name'] ?? 'U', 0, 1)) ?>
                                    </div>
                                    <div>
                                        <div class="fw-bold text-light"><?= e($r['sender_name']) ?></div>
                                        <span class="badge bg-primary text-dark font-monospace fw-bold px-2 py-0" style="font-size: 0.75rem;">
                                            <?= e($r['sender_tag']) ?>
                                        </span>
                                    </div>
                                </div>
                            </td>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="admin-avatar" style="width: 32px; height: 32px; font-size: 0.8rem;">
                                        <?= strtoupper(substr($r['receiver_name'] ?? 'U', 0, 1)) ?>
                                    </div>
                                    <div>
                                        <div class="fw-bold text-light"><?= e($r['receiver_name']) ?></div>
                                        <span class="badge bg-warning text-dark font-monospace fw-bold px-2 py-0" style="font-size: 0.75rem;">
                                            <?= e($r['receiver_tag']) ?>
                                        </span>
                                    </div>
                                </div>
                            </td>
                            <td>
                                <?php if ($r['status'] === 'accepted'): ?>
                                    <span class="badge bg-success-subtle text-success border border-success-subtle">
                                        <i class="fas fa-check-circle me-1"></i> Accepted
                                    </span>
                                <?php elseif ($r['status'] === 'pending'): ?>
                                    <span class="badge bg-warning-subtle text-warning border border-warning-subtle">
                                        <i class="fas fa-clock me-1"></i> Pending
                                    </span>
                                <?php else: ?>
                                    <span class="badge bg-danger-subtle text-danger border border-danger-subtle">
                                        <i class="fas fa-times-circle me-1"></i> <?= ucfirst(e($r['status'])) ?>
                                    </span>
                                <?php endif; ?>
                            </td>
                            <td class="text-secondary small">
                                <?= date('M j, Y H:i', strtotime($r['created_at'])) ?>
                            </td>
                            <td class="text-secondary small">
                                <?= $r['updated_at'] ? date('M j, Y H:i', strtotime($r['updated_at'])) : '—' ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php
require_once __DIR__ . '/../includes/footer.php';
