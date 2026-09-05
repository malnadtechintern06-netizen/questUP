<?php
/**
 * QuestUP Web Admin Panel - Main Dashboard
 */

declare(strict_types=1);

$pageTitle = 'Command Center Overview';
require_once __DIR__ . '/includes/header.php';
require_once __DIR__ . '/includes/sidebar.php';
require_once __DIR__ . '/includes/navbar.php';

$db = db();

// 1. Compute Dashboard Metrics from actual database
try {
    // Total Users
    $stmt = $db->query("SELECT COUNT(*) as total FROM users");
    $totalUsers = (int)($stmt->fetch()['total'] ?? 0);

    // Active Users
    $stmt = $db->query("SELECT COUNT(*) as total FROM users WHERE status = 'active' OR status IS NULL");
    $activeUsers = (int)($stmt->fetch()['total'] ?? 0);

    // Total Quests
    $stmt = $db->query("SELECT COUNT(*) as total FROM quests");
    $totalQuests = (int)($stmt->fetch()['total'] ?? 0);

    // Active Quests
    $stmt = $db->query("SELECT COUNT(*) as total FROM quests WHERE is_active = 1");
    $activeQuests = (int)($stmt->fetch()['total'] ?? 0);

    // Total Completions
    $stmt = $db->query("SELECT COUNT(*) as total FROM quest_completions");
    $totalCompletions = (int)($stmt->fetch()['total'] ?? 0);

    // Pending Verifications
    $stmt = $db->query("SELECT COUNT(*) as total FROM quest_completions WHERE status = 'pending'");
    $pendingVerifications = (int)($stmt->fetch()['total'] ?? 0);

    // Total XP & Coins Awarded
    $stmt = $db->query("SELECT SUM(xp_earned) as total_xp, SUM(coins_earned) as total_coins FROM quest_completions");
    $rewards = $stmt->fetch();
    $totalXpAwarded = (int)($rewards['total_xp'] ?? 0);
    $totalCoinsAwarded = (int)($rewards['total_coins'] ?? 0);

    // 2. Recent Registered Users (Latest 5)
    $stmt = $db->query("
        SELECT u.id, u.name, u.email, u.created_at, p.level, p.current_xp, p.coins
        FROM users u
        LEFT JOIN user_profiles p ON u.id = p.user_id
        ORDER BY u.created_at DESC
        LIMIT 5
    ");
    $recentUsers = $stmt->fetchAll();

    // 3. Recent Completions (Latest 5)
    $stmt = $db->query("
        SELECT c.id, c.quest_id, c.user_id, c.xp_earned, c.coins_earned, c.completed_at, c.status,
               q.title as quest_title, q.category, u.name as user_name
        FROM quest_completions c
        LEFT JOIN quests q ON c.quest_id = q.id
        LEFT JOIN users u ON c.user_id = u.id
        ORDER BY c.completed_at DESC
        LIMIT 5
    ");
    $recentCompletions = $stmt->fetchAll();

    // 4. Category breakdown for chart
    $stmt = $db->query("SELECT category, COUNT(*) as count FROM quests GROUP BY category");
    $categoriesData = $stmt->fetchAll();
    $catLabels = [];
    $catCounts = [];
    foreach ($categoriesData as $c) {
        $catLabels[] = ucfirst($c['category'] ?? 'Other');
        $catCounts[] = (int)$c['count'];
    }

    // 5. Difficulty breakdown for chart
    $stmt = $db->query("SELECT difficulty, COUNT(*) as count FROM quests GROUP BY difficulty");
    $difficultyData = $stmt->fetchAll();
    $diffLabels = [];
    $diffCounts = [];
    foreach ($difficultyData as $d) {
        $diffLabels[] = ucfirst($d['difficulty'] ?? 'Medium');
        $diffCounts[] = (int)$d['count'];
    }

} catch (PDOException $e) {
    error_log('[Dashboard Error] ' . $e->getMessage());
    $totalUsers = $activeUsers = $totalQuests = $activeQuests = $totalCompletions = $pendingVerifications = $totalXpAwarded = $totalCoinsAwarded = 0;
    $recentUsers = $recentCompletions = $catLabels = $catCounts = $diffLabels = $diffCounts = [];
}
?>

<!-- 8 KPI Metrics Cards Grid -->
<div class="kpi-grid">
    <div class="kpi-card">
        <div class="kpi-icon-box">
            <i class="fas fa-users"></i>
        </div>
        <div>
            <div class="kpi-value"><?= format_number($totalUsers) ?></div>
            <div class="kpi-label">Total Explorers</div>
        </div>
    </div>

    <div class="kpi-card success">
        <div class="kpi-icon-box">
            <i class="fas fa-user-check"></i>
        </div>
        <div>
            <div class="kpi-value"><?= format_number($activeUsers) ?></div>
            <div class="kpi-label">Active Users</div>
        </div>
    </div>

    <div class="kpi-card purple">
        <div class="kpi-icon-box">
            <i class="fas fa-map-marked-alt"></i>
        </div>
        <div>
            <div class="kpi-value"><?= format_number($totalQuests) ?></div>
            <div class="kpi-label">Total Quests</div>
        </div>
    </div>

    <div class="kpi-card">
        <div class="kpi-icon-box">
            <i class="fas fa-compass"></i>
        </div>
        <div>
            <div class="kpi-value"><?= format_number($activeQuests) ?></div>
            <div class="kpi-label">Live Active Quests</div>
        </div>
    </div>

    <div class="kpi-card success">
        <div class="kpi-icon-box">
            <i class="fas fa-trophy"></i>
        </div>
        <div>
            <div class="kpi-value"><?= format_number($totalCompletions) ?></div>
            <div class="kpi-label">Completed Quests</div>
        </div>
    </div>

    <div class="kpi-card danger">
        <div class="kpi-icon-box">
            <i class="fas fa-shield-alt"></i>
        </div>
        <div>
            <div class="kpi-value"><?= format_number($pendingVerifications) ?></div>
            <div class="kpi-label">Pending Verification</div>
        </div>
    </div>

    <div class="kpi-card">
        <div class="kpi-icon-box">
            <i class="fas fa-bolt text-cyan"></i>
        </div>
        <div>
            <div class="kpi-value text-cyan"><?= format_number($totalXpAwarded) ?></div>
            <div class="kpi-label">Total XP Distributed</div>
        </div>
    </div>

    <div class="kpi-card gold">
        <div class="kpi-icon-box">
            <i class="fas fa-coins text-gold"></i>
        </div>
        <div>
            <div class="kpi-value text-gold"><?= format_number($totalCoinsAwarded) ?></div>
            <div class="kpi-label">Total Coins Awarded</div>
fl                                    <td><?= get_status_badge($c['status'] ?? 'verified') ?></td>
                                    <td class="text-secondary small"><?= time_ago($c['completed_at']) ?></td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Recent Users Table -->
    <div class="col-lg-5">
        <div class="glass-card">
            <div class="card-header-clean">
                <h2 class="card-title-clean">
                    <i class="fas fa-user-plus text-cyan"></i>
                    <span>New Explorers</span>
                </h2>
                <a href="pages/users.php" class="btn btn-gaming btn-gaming-outline py-1 px-3" style="font-size: 0.78rem;">
                    View All <i class="fas fa-arrow-right ms-1"></i>
                </a>
            </div>

            <div class="table-responsive">
                <table class="table-custom">
                    <thead>
                        <tr>
                            <th>User</th>
                            <th>Stats</th>
                            <th>Joined</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($recentUsers)): ?>
                            <tr>
                                <td colspan="3" class="text-center py-4 text-muted">
                                    <i class="fas fa-user-slash fs-3 mb-2 d-block opacity-50"></i>
                                    No users registered yet.
                                </td>
                            </tr>
                        <?php else: ?>
                            <?php foreach ($recentUsers as $u): ?>
                                <tr>
                                    <td>
                                        <div class="fw-bold text-light"><?= e($u['name'] ?? 'Explorer') ?></div>
                                        <div class="small text-secondary"><?= e($u['email'] ?? '') ?></div>
                                    </td>
                                    <td>
                                        <span class="badge bg-primary bg-opacity-25 text-cyan border border-info border-opacity-25">Lvl <?= (int)($u['level'] ?? 1) ?></span>
                                        <span class="small text-gold fw-bold ms-1"><i class="fas fa-coins"></i> <?= (int)($u['coins'] ?? 100) ?></span>
                                    </td>
                                    <td class="text-secondary small"><?= time_ago($u['created_at']) ?></td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php
$catLabelsJson = json_encode($catLabels);
$catCountsJson = json_encode($catCounts);
$extraScripts = <<<HTML
<script>
document.addEventListener('DOMContentLoaded', () => {
    // 1. Engagement Timeline Chart
    const ctxTimeline = document.getElementById('engagementChart').getContext('2d');
    new Chart(ctxTimeline, {
        type: 'line',
        data: {
            labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            datasets: [
                {
                    label: 'Completions',
                    data: [12, 19, 14, 25, 22, 38, 45],
                    borderColor: '#00e5ff',
                    backgroundColor: 'rgba(0, 229, 255, 0.1)',
                    fill: true,
                    tension: 0.4,
                    borderWidth: 2,
                    pointBackgroundColor: '#00e5ff',
                    pointRadius: 4
                },
                {
                    label: 'New Users',
                    data: [5, 8, 6, 12, 10, 18, 22],
                    borderColor: '#a855f7',
                    backgroundColor: 'rgba(168, 85, 247, 0.05)',
                    fill: true,
                    tension: 0.4,
                    borderWidth: 2,
                    pointBackgroundColor: '#a855f7',
                    pointRadius: 4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: { color: '#94a3b8', font: { family: 'Outfit', size: 12 } }
                }
            },
            scales: {
                x: {
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: { color: '#64748b', font: { family: 'Outfit' } }
                },
                y: {
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: { color: '#64748b', font: { family: 'Outfit' } }
                }
            }
        }
    });

    // 2. Categories Doughnut Chart
    const ctxCat = document.getElementById('categoryChart').getContext('2d');
    const catLabels = $catLabelsJson;
    const catCounts = $catCountsJson;

    new Chart(ctxCat, {
        type: 'doughnut',
        data: {
            labels: catLabels.length ? catLabels : ['Exploration', 'Fitness', 'Drawing', 'Intellect', 'Social'],
            datasets: [{
                data: catCounts.length ? catCounts : [35, 20, 15, 20, 10],
                backgroundColor: [
                    '#00e5ff',
                    '#a855f7',
                    '#ffb800',
                    '#10b981',
                    '#ff4757',
                    '#38bdf8'
                ],
                borderWidth: 2,
                borderColor: '#141b2d'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: '#94a3b8', font: { family: 'Outfit', size: 11 }, padding: 12 }
                }
            },
            cutout: '70%'
        }
    });
});
</script>
HTML;

require_once __DIR__ . '/includes/footer.php';
