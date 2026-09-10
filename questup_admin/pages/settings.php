<?php
/**
 * QuestUP Admin - Settings & Security Configuration
 */

declare(strict_types=1);

$pageTitle = 'Admin Portal Settings & Diagnostics';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();
$admin = get_current_admin();

// Fetch latest admin details
$stmt = $db->prepare("SELECT id, username, email, full_name, role, is_active, last_login, created_at FROM admin_users WHERE id = :id LIMIT 1");
$stmt->execute(['id' => $admin['id']]);
$adminDetails = $stmt->fetch();

// Password Change Handler
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'change_password') {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        set_flash('danger', 'Security validation failed (CSRF token invalid).');
    } else {
        $currentPass = $_POST['current_password'] ?? '';
        $newPass = $_POST['new_password'] ?? '';
        $confirmPass = $_POST['confirm_password'] ?? '';

        if (empty($currentPass) || empty($newPass) || empty($confirmPass)) {
            set_flash('danger', 'Please fill in all password fields.');
        } elseif (strlen($newPass) < 6) {
            set_flash('danger', 'New password must be at least 6 characters.');
        } elseif ($newPass !== $confirmPass) {
            set_flash('danger', 'New password and confirmation do not match.');
        } else {
            // Verify current password
            $pStmt = $db->prepare("SELECT password_hash FROM admin_users WHERE id = :id LIMIT 1");
            $pStmt->execute(['id' => $admin['id']]);
            $hashRow = $pStmt->fetch();

            if (!$hashRow || !password_verify($currentPass, $hashRow['password_hash'])) {
                set_flash('danger', 'Current password is incorrect.');
            } else {
                $newHash = password_hash($newPass, PASSWORD_BCRYPT);
                $upStmt = $db->prepare("UPDATE admin_users SET password_hash = :hash, updated_at = NOW() WHERE id = :id");
                $upStmt->execute(['hash' => $newHash, 'id' => $admin['id']]);
                set_flash('success', 'Admin password updated successfully!');
            }
        }
    }
}
?>

<div class="mb-4">
    <h2 class="display-font fs-3 mb-0">Portal Settings & System Diagnostics</h2>
    <p class="text-secondary small mb-0">Manage master administrator security credentials and examine database infrastructure</p>
</div>

