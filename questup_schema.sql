-- QuestUP MySQL Database Schema
-- Database: questup_db

CREATE DATABASE IF NOT EXISTS `questup_db` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `questup_db`;

-- 1. Users Table (Authentication)
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `email` VARCHAR(191) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `salt` VARCHAR(64) DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. User Profiles Table (Game stats, XP, Level, Coins)
CREATE TABLE IF NOT EXISTS `user_profiles` (
  `user_id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `email` VARCHAR(191) NOT NULL,
  `avatar_key` VARCHAR(64) DEFAULT 'adventurer_default',
  `level` INT DEFAULT 1,
  `current_xp` INT DEFAULT 0,
  `xp_to_next_level` INT DEFAULT 500,
  `coins` INT DEFAULT 100,
  `joined_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
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
  INDEX `idx_quests_active` (`is_active`)
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
  PRIMARY KEY (`id`),
  INDEX `idx_completions_user` (`user_id`),
  INDEX `idx_completions_quest` (`quest_id`)
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
  INDEX `idx_notifications_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. User Badges / Achievements Table
CREATE TABLE IF NOT EXISTS `user_badges` (
  `id` VARCHAR(64) NOT NULL,
  `user_id` VARCHAR(64) NOT NULL,
  `badge_id` VARCHAR(64) NOT NULL,
  `earned_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_badge` (`user_id`, `badge_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
