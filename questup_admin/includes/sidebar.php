<?php
/**
 * QuestUP Admin - Sidebar Include
 */

declare(strict_types=1);

$currentPage = basename($_SERVER['SCRIPT_NAME']);
$currentDir = basename(dirname($_SERVER['SCRIPT_NAME']));

function is_active_nav(string $pageName): string {
    global $currentPage;
    return ($currentPage === $pageName) ? 'active' : '';
}

// Fetch pending verifications count for badge
$pendingVerifCount = 0;
try {
    $db = db();
    $verifStmt = $db->query("SELECT COUNT(*) as total FROM quest_completions WHERE status = 'pending'");
    $pendingVerifCount = (int)($verifStmt->fetch()['total'] ?? 0);
} catch (Throwable $_) {}
?>
<aside class="admin-sidebar" id="adminSidebar">
    <div class="sidebar-header">
        <img src="<?= $baseUrl ?>assets/images/logo_emblem.png" alt="QuestUP" class="sidebar-logo">
        <div>
            <div class="sidebar-brand-title">QuestUP</div>
            <span class="sidebar-brand-sub">Admin Portal</span>
        </div>
        <button class="btn btn-link text-secondary d-lg-none ms-auto" id="sidebarCloseBtn" aria-label="Close sidebar">
            <i class="fas fa-times fs-5"></i>
        </button>
    </div>

    <ul class="sidebar-menu">
        <li class="menu-category-title">Core Management</li>
        
        <li class="menu-item">
            <a href="<?= $baseUrl ?>dashboard.php" class="menu-link <?= is_active_nav('dashboard.php') ?>">
                <i class="fas fa-th-large"></i>
                <span>Dashboard</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/users.php" class="menu-link <?= is_active_nav('users.php') || is_active_nav('user_view.php') || is_active_nav('user_edit.php') ?>">
                <i class="fas fa-users"></i>
                <span>Users</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/quests.php" class="menu-link <?= is_active_nav('quests.php') || is_active_nav('quest_add.php') || is_active_nav('quest_edit.php') || is_active_nav('quest_view.php') ?>">
                <i class="fas fa-map-marked-alt"></i>
                <span>Quests</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/completions.php" class="menu-link <?= is_active_nav('completions.php') ?>">
                <i class="fas fa-check-double"></i>
                <span>Completions</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/verification.php" class="menu-link <?= is_active_nav('verification.php') ?>">
                <i class="fas fa-shield-alt"></i>
                <span>Verification</span>
                <?php if ($pendingVerifCount > 0): ?>
                    <span class="badge bg-danger rounded-pill ms-auto"><?= $pendingVerifCount ?></span>
                <?php endif; ?>
            </a>
        </li>

        <li class="menu-category-title">Gamification & Social</li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/rankings.php" class="menu-link <?= is_active_nav('rankings.php') ?>">
                <i class="fas fa-trophy"></i>
                <span>Rankings</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/badges.php" class="menu-link <?= is_active_nav('badges.php') ?>">
                <i class="fas fa-medal"></i>
                <span>Badges</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/friend_requests.php" class="menu-link <?= is_active_nav('friend_requests.php') ?>">
                <i class="fas fa-user-friends"></i>
                <span>Friend Requests</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/notifications.php" class="menu-link <?= is_active_nav('notifications.php') ?>">
                <i class="fas fa-bell"></i>
                <span>Notifications</span>
            </a>
        </li>

        <li class="menu-category-title">Analytics & System</li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/reports.php" class="menu-link <?= is_active_nav('reports.php') ?>">
                <i class="fas fa-chart-line"></i>
                <span>Reports</span>
            </a>
        </li>

        <li class="menu-item">
            <a href="<?= $baseUrl ?>pages/settings.php" class="menu-link <?= is_active_nav('settings.php') ?>">
                <i class="fas fa-cog"></i>
                <span>Settings</span>
            </a>
        </li>
    </ul>

    <div class="sidebar-footer">
        <div class="admin-mini-profile">
            <div class="admin-avatar">
                <?= strtoupper(substr($currentAdmin['full_name'] ?? 'A', 0, 1)) ?>
            </div>
            <div class="flex-grow-1 overflow-hidden">
                <div class="fw-bold text-truncate" style="font-size: 0.88rem;"><?= e($currentAdmin['full_name'] ?? 'Admin') ?></div>
                <div class="text-muted" style="font-size: 0.75rem;"><?= e($currentAdmin['role'] ?? 'superadmin') ?></div>
            </div>
            <a href="<?= $baseUrl ?>logout.php" class="text-danger ms-auto" title="Sign Out" onclick="return confirm('Are you sure you want to log out?');">
                <i class="fas fa-sign-out-alt fs-5"></i>
            </a>
        </div>
    </div>
</aside>