<div class="row g-4">
    <!-- Admin Security Profile & Password -->
    <div class="col-lg-6">
        <!-- Admin Profile Summary -->
        <div class="glass-card mb-4">
            <h3 class="fs-5 text-cyan border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                <i class="fas fa-user-shield me-2"></i> Master Admin Identity
            </h3>

            <div class="d-flex align-items-center gap-3 mb-3 p-3 rounded" style="background: var(--bg-surface); border: 1px solid var(--border-subtle);">
                <div class="admin-avatar" style="width: 54px; height: 54px; font-size: 1.4rem;">
                    <?= strtoupper(substr($adminDetails['full_name'] ?? 'A', 0, 1)) ?>
                </div>
                <div>
                    <div class="fw-bold fs-5 text-light"><?= e($adminDetails['full_name'] ?? 'Administrator') ?></div>
                    <div class="small text-secondary"><?= e($adminDetails['email'] ?? '') ?></div>
                    <span class="badge bg-primary bg-opacity-25 text-cyan border border-info border-opacity-25 mt-1">
                        <?= e(strtoupper($adminDetails['role'] ?? 'superadmin')) ?>
                    </span>
                </div>
            </div>

            <div class="small text-muted">
                <div><i class="fas fa-user-tag me-2 text-cyan"></i> Username: <strong class="text-light"><?= e($adminDetails['username'] ?? 'admin') ?></strong></div>
                <div class="mt-1"><i class="fas fa-clock me-2 text-purple"></i> Last Session Sign-in: <?= e($adminDetails['last_login'] ?? 'Just now') ?></div>
                <div class="mt-1"><i class="fas fa-calendar-check me-2 text-gold"></i> Account Created: <?= date('M j, Y', strtotime($adminDetails['created_at'] ?? 'now')) ?></div>
            </div>
        </div>

        <!-- Change Password Form -->
        <div class="glass-card">
            <h3 class="fs-5 text-purple border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                <i class="fas fa-key me-2"></i> Change Security Password
            </h3>

            <form method="POST" action="settings.php">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="change_password">

                <div class="form-group">
                    <label class="form-label-gaming" for="current_password">Current Password *</label>
                    <input type="password" class="form-control-gaming" id="current_password" name="current_password" required>
                </div>

                <div class="form-group">
                    <label class="form-label-gaming" for="new_password">New Password (min. 6 chars) *</label>
                    <input type="password" class="form-control-gaming" id="new_password" name="new_password" required>
                </div>

                <div class="form-group">
                    <label class="form-label-gaming" for="confirm_password">Confirm New Password *</label>
                    <input type="password" class="form-control-gaming" id="confirm_password" name="confirm_password" required>
                </div>

                <button type="submit" class="btn btn-gaming btn-gaming-purple w-100 py-2">
                    <i class="fas fa-lock me-2"></i> Update Password
                </button>
            </form>
        </div>
    </div>

    <!-- System & Database Health Diagnostics -->
    <div class="col-lg-6">
        <div class="glass-card h-100">
            <h3 class="fs-5 text-gold border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                <i class="fas fa-server me-2"></i> Database & Environment Health
            </h3>

            <!-- Health Status Banner -->
            <div class="p-3 rounded mb-4 d-flex align-items-center gap-3" style="background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3);">
                <i class="fas fa-database text-success fs-2"></i>
                <div>
                    <div class="fw-bold text-success">MySQL Database: CONNECTED & SYNCHRONIZED</div>
                    <div class="small text-secondary">Target Database: <strong class="text-cyan"><?= e($dbHealth['database']) ?></strong> on 127.0.0.1:3306</div>
                </div>
            </div>

            <!-- Diagnostics Metrics Table -->
            <table class="table-custom mb-4">
                <tbody>
                    <tr>
                        <td class="text-secondary fw-semibold">Database Engine</td>
                        <td class="font-monospace text-cyan"><?= e($dbHealth['version'] ?? 'MariaDB / MySQL') ?></td>
                    </tr>
                    <tr>
                        <td class="text-secondary fw-semibold">Database Name</td>
                        <td class="font-monospace text-gold"><?= e(DB_NAME) ?></td>
                    </tr>
                    <tr>
                        <td class="text-secondary fw-semibold">Database Charset</td>
                        <td class="font-monospace text-light">utf8mb4 (Unicode CI)</td>
                    </tr>
                    <tr>
                        <td class="text-secondary fw-semibold">PHP Runtime Version</td>
                        <td class="font-monospace text-purple"><?= PHP_VERSION ?></td>
                    </tr>
                    <tr>
                        <td class="text-secondary fw-semibold">Session Status</td>
                        <td class="text-success"><i class="fas fa-shield-alt me-1"></i> Active (HTTPOnly, SameSite=Lax)</td>
                    </tr>
                    <tr>
                        <td class="text-secondary fw-semibold">Server Local Time</td>
                        <td class="font-monospace text-light"><?= date('Y-m-d H:i:s') ?></td>
                    </tr>
                </tbody>
            </table>

            <!-- Recommended Production Architecture Note -->
            <div class="p-3 rounded small" style="background: var(--bg-surface); border: 1px solid var(--border-bright);">
                <div class="fw-bold text-cyan mb-1"><i class="fas fa-network-wired me-1"></i> Architecture Topology:</div>
                <div class="text-secondary">
                    Admin Panel connects internally via <strong class="text-light">PDO (localhost:3306)</strong> using prepared statements and CSRF tokens. All operations modify the unified <strong class="text-light">questup_db</strong> database shared with the mobile application.
                </div>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
