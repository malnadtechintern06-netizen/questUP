<?php
/**
 * QuestUP Admin - View Quest Details & Completion Log
 */

declare(strict_types=1);

$questId = trim($_GET['id'] ?? '');
if (empty($questId)) {
    header('Location: quests.php');
    exit;
}

$pageTitle = 'Quest Blueprint';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Fetch Quest
$stmt = $db->prepare("SELECT * FROM quests WHERE id = :id LIMIT 1");
$stmt->execute(['id' => $questId]);
$quest = $stmt->fetch();

if (!$quest) {
    echo '<div class="alert alert-danger">Quest record not found. <a href="quests.php">Back to Quests</a></div>';
    require_once __DIR__ . '/../includes/footer.php';
    exit;
}

// Fetch Completions for this quest
$stmt = $db->prepare("
    SELECT c.*, u.name as user_name, u.email as user_email
    FROM quest_completions c
    LEFT JOIN users u ON c.user_id = u.id
    WHERE c.quest_id = :id
    ORDER BY c.completed_at DESC
");
$stmt->execute(['id' => $questId]);
$completions = $stmt->fetchAll();

$lat = (float)($quest['latitude'] ?? 12.971598);
$lng = (float)($quest['longitude'] ?? 77.594566);
$rad = (float)($quest['radius_meters'] ?? 150.0);
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <a href="quests.php" class="text-secondary small text-decoration-none mb-1 d-inline-block">
            <i class="fas fa-arrow-left me-1"></i> Back to Quests Catalog
        </a>
        <h2 class="display-font fs-3 mb-0"><?= e($quest['title']) ?></h2>
    </div>
    <div class="d-flex gap-2">
        <a href="quest_edit.php?id=<?= urlencode($quest['id']) ?>" class="btn btn-gaming btn-gaming-cyan">
            <i class="fas fa-edit me-1"></i> Edit Quest
        </a>
    </div>
</div>

<div class="row g-4 mb-4">
    <!-- Quest Metadata & Rewards -->
    <div class="col-lg-6">
        <div class="glass-card mb-4">
            <div class="d-flex justify-content-between align-items-center mb-3">
                <div class="d-flex gap-2">
                    <?= get_category_badge($quest['category'] ?? 'exploration') ?>
                    <?= get_difficulty_badge($quest['difficulty'] ?? 'medium') ?>
                </div>
                <?= get_status_badge((int)$quest['is_active']) ?>
            </div>

            <h3 class="fs-4 mb-2"><?= e($quest['title']) ?></h3>
            <p class="text-secondary mb-4"><?= nl2br(e($quest['description'])) ?></p>

            <div class="row g-3 text-center mb-3">
                <div class="col-4">
                    <div class="p-3 rounded" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                        <div class="text-cyan fw-bold fs-4">+<?= (int)$quest['xp_reward'] ?></div>
                        <div class="text-muted small">XP Reward</div>
                    </div>
                </div>
                <div class="col-4">
                    <div class="p-3 rounded" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                        <div class="text-gold fw-bold fs-4">+<?= (int)$quest['coins_reward'] ?></div>
                        <div class="text-muted small">Coin Bounty</div>
                    </div>
                </div>
                <div class="col-4">
                    <div class="p-3 rounded" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                        <div class="text-success fw-bold fs-4"><?= count($completions) ?></div>
                        <div class="text-muted small">Total Clears</div>
                    </div>
                </div>
            </div>

            <div class="p-3 rounded small" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                <div class="mb-2"><strong>Verification:</strong> <?= get_verification_badge($quest['verification_type'] ?? 'locationGps') ?></div>
                <div class="mb-1"><strong>Location:</strong> <i class="fas fa-map-pin text-cyan ms-1 me-1"></i><?= e($quest['location_name'] ?? 'Local') ?> (<?= e($quest['place_type'] ?? 'landmark') ?>)</div>
                <div><strong>UUID:</strong> <span class="font-monospace text-muted"><?= e($quest['id']) ?></span></div>
            </div>
        </div>
    </div>

    <!-- Map Geofence Radar Preview -->
    <div class="col-lg-6">
        <div class="glass-card mb-4 h-100">
            <h3 class="fs-5 text-purple border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                <i class="fas fa-satellite-dish me-2"></i> Radar Geofence Area (<?= (int)$rad ?>m Radius)
            </h3>
            <div id="map-viewer" style="height: 300px;"></div>
            <div class="mt-3 text-secondary small d-flex justify-content-between">
                <span>Lat: <strong class="text-light"><?= $lat ?></strong>, Lng: <strong class="text-light"><?= $lng ?></strong></span>
                <span>Radius: <strong class="text-cyan"><?= (int)$rad ?> meters</strong></span>
            </div>
        </div>
    </div>
</div>

<!-- Completions Table for this Quest -->
<div class="glass-card">
    <div class="card-header-clean">
        <h3 class="card-title-clean">
            <i class="fas fa-users-cog text-cyan"></i>
            <span>Adventurers Who Conquered This Quest (<?= count($completions) ?>)</span>
        </h3>
    </div>

    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th>Explorer</th>
                    <th>Rewards Won</th>
                    <th>Status</th>
                    <th>Completed At</th>
                    <th class="text-end">Proof / Review</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($completions)): ?>
                    <tr>
                        <td colspan="5" class="text-center py-5 text-muted">
                            <i class="fas fa-flag-checkered fs-2 mb-2 d-block opacity-50"></i>
                            No adventurer has completed this quest yet.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($completions as $c): ?>
                        <tr>
                            <td>
                                <a href="user_view.php?id=<?= urlencode($c['user_id']) ?>" class="fw-bold text-light text-decoration-none hover-cyan">
                                    <?= e($c['user_name'] ?? 'Explorer') ?>
                                </a>
                                <div class="small text-secondary"><?= e($c['user_email'] ?? $c['user_id']) ?></div>
                            </td>
                            <td>
                                <span class="text-cyan fw-bold">+<?= (int)$c['xp_earned'] ?> XP</span>,
                                <span class="text-gold fw-bold">+<?= (int)$c['coins_earned'] ?> Coins</span>
                            </td>
                            <td><?= get_status_badge($c['status'] ?? 'verified') ?></td>
                            <td class="text-secondary small"><?= date('M j, Y H:i', strtotime($c['completed_at'])) ?></td>
                            <td class="text-end">
                                <a href="verification.php?search=<?= urlencode($c['id']) ?>" class="btn btn-gaming btn-gaming-outline py-1 px-2" style="font-size: 0.78rem;">
                                    <i class="fas fa-search me-1"></i> Inspect
                                </a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php
$extraScripts = <<<HTML
<script>
document.addEventListener('DOMContentLoaded', () => {
    if (typeof L !== 'undefined') {
        const map = L.map('map-viewer').setView([{$lat}, {$lng}], 15);
        L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
            attribution: '&copy; CARTO',
            maxZoom: 19
        }).addTo(map);

        const questIcon = L.divIcon({
            className: 'custom-map-pin',
            html: '<div style="background: #00e5ff; width: 22px; height: 22px; border-radius: 50%; border: 3px solid #0a0e17; box-shadow: 0 0 14px #00e5ff;"></div>',
            iconSize: [22, 22],
            iconAnchor: [11, 11]
        });

        L.marker([{$lat}, {$lng}], { icon: questIcon }).addTo(map);
        L.circle([{$lat}, {$lng}], {
            radius: {$rad},
            color: '#00e5ff',
            fillColor: '#00e5ff',
            fillOpacity: 0.2,
            weight: 2
        }).addTo(map);
    }
});
</script>
HTML;

require_once __DIR__ . '/../includes/footer.php';
