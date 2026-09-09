<?php
/**
 * Create shared_quests table in MySQL
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

$db = db();

$sql = "
CREATE TABLE IF NOT EXISTS shared_quests (
    id VARCHAR(64) PRIMARY KEY,
    quest_id VARCHAR(120) NOT NULL,
    quest_title VARCHAR(255) NOT NULL,
    quest_data JSON NULL,
    sender_id VARCHAR(64) NOT NULL,
    sender_name VARCHAR(120) NOT NULL,
    sender_tag VARCHAR(32) NOT NULL,
    receiver_id VARCHAR(64) NOT NULL,
    status ENUM('pending', 'assisting', 'completed') DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_receiver (receiver_id),
    INDEX idx_sender (sender_id),
    INDEX idx_quest (quest_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
";

$db->exec($sql);
echo "TABLE_SHARED_QUESTS_CREATED\n";
