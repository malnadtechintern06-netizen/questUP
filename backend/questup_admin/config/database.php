<?php
/**
 * QuestUP Admin Database Configuration & Connection (PDO)
 * Database: questup_db
 */

declare(strict_types=1);

define('DB_HOST', getenv('DB_HOST') ?: '127.0.0.1');
define('DB_PORT', (int)(getenv('DB_PORT') ?: 3306));
define('DB_NAME', getenv('DB_NAME') ?: 'questup_db');
define('DB_USER', getenv('DB_USER') ?: 'root');
define('DB_PASS', getenv('DB_PASS') !== false ? getenv('DB_PASS') : '');
define('DB_CHARSET', 'utf8mb4');

class Database {
    private static ?PDO $instance = null;

    public static function getConnection(): PDO {
        if (self::$instance === null) {
            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                DB_HOST,
                DB_PORT,
                DB_NAME,
                DB_CHARSET
            );

            $options = [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
            ];

            try {
                self::$instance = new PDO($dsn, DB_USER, DB_PASS, $options);
            } catch (PDOException $e) {
                error_log('[QuestUP Admin DB Error] ' . $e->getMessage());
                die('<div style="font-family: sans-serif; padding: 20px; background: #1a1a2e; color: #ff6b6b; border-radius: 8px; margin: 20px;">' .
                    '<h3>Database Connection Failed</h3>' .
                    '<p>' . htmlspecialchars($e->getMessage()) . '</p>' .
                    '<p style="color: #a0a0b0;">Please check your database settings in <code>config/database.php</code> (Host, Database Name, Username, Password).</p>' .
                    '</div>');
            }
        }

        return self::$instance;
    }

    public static function checkHealth(): array {
        try {
            $db = self::getConnection();
            $stmt = $db->query("SELECT VERSION() as version, DATABASE() as dbname, NOW() as server_time");
            $info = $stmt->fetch();
            return [
                'status' => 'connected',
                'database' => $info['dbname'] ?? DB_NAME,
                'version' => $info['version'] ?? 'Unknown',
                'server_time' => $info['server_time'] ?? date('Y-m-d H:i:s'),
                'host' => DB_HOST . ':' . DB_PORT,
            ];
        } catch (Throwable $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
                'database' => DB_NAME,
                'host' => DB_HOST . ':' . DB_PORT,
            ];
        }
    }
}

function db(): PDO {
    return Database::getConnection();
}
