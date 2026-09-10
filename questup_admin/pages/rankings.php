<?php
/**
 * QuestUP Admin - Real-Time Rankings & Leaderboard
 */

declare(strict_types=1);

$pageTitle = 'Global Hall of Fame & Rankings';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Fetch rankings ordered by Level DESC, then XP DESC
$stmt = $db->query("
    SELECT u.id, u.name, u.email, u.status,
           COALESCE(p.level, 1) as level,
           COALESCE(p.current_xp, 0) as current_xp,
           COALESCE(p.coins, 100) as coins,
           (SELECT COUNT(*) FROM quest_completions WHERE user_id = u.id) as quests_won,
           (SELECT COUNT(*) FROM user_badges WHERE user_id = u.id) as badges_count
    FROM users u
    LEFT JOIN user_profiles p ON u.id = p.user_id
    WHERE u.status = 'active' OR u.status IS NULL
    ORDER BY level DESC, current_xp DESC, quests_won DESC
    LIMIT 100
");
$players = $stmt->fetchAll();

$top1 = $players[0] ?? null;
$top2 = $players[1] ?? null;
$top3 = $players[2] ?? null;
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h2 class="display-font fs-3 mb-0">Global Explorer Leaderboard</h2>
        <p class="text-secondary small mb-0">Live player hierarchy computed directly from level and XP progression</p>
    </div>
    <div class="text-muted small">
        <i class="fas fa-sync text-cyan me-1"></i> Live Real-Time Data
    </div>
</div>

<!-- Top 3 Podium -->
<?php if ($top1 !== null): ?>
    <div class="podium-container">
        <!-- 2nd Place (Silver) -->
        <div class="podium-place second">
            <?php if ($top2): ?>
                <div class="podium-avatar-wrapper">
                    <i class="fas fa-crown podium-crown"></i>
                    <div class="podium-avatar">
                        <?= strtoupper(substr($top2['name'] ?? '2', 0, 1)) ?>
                    </div>
                </div>
                <div class="fw-bold text-light fs-5"><?= e($top2['name']) ?></div>
                <div class="badge bg-secondary mb-2">Level <?= (int)$top2['level'] ?></div>
                <div class="small text-cyan mb-2"><?= format_number((int)$top2['current_xp']) ?> XP</div>
                <div class="podium-bar">
                    <div class="podium-rank-tag" style="color: #cbd5e1;">#2</div>
                    <div class="small text-muted">Silver Explorer</div>
                </div>
            <?php else: ?>
                <div class="podium-bar text-muted d-flex align-items-center justify-content-center">Empty Rank</div>
            <?php endif; ?>
        </div>

        <!-- 1st Place (Gold Champion) -->
        <div class="podium-place first">
            <div class="podium-avatar-wrapper">
                <i class="fas fa-crown podium-crown"></i>
                <div class="podium-avatar">
                    <?= strtoupper(substr($top1['name'] ?? '1', 0, 1)) ?>
                </div>
            </div>
            <div class="fw-bold text-gold fs-4"><?= e($top1['name']) ?></div>
            <div class="badge bg-warning text-dark fw-bold mb-2">Level <?= (int)$top1['level'] ?> Champion</div>
            <div class="text-cyan fw-bold mb-2"><?= format_number((int)$top1['current_xp']) ?> XP</div>
            <div class="podium-bar">
                <div class="podium-rank-tag text-gold">#1</div>
                <div class="small text-gold fw-semibold">Grand Champion</div>
            </div>
        </div>

        <!-- 3rd Place (Bronze) -->
        <div class="podium-place third">
            <?php if ($top3): ?>
                <div class="podium-avatar-wrapper">
                    <i class="fas fa-crown podium-crown"></i>
                    <div class="podium-avatar">
                        <?= strtoupper(substr($top3['name'] ?? '3', 0, 1)) ?>
                    </div>
                </div>
                <div class="fw-bold text-light fs-5"><?= e($top3['name']) ?></div>
                <div class="badge bg-secondary mb-2">Level <?= (int)$top3['level'] ?></div>
                <div class="small text-cyan mb-2"><?= format_number((int)$top3['current_xp']) ?> XP</div>
                <div class="podium-bar">
                    <div class="podium-rank-tag" style="color: #cd7f32;">#3</div>
                    <div class="small text-muted">Bronze Explorer</div>
                </div>
            <?php else: ?>
                <div class="podium-bar text-muted d-flex align-items-center justify-content-center">Empty Rank</div>
            <?php endif; ?>
        </div>
    </div>
<?php endif; ?>

<!-- Full Rankings Table -->
<div class="glass-card">
    <div class="card-header-clean">
        <h3 class="card-title-clean">
            <i class="fas fa-list-ol text-cyan"></i>
            <span>Complete Global Standings (Top 100)</span>
        </h3>
    </div>

    <div class="table-responsive">
        <table class="table-custom">
            <thead>
                <tr>
                    <th style="width: 80px;">Rank</th>
                    <th>Explorer</th>
                    <th>Level</th>
                    <th>Current XP</th>
                    <th>Gold Coins</th>
                    <th>Quests Won</th>
                    <th>Badges Earned</th>
                    <th class="text-end">Profile</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($players)): ?>
                    <tr>
                        <td colspan="8" class="text-center py-5 text-muted">
                            <i class="fas fa-trophy fs-2 mb-2 d-block opacity-50"></i>
                            No player records found.
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($players as $index => $p): ?>
                        <?php
                        $rank = $index + 1;
                        $rankBadge = match ($rank) {
                            1 => '<span class="badge bg-warning text-dark fw-bold px-2 py-1"><i class="fas fa-crown me-1"></i>#1</span>',
                            2 => '<span class="badge px-2 py-1" style="background: #cbd5e1; color: #0a0e17; font-weight: bold;">#2</span>',
                            3 => '<span class="badge px-2 py-1" style="background: #cd7f32; color: #ffffff; font-weight: bold;">#3</span>',
                            default => '<span class="text-secondary fw-bold">#' . $rank . '</span>',
                        };
                        ?>
                        <tr>
                            <td><?= $rankBadge ?></td>
                            <td>
                                <a href="user_view.php?id=<?= urlencode($p['id']) ?>" class="fw-bold text-light text-decoration-none hover-cyan">
                                    <?= e($p['name'] ?? 'Adventurer') ?>
                                </a>
                                <div class="small text-secondary"><?= e($p['email']) ?></div>
                            </td>
                            <td>
                                <span class="badge bg-info bg-opacity-25 text-cyan border border-info border-opacity-25">Level <?= (int)$p['level'] ?></span>
                            </td>
                            <td>
                                <span class="text-cyan fw-bold"><?= format_number((int)$p['current_xp']) ?> XP</span>
                            </td>
                            <td>
                                <span class="text-gold fw-bold"><i class="fas fa-coins me-1"></i><?= format_number((int)$p['coins']) ?></span>
                            </td>
                            <td>
                                <span class="badge bg-success bg-opacity-25 text-success border border-success border-opacity-25">
                                    <i class="fas fa-trophy me-1"></i><?= (int)$p['quests_won'] ?>
                                </span>
                            </td>
                            <td>
                                <span class="badge bg-purple bg-opacity-25 text-purple border border-purple border-opacity-25">
                                    <i class="fas fa-medal me-1"></i><?= (int)$p['badges_count'] ?>
                                </span>
                            </td>
                            <td class="text-end">
                                <a href="user_view.php?id=<?= urlencode($p['id']) ?>" class="btn-action-icon" title="View Dossier">
                                    <i class="fas fa-eye text-cyan"></i>
                                </a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
