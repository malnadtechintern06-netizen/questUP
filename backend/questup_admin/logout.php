<?php
/**
 * QuestUP Admin - Logout Handler
 */

declare(strict_types=1);

require_once __DIR__ . '/config/auth.php';
require_once __DIR__ . '/includes/functions.php';

admin_logout();
set_flash('info', 'You have been securely logged out.');
header('Location: login.php');
exit;
