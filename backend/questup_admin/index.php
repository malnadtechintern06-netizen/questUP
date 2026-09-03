<?php
/**
 * QuestUP Admin - Entry Point Router
 */

declare(strict_types=1);

require_once __DIR__ . '/config/auth.php';

if (is_admin_logged_in()) {
    header('Location: dashboard.php');
} else {
    header('Location: login.php');
}
exit;
