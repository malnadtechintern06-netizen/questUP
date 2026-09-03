<?php
/**
 * QuestUP Backend - Database Configuration & PDO Factory
 */

declare(strict_types=1);

function db(): PDO {
    static $pdo = null;

    if ($pdo !== null) {
        return $pdo;
    }

    $host = '127.0.0.1';
    $port = 3306;
    $dbname = 'questup_db';
    $charset = 'utf8mb4';

    $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset={$charset}";
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];

    // Try questup user credentials first, then root
    try {
        $pdo = new PDO($dsn, 'questup', 'questup123', $options);
    } catch (PDOException $e) {
        try {
            $pdo = new PDO($dsn, 'root', '', $options);
        } catch (PDOException $e2) {
            http_response_code(500);
            header('Content-Type: application/json');
            echo json_encode([
                'success' => false,
                'message' => 'Database connection failed: ' . $e2->getMessage(),
            ]);
            exit;
        }
    }

    return $pdo;
}
