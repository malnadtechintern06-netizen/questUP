<?php
/**
 * QuestUP Admin - Header Include
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/functions.php';

require_admin();

$pageTitle = $pageTitle ?? 'Dashboard';
$currentAdmin = get_current_admin();
$dbHealth = Database::checkHealth();

// Determine asset relative path
$isSubPage = strpos($_SERVER['SCRIPT_NAME'], '/pages/') !== false;
$baseUrl = $isSubPage ? '../' : './';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($pageTitle) ?> | QuestUP Administration</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800;900&family=Rajdhani:wght@500;600;700;800&display=swap" rel="stylesheet">

    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

    <!-- FontAwesome 6 -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">

    <!-- Leaflet Maps CSS -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />

    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

    <!-- Custom Gaming Admin CSS -->
    <link rel="stylesheet" href="<?= $baseUrl ?>assets/css/admin.css?v=1.0.0">

    <!-- Favicon -->
    <link rel="icon" type="image/png" href="<?= $baseUrl ?>assets/images/logo_emblem.png">
</head>
<body>
<div class="admin-wrapper">
