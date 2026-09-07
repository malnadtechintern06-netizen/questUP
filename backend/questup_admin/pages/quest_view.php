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
            <p class="text-secondary mb-3"><?= nl2br(e($quest['description'])) ?></p>

            <?php if (!empty($quest['storyline'])): ?>
            <div class="p-3 mb-3 rounded" style="background: rgba(138, 43, 226, 0.1); border-left: 3px solid var(--neon-purple);">
                <div class="small text-purple fw-bold mb-1"><i class="fas fa-scroll me-1"></i> Quest Lore & Storyline</div>
                <div class="small text-light fst-italic"><?= nl2br(e($quest['storyline'])) ?></div>
            </div>
            <?php endif; ?>

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

            <!-- Dynamic Verification Parameters Display -->
            <div class="p-3 rounded small mb-3" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                <div class="mb-2"><strong>Verification Mode:</strong> <?= get_verification_badge($quest['verification_type'] ?? 'locationGps') ?></div>
                
                <?php if (!empty($quest['required_object'])): ?>
                <div class="mb-1"><i class="fas fa-camera text-cyan me-1"></i><strong>Target Object:</strong> <span class="badge bg-cyan text-dark"><?= e($quest['required_object']) ?></span></div>
                <?php endif; ?>

                <?php if (!empty($quest['required_drawing_subject'])): ?>
                <div class="mb-1"><i class="fas fa-paint-brush text-purple me-1"></i><strong>Drawing Target:</strong> <span class="badge bg-purple text-light"><?= e($quest['required_drawing_subject']) ?></span></div>
                <?php endif; ?>

                <?php if (!empty($quest['required_words'])): ?>
                <div class="mb-1"><i class="fas fa-file-alt text-gold me-1"></i><strong>Min Words:</strong> <?= (int)$quest['required_words'] ?> words</div>
                <?php endif; ?>

                <?php if (!empty($quest['required_duration_seconds'])): ?>
                <div class="mb-1"><i class="fas fa-stopwatch text-success me-1"></i><strong>Duration:</strong> <?= (int)$quest['required_duration_seconds'] ?>s (<?= round((int)$quest['required_duration_seconds']/60, 1) ?> min)</div>
                <?php endif; ?>

                <?php if (!empty($quest['required_distance_meters'])): ?>
                <div class="mb-1"><i class="fas fa-running text-info me-1"></i><strong>Distance:</strong> <?= (float)$quest['required_distance_meters'] ?>m</div>
                <?php endif; ?>

                <div class="mb-1"><strong>Location:</strong> <i class="fas fa-map-pin text-cyan ms-1 me-1"></i><?= e($quest['location_name'] ?? 'Local') ?> (<?= e($quest['place_type'] ?? 'landmark') ?>)</div>
                <div class="mb-1"><strong>Icon Key:</strong> <code><?= e($quest['icon_key'] ?? 'landmark') ?></code></div>
                <div><strong>UUID:</strong> <span class="font-monospace text-muted"><?= e($quest['id']) ?></span></div>
            </div>

            <!-- Active Rules Badges -->
            <div class="d-flex flex-wrap gap-1">
                <?php if (!empty($quest['requires_gps'])): ?><span class="badge bg-dark border border-secondary text-cyan"><i class="fas fa-satellite me-1"></i>GPS Check</span><?php endif; ?>
                <?php if (!empty($quest['requires_photo'])): ?><span class="badge bg-dark border border-secondary text-warning"><i class="fas fa-camera me-1"></i>Photo Proof</span><?php endif; ?>
                <?php if (!empty($quest['requires_fresh_photo'])): ?><span class="badge bg-dark border border-secondary text-danger"><i class="fas fa-shield-alt me-1"></i>No Gallery</span><?php endif; ?>
                <?php if (!empty($quest['requires_drawing'])): ?><span class="badge bg-dark border border-secondary text-purple"><i class="fas fa-palette me-1"></i>Drawing</span><?php endif; ?>
                <?php if (!empty($quest['requires_text'])): ?><span class="badge bg-dark border border-secondary text-gold"><i class="fas fa-pen me-1"></i>Text Log</span><?php endif; ?>
                <?php if (!empty($quest['requires_video'])): ?><span class="badge bg-dark border border-secondary text-info"><i class="fas fa-video me-1"></i>Video</span><?php endif; ?>
                <?php if (!empty($quest['requires_game_session'])): ?><span class="badge bg-dark border border-secondary text-success"><i class="fas fa-gamepad me-1"></i>Game</span><?php endif; ?>
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
