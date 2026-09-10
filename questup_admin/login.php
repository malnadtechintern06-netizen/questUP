<?php
/**
 * QuestUP Web Admin Panel - Secure Login
 */

declare(strict_types=1);

require_once __DIR__ . '/config/auth.php';
require_once __DIR__ . '/includes/functions.php';

if (is_admin_logged_in()) {
    header('Location: dashboard.php');
    exit;
}

$errorMessage = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $errorMessage = 'Security token invalid or expired. Please refresh and try again.';
    } else {
        $identifier = trim($_POST['identifier'] ?? '');
        $password = $_POST['password'] ?? '';

        $loginResult = admin_login($identifier, $password);
        if ($loginResult['success']) {
            set_flash('success', 'Welcome back, ' . ($_SESSION['admin_full_name'] ?? 'Admin') . '!');
            header('Location: dashboard.php');
            exit;
        } else {
            $errorMessage = $loginResult['message'];
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Portal Login | QuestUP</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Rajdhani:wght@600;700;800&display=swap" rel="stylesheet">

    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

    <!-- FontAwesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">

    <!-- Custom Admin CSS -->
    <link rel="stylesheet" href="assets/css/admin.css?v=1.0.0">

    <link rel="icon" type="image/png" href="assets/images/logo_emblem.png">

    <style>
        .login-wrapper {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            background: radial-gradient(circle at 50% 30%, rgba(0, 229, 255, 0.12) 0%, rgba(10, 14, 23, 0.98) 70%);
        }
        .login-card {
            width: 100%;
            max-width: 440px;
            background: rgba(20, 27, 45, 0.9);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(0, 229, 255, 0.3);
            border-radius: 24px;
            padding: 40px 32px;
            box-shadow: 0 16px 50px rgba(0, 0, 0, 0.7), 0 0 30px rgba(0, 229, 255, 0.15);
        }
        .login-logo-circle {
            width: 90px;
            height: 90px;
            margin: 0 auto 20px;
            border-radius: 50%;
            border: 2px solid var(--accent-cyan);
            box-shadow: 0 0 25px var(--accent-cyan-glow);
            padding: 4px;
            background: #0f1523;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-logo-circle img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            border-radius: 50%;
        }
        .password-toggle-btn {
            position: absolute;
            right: 14px;
            top: 50%;
            transform: translateY(-50%);
            background: none;
            border: none;
            color: var(--text-secondary);
            cursor: pointer;
            padding: 4px;
        }
        .password-toggle-btn:hover {
            color: var(--accent-cyan);
        }
    </style>
</head>
<body>
<div class="login-wrapper">
    <div class="login-card">
        <div class="text-center mb-4">
            <div class="login-logo-circle">
                <img src="assets/images/logo_emblem.png" alt="QuestUP Emblem">
            </div>
            <h1 class="display-font fs-2 mb-1" style="letter-spacing: 1.5px;">QUEST<span class="text-cyan">UP</span></h1>
            <p class="text-secondary small text-uppercase fw-bold" style="letter-spacing: 2px;">Master Admin Portal</p>
        </div>

        <?php if (!empty($errorMessage)): ?>
            <div class="alert alert-danger py-2 px-3 mb-4 d-flex align-items-center gap-2" role="alert" style="font-size: 0.88rem;">
                <i class="fas fa-exclamation-triangle"></i>
                <div><?= e($errorMessage) ?></div>
            </div>
        <?php endif; ?>

        <form method="POST" action="login.php">
            <?= csrf_field() ?>

            <div class="form-group">
                <label for="identifier" class="form-label-gaming">Username or Email</label>
                <div class="position-relative">
                    <input type="text" 
                           class="form-control-gaming ps-5" 
                           id="identifier" 
                           name="identifier" 
                           value="<?= e($_POST['identifier'] ?? '') ?>" 
                           placeholder="admin or admin@questup.com" 
                           required 
                           autofocus>
                    <i class="fas fa-user-shield position-absolute text-muted" style="left: 16px; top: 50%; transform: translateY(-50%);"></i>
                </div>
            </div>

            <div class="form-group">
                <label for="password" class="form-label-gaming">Admin Password</label>
                <div class="position-relative">
                    <input type="password" 
                           class="form-control-gaming ps-5 pe-5" 
                           id="password" 
                           name="password" 
                           placeholder="••••••••••••" 
                           required>
                    <i class="fas fa-lock position-absolute text-muted" style="left: 16px; top: 50%; transform: translateY(-50%);"></i>
                    <button type="button" class="password-toggle-btn" onclick="togglePasswordVisibility('password', 'passwordIcon')" aria-label="Toggle password visibility">
                        <i class="fas fa-eye" id="passwordIcon"></i>
                    </button>
                </div>
            </div>

            <div class="d-flex justify-content-between align-items-center mb-4">
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="rememberMe" name="remember_me" style="background-color: var(--bg-surface); border-color: var(--border-bright);">
                    <label class="form-check-label text-secondary small" for="rememberMe">
                        Keep me signed in
                    </label>
                </div>
                <span class="text-cyan small fw-semibold" title="Default login: admin / admin123">Default: admin123</span>
            </div>

            <button type="submit" class="btn btn-gaming btn-gaming-cyan w-100 py-3 fs-6">
                <i class="fas fa-sign-in-alt me-2"></i> Enter Admin Portal
            </button>
        </form>

        <div class="mt-4 pt-3 border-top text-center text-muted" style="border-color: var(--border-subtle) !important; font-size: 0.78rem;">
            <div>Database: <strong class="text-cyan"><?= htmlspecialchars(DB_NAME) ?></strong> (Localhost / XAMPP)</div>
            <div class="mt-1">Protected by CSRF & BCrypt Authentication</div>
        </div>
    </div>
</div>

<script src="assets/js/admin.js?v=1.0.0"></script>
</body>
</html>
