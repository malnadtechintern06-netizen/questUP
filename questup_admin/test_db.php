<?php
/** 
 * QuestUP Database Connection Diagnostic Tool
 * Visit this file in your browser to verify database connectivity.
 * e.g., http://your-domain.com/questup_admin/test_db.php
 */

declare(strict_types=1);

require_once __DIR__ . '/config/database.php';

$dbStatus = false;
$errorMsg = '';
$tableCount = 0;
$tables = [];
$adminExists = false;

try {
    $pdo = Database::getConnection();
    $dbStatus = true;

    // Check tables
    $stmt = $pdo->query("SHOW TABLES");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    $tableCount = count($tables);

    // Check admin users table
    if (in_array('admin_users', $tables)) {
        $adminStmt = $pdo->query("SELECT COUNT(*) FROM `admin_users` WHERE `username` = 'admin'");
        $adminExists = ((int)$adminStmt->fetchColumn()) > 0;
    }
} catch (Throwable $e) {
    $errorMsg = $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Connection Diagnostic | QuestUP</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    <style>
        body { background: #0f111a; color: #e2e8f0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: #1a1d2d; border: 1px solid #2d3250; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 650px; width: 100%; }
        .status-badge { font-size: 0.9rem; padding: 6px 14px; border-radius: 20px; font-weight: 600; }
        .bg-success-subtle { background: rgba(16, 185, 129, 0.15) !important; color: #10b981 !important; border: 1px solid rgba(16, 185, 129, 0.3); }
        .bg-danger-subtle { background: rgba(239, 68, 68, 0.15) !important; color: #ef4444 !important; border: 1px solid rgba(239, 68, 68, 0.3); }
        .list-group-item { background: #131622; border-color: #262b40; color: #cbd5e1; }
        code { color: #38bdf8; background: #0b0d14; padding: 2px 6px; border-radius: 4px; }
    </style>
</head>
<body class="p-3">
<div class="card p-4">
    <div class="d-flex align-items-center justify-content-between mb-4 pb-3 border-bottom border-secondary">
        <div>
            <h4 class="mb-0 text-white"><i class="fa-solid fa-database text-primary me-2"></i>QuestUP DB Check</h4>
            <small class="text-muted">Host: <code><?= htmlspecialchars(DB_HOST) ?>:<?= DB_PORT ?></code> | DB: <code><?= htmlspecialchars(DB_NAME) ?></code></small>
        </div>
        <div>
            <?php if ($dbStatus): ?>
                <span class="status-badge bg-success-subtle"><i class="fa-solid fa-circle-check me-1"></i> Connected</span>
            <?php else: ?>
                <span class="status-badge bg-danger-subtle"><i class="fa-solid fa-circle-xmark me-1"></i> Disconnected</span>
            <?php endif; ?>
        </div>
    </div>

    <?php if ($dbStatus): ?>
        <div class="alert alert-success bg-dark border-success text-success d-flex align-items-center mb-4">
            <i class="fa-solid fa-circle-check fs-4 me-3"></i>
            <div>
                <strong>Connection Successful!</strong> The admin panel is successfully connected to MySQL.
            </div>
        </div>

        <h6 class="text-uppercase text-muted fw-bold mb-3" style="font-size: 0.75rem; letter-spacing: 1px;">Database Summary</h6>
        <ul class="list-group mb-4">
            <li class="list-group-item d-flex justify-content-between align-items-center">
                <span><i class="fa-solid fa-table-cells text-info me-2"></i> Total Tables</span>
                <span class="badge bg-primary rounded-pill"><?= $tableCount ?> tables found</span>
            </li>
            <li class="list-group-item d-flex justify-content-between align-items-center">
                <span><i class="fa-solid fa-user-shield text-warning me-2"></i> Default Admin Account (<code>admin</code>)</span>
                <?php if ($adminExists): ?>
                    <span class="badge bg-success"><i class="fa-solid fa-check me-1"></i> Ready</span>
                <?php else: ?>
                    <span class="badge bg-warning text-dark"><i class="fa-solid fa-triangle-exclamation me-1"></i> Missing (Import questup_db.sql)</span>
                <?php endif; ?>
            </li>
            <li class="list-group-item d-flex justify-content-between align-items-center">
                <span><i class="fa-solid fa-key text-secondary me-2"></i> Default Login Credentials</span>
                <span><code>admin</code> / <code>admin123</code></span>
            </li>
        </ul>

        <div class="text-center">
            <a href="login.php" class="btn btn-primary px-4 py-2"><i class="fa-solid fa-arrow-right-to-bracket me-2"></i> Go to Admin Login</a>
        </div>
    <?php else: ?>
        <div class="alert alert-danger bg-dark border-danger text-danger mb-4">
            <h6 class="fw-bold"><i class="fa-solid fa-triangle-exclamation me-2"></i> Connection Failed</h6>
            <p class="mb-0 font-monospace small"><?= htmlspecialchars($errorMsg) ?></p>
        </div>

        <h6 class="text-uppercase text-muted fw-bold mb-3" style="font-size: 0.75rem; letter-spacing: 1px;">How to Fix This:</h6>
        <ol class="text-light small ps-3 mb-4" style="line-height: 1.8;">
            <li>Open <code>config/database.php</code> in your File Manager or editor.</li>
            <li>Verify <code>DB_HOST</code>, <code>DB_NAME</code>, <code>DB_USER</code>, and <code>DB_PASS</code> match your hosting MySQL settings.</li>
            <li>In cPanel / Hostinger, check that your MySQL User has been granted <strong>ALL PRIVILEGES</strong> on the database.</li>
            <li>Ensure <code>questup_db.sql</code> is imported in phpMyAdmin.</li>
        </ol>

        <div class="text-center">
            <a href="test_db.php" class="btn btn-outline-light px-4 py-2"><i class="fa-solid fa-rotate-right me-2"></i> Retry Connection</a>
        </div>
    <?php endif; ?>
</div>
</body>
</html>
