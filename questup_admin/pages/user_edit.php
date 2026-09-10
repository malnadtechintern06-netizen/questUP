<?php
/**
 * QuestUP Admin - Edit User Profile & Stats
 */

declare(strict_types=1);

$userId = trim($_GET['id'] ?? '');
if (empty($userId)) {
    header('Location: users.php');
    exit;
}

$pageTitle = 'Edit Explorer Stats';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

// Fetch User & Profile
$stmt = $db->prepare("
    SELECT u.id, u.name, u.email, u.status,
           p.avatar_key, p.level, p.current_xp, p.xp_to_next_level, p.coins
    FROM users u
    LEFT JOIN user_profiles p ON u.id = p.user_id
    WHERE u.id = :id
    LIMIT 1
");
$stmt->execute(['id' => $userId]);
$user = $stmt->fetch();

if (!$user) {
    echo '<div class="alert alert-danger">User not found. <a href="users.php">Return to Users</a></div>';
    require_once __DIR__ . '/../includes/footer.php';
    exit;
}
?>

<div class="mb-4">
    <a href="users.php" class="text-secondary small text-decoration-none mb-1 d-inline-block">
        <i class="fas fa-arrow-left me-1"></i> Back to Explorers
    </a>
    <h2 class="display-font fs-3 mb-0">Modify Explorer: <?= e($user['name']) ?></h2>
</div>

<div class="row justify-content-center">
    <div class="col-lg-8">
        <div class="glass-card">
            <form method="POST" action="../actions/user_actions.php">
                <?= csrf_field() ?>
                <input type="hidden" name="action" value="update_user">
                <input type="hidden" name="user_id" value="<?= e($user['id']) ?>">

                <h3 class="fs-5 text-cyan border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-user me-2"></i> Account Information
                </h3>

                <div class="row g-3 mb-4">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="name">Display Name</label>
                        <input type="text" class="form-control-gaming" id="name" name="name" value="<?= e($user['name']) ?>" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="email">Email Address</label>
                        <input type="email" class="form-control-gaming" id="email" name="email" value="<?= e($user['email']) ?>" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="status">Account Status</label>
                        <select class="form-control-gaming" id="status" name="status">
                            <option value="active" <?= ($user['status'] ?? 'active') === 'active' ? 'selected' : '' ?>>Active (Enabled)</option>
                            <option value="disabled" <?= ($user['status'] ?? '') === 'disabled' ? 'selected' : '' ?>>Disabled / Suspended</option>
                        </select>
                    </div>
                </div>

                <h3 class="fs-5 text-gold border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-gamepad me-2"></i> RPG Progression & Economy Stats
                </h3>

                <div class="row g-3 mb-4">
                    <div class="col-md-4">
                        <label class="form-label-gaming" for="level">Player Level</label>
                        <input type="number" min="1" max="100" class="form-control-gaming" id="level" name="level" value="<?= (int)($user['level'] ?? 1) ?>" required>
                    </div>

                    <div class="col-md-4">
                        <label class="form-label-gaming" for="current_xp">Current XP</label>
                        <input type="number" min="0" class="form-control-gaming" id="current_xp" name="current_xp" value="<?= (int)($user['current_xp'] ?? 0) ?>" required>
                    </div>

                    <div class="col-md-4">
                        <label class="form-label-gaming" for="xp_to_next_level">XP Required for Next Level</label>
                        <input type="number" min="100" class="form-control-gaming" id="xp_to_next_level" name="xp_to_next_level" value="<?= (int)($user['xp_to_next_level'] ?? 500) ?>" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="coins">Gold Coins Balance</label>
                        <input type="number" min="0" class="form-control-gaming" id="coins" name="coins" value="<?= (int)($user['coins'] ?? 100) ?>" required>
                    </div>
                </div>

                <div class="d-flex justify-content-between align-items-center pt-3 border-top" style="border-color: var(--border-subtle) !important;">
                    <a href="users.php" class="btn btn-gaming btn-gaming-outline">Cancel</a>
                    <button type="submit" class="btn btn-gaming btn-gaming-cyan px-4">
                        <i class="fas fa-save me-2"></i> Save Changes
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../includes/footer.php'; ?>
