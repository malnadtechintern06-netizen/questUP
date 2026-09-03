<?php
/**
 * QuestUP Admin - Navbar Include
 */

declare(strict_types=1);
?>
<div class="admin-main">
    <header class="admin-navbar">
        <div class="d-flex align-items-center gap-3">
            <button class="btn btn-action-icon d-lg-none" id="sidebarToggleBtn" aria-label="Toggle navigation">
                <i class="fas fa-bars"></i>
            </button>
            <h1 class="navbar-page-title">
                <?= e($pageTitle ?? 'Dashboard') ?>
            </h1>
        </div>

        <div class="navbar-actions">
            <!-- Database Connection Health -->
            <?php if (($dbHealth['status'] ?? '') === 'connected'): ?>
                <div class="db-status-pill" title="Connected to <?= e($dbHealth['database']) ?> on <?= e($dbHealth['host']) ?>">
                    <span class="pulse-dot"></span>
                    <span>MySQL: <?= e($dbHealth['database']) ?></span>
                </div>
            <?php else: ?>
                <div class="db-status-pill error" title="<?= e($dbHealth['message'] ?? 'Connection error') ?>">
                    <span class="pulse-dot"></span>
                    <span>MySQL Disconnected</span>
                </div>
            <?php endif; ?>

            <!-- Quick Add Quest Button -->
            <a href="<?= $baseUrl ?>pages/quest_add.php" class="btn btn-gaming btn-gaming-cyan d-none d-sm-inline-flex" style="padding: 7px 14px; font-size: 0.8rem;">
                <i class="fas fa-plus"></i>
                <span>New Quest</span>
            </a>

            <!-- Admin Dropdown Menu -->
            <div class="dropdown">
                <button class="btn btn-action-icon" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                    <i class="fas fa-user-shield text-cyan"></i>
                </button>
                <ul class="dropdown-menu dropdown-menu-dark dropdown-menu-end shadow-lg" style="background: var(--bg-card); border-color: var(--border-bright);">
                    <li class="dropdown-header text-secondary" style="font-size: 0.8rem;">
                        Signed in as <strong><?= e($currentAdmin['username'] ?? 'Admin') ?></strong>
                    </li>
                    <li><hr class="dropdown-divider" style="border-color: var(--border-subtle);"></li>
                    <li>
                        <a class="dropdown-item text-light" href="<?= $baseUrl ?>pages/settings.php">
                            <i class="fas fa-cog me-2 text-cyan"></i> Settings & Password
                        </a>
                    </li>
                    <li>
                        <a class="dropdown-item text-light" href="<?= $baseUrl ?>pages/reports.php">
                            <i class="fas fa-chart-pie me-2 text-purple"></i> Analytics
                        </a>
                    </li>
                    <li><hr class="dropdown-divider" style="border-color: var(--border-subtle);"></li>
                    <li>
                        <a class="dropdown-item text-danger" href="<?= $baseUrl ?>logout.php" onclick="return confirm('Are you sure you want to log out?');">
                            <i class="fas fa-sign-out-alt me-2"></i> Log Out
                        </a>
                    </li>
                </ul>
            </div>
        </div>
    </header>

    <main class="admin-content">
        <?= render_flash() ?>
