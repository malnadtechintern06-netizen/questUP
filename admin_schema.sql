-- QuestUP Admin & Schema Extensions Migration
-- Database: questup_db

USE `questup_db`;

-- 1. Admin Users Table for Web Admin Panel Authentication
CREATE TABLE IF NOT EXISTS `admin_users` (
  `id` VARCHAR(64) NOT NULL,
  `username` VARCHAR(60) NOT NULL UNIQUE,
  `email` VARCHAR(191) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `full_name` VARCHAR(120) NOT NULL,
  `role` VARCHAR(30) DEFAULT 'superadmin',
  `is_active` TINYINT(1) DEFAULT 1,
  `last_login` DATETIME DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_admin_username` (`username`),
  INDEX `idx_admin_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Badges Catalog Table
CREATE TABLE IF NOT EXISTS `badges` (
  `id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `description` TEXT NOT NULL,
  `icon` VARCHAR(100) DEFAULT 'military_tech',
  `category` VARCHAR(50) DEFAULT 'exploration',
  `xp_bonus` INT DEFAULT 100,
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Ensure status & review columns in quest_completions
SET @dbname = DATABASE();
SET @tablename = 'quest_completions';
SET @columnname = 'status';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD COLUMN `status` VARCHAR(30) DEFAULT \'verified\' AFTER `completed_at`'
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

SET @columnname = 'review_notes';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD COLUMN `review_notes` TEXT DEFAULT NULL AFTER `status`'
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

SET @columnname = 'reviewed_by';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD COLUMN `reviewed_by` VARCHAR(64) DEFAULT NULL AFTER `review_notes`'
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- 4. Ensure status column in users
SET @tablename = 'users';
SET @columnname = 'status';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `users` ADD COLUMN `status` VARCHAR(20) DEFAULT \'active\' AFTER `password_hash`'
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- 5. Seed default superadmin if table is empty
-- Default credentials: admin / admin123
INSERT INTO `admin_users` (`id`, `username`, `email`, `password_hash`, `full_name`, `role`, `is_active`)
SELECT 'admin_001', 'admin', 'admin@questup.com', '$2y$10$EPb2ebJ9cz3vrYlfJVn4Muh/EiagIF8eRPb2dZoAx76Pg/pzoiKzC', 'QuestUP Master Admin', 'superadmin', 1
WHERE NOT EXISTS (SELECT 1 FROM `admin_users` WHERE `username` = 'admin');

-- 6. Seed core achievement badges into catalog
INSERT IGNORE INTO `badges` (`id`, `name`, `description`, `icon`, `category`, `xp_bonus`, `is_active`) VALUES
('badge_first_step', 'First Step', 'Took the first step into the world of QuestUP exploration.', 'badge_compass', 'novice', 50, 1),
('badge_first_quest', 'Quest Pioneer', 'Successfully conquered your very first real-world quest.', 'badge_first_quest', 'exploration', 100, 1),
('badge_pathfinder', 'Pathfinder', 'Discovered and verified 5 distinct landmarks on radar.', 'badge_trail', 'exploration', 250, 1),
('badge_coin_hoarder', 'Treasure Seeker', 'Accumulated over 500 gold coins from quest rewards.', 'badge_coins', 'wealth', 200, 1),
('badge_level_2', 'Rising Legend', 'Reached Player Level 2 and ascended through the ranks.', 'badge_shield', 'progression', 300, 1),
('badge_legendary', 'Crown of Champions', 'Completed a Legendary difficulty quest with 100% precision.', 'badge_crown', 'elite', 1000, 1),
('badge_grandmaster_explorer', 'Grandmaster Explorer', 'Mastered 25 quests across multiple regions.', 'badge_globe_conqueror', 'elite', 1500, 1),
('badge_dragon_vault', 'Dragon Hoard Master', 'Collected over 2,500 gold coins across quests.', 'badge_dragon_gold', 'wealth', 1200, 1),
('badge_iron_marathoner', 'Iron Legs', 'Completed 10 fitness and exploration quests on foot.', 'badge_iron_legs', 'fitness', 800, 1),
('badge_eagle_eye', 'Eagle Eye Navigator', 'Discovered hidden locations without GPS simulation hints.', 'badge_eagle_eye', 'tactical', 600, 1),
('badge_enigma_solver', 'Enigma Cryptographer', 'Solved 5 high-difficulty mystery riddle quests.', 'badge_enigma', 'intellect', 750, 1),
('badge_apex_titan', 'Apex Titan', 'Earned 10,000 Total XP and secured top rank on the leaderboard.', 'badge_apex_titan', 'championship', 3000, 1),
('badge_immortal_mythic', 'Immortal Mythic Master', 'Attained the ultimate QuestUP prestige tier.', 'badge_immortal_mythic', 'mythic', 5000, 1);
