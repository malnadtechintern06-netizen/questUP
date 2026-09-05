-- ==========================================================
-- QuestUP COMPLETE LIVE DATABASE SCHEMA & SEED DATA
-- Database: questup_db
-- Includes: App Tables, Badges, Friend Requests, Admin Auth
-- ==========================================================

-- 1. Users Table (Player Authentication & Player Tags)
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(64) NOT NULL,
  `player_id` VARCHAR(32) DEFAULT NULL,
  `name` VARCHAR(120) NOT NULL,
  `email` VARCHAR(191) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `salt` VARCHAR(64) DEFAULT NULL,
  `status` VARCHAR(30) DEFAULT 'active',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_users_email` (`email`),
  INDEX `idx_users_player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. User Profiles Table (Game stats, XP, Level, Coins)
CREATE TABLE IF NOT EXISTS `user_profiles` (
  `user_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `email` VARCHAR(191) NOT NULL,
  `avatar_key` VARCHAR(64) DEFAULT 'avatar_ranger',
  `level` INT DEFAULT 1,
  `current_xp` INT DEFAULT 0,
  `xp_to_next_level` INT DEFAULT 500,
  `coins` INT DEFAULT 100,
  `joined_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  INDEX `idx_profiles_email` (`email`),
  CONSTRAINT `fk_user_profile_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Quests Table (Real-world and Activity Quests)
CREATE TABLE IF NOT EXISTS `quests` (
  `id` VARCHAR(64) NOT NULL,
  `title` VARCHAR(191) NOT NULL,
  `description` TEXT NOT NULL,
  `category` VARCHAR(50) NOT NULL,
  `verification_type` VARCHAR(50) NOT NULL,
  `latitude` DOUBLE DEFAULT NULL,
  `longitude` DOUBLE DEFAULT NULL,
  `radius_meters` DOUBLE DEFAULT 150.0,
  `xp_reward` INT DEFAULT 100,
  `coins_reward` INT DEFAULT 50,
  `location_name` VARCHAR(191) DEFAULT 'Current Area',
  `place_type` VARCHAR(100) DEFAULT NULL,
  `image_asset_path` VARCHAR(255) DEFAULT NULL,
  `difficulty` VARCHAR(30) DEFAULT 'medium',
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_quests_category` (`category`),
  INDEX `idx_quests_active` (`is_active`),
  INDEX `idx_quests_active_cat` (`is_active`, `category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Quest Completions Table
CREATE TABLE IF NOT EXISTS `quest_completions` (
  `id` VARCHAR(64) NOT NULL,
  `quest_id` VARCHAR(64) NOT NULL,
  `user_id` VARCHAR(64) NOT NULL,
  `verification_type` VARCHAR(50) DEFAULT NULL,
  `proof_data` TEXT DEFAULT NULL,
  `xp_earned` INT DEFAULT 0,
  `coins_earned` INT DEFAULT 0,
  `completed_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `status` VARCHAR(30) DEFAULT 'verified',
  `review_notes` TEXT DEFAULT NULL,
  `reviewed_by` VARCHAR(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_completions_user` (`user_id`),
  INDEX `idx_completions_quest` (`quest_id`),
  INDEX `idx_completions_user_quest` (`user_id`, `quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Notifications Table
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` VARCHAR(64) NOT NULL,
  `user_id` VARCHAR(64) DEFAULT NULL,
  `title` VARCHAR(191) NOT NULL,
  `message` TEXT NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `is_read` TINYINT(1) DEFAULT 0,
  `route_target` VARCHAR(100) DEFAULT NULL,
  `action_label` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_notifications_user` (`user_id`),
  INDEX `idx_notifications_user_read` (`user_id`, `is_read`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. User Badges / Achievements Table
CREATE TABLE IF NOT EXISTS `user_badges` (
  `id` VARCHAR(64) NOT NULL,
  `user_id` VARCHAR(64) NOT NULL,
  `badge_id` VARCHAR(64) NOT NULL,
  `earned_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_badge` (`user_id`, `badge_id`),
  INDEX `idx_user_badges_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Badges Catalog Table
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

-- 8. Friend Requests & Social Connections Table
CREATE TABLE IF NOT EXISTS `friend_requests` (
  `id` VARCHAR(64) NOT NULL,
  `sender_id` VARCHAR(64) NOT NULL,
  `receiver_id` VARCHAR(64) NOT NULL,
  `sender_tag` VARCHAR(32) DEFAULT NULL,
  `receiver_tag` VARCHAR(32) DEFAULT NULL,
  `status` ENUM('pending', 'accepted', 'rejected', 'cancelled') DEFAULT 'pending',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_fr_sender` (`sender_id`),
  INDEX `idx_fr_receiver` (`receiver_id`),
  INDEX `idx_fr_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Email OTPs Table
CREATE TABLE IF NOT EXISTS `email_otps` (
  `id` VARCHAR(64) NOT NULL,
  `email` VARCHAR(191) NOT NULL,
  `otp_code` VARCHAR(10) NOT NULL,
  `expires_at` DATETIME NOT NULL,
  `is_used` TINYINT(1) DEFAULT 0,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_email_otp` (`email`, `otp_code`),
  INDEX `idx_email_expires` (`email`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Admin Users Table (For Web Admin Panel Login)
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

-- ==========================================================
-- SEED DATA
-- ==========================================================

-- Seed default Master Superadmin: admin / admin123
INSERT INTO `admin_users` (`id`, `username`, `email`, `password_hash`, `full_name`, `role`, `is_active`)
SELECT 'admin_001', 'admin', 'admin@questup.com', '$2y$10$EPb2ebJ9cz3vrYlfJVn4Muh/EiagIF8eRPb2dZoAx76Pg/pzoiKzC', 'QuestUP Master Admin', 'superadmin', 1
WHERE NOT EXISTS (SELECT 1 FROM `admin_users` WHERE `username` = 'admin');

-- Seed Badges Catalog
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
