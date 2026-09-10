-- QuestUP Two-Step Verification & Anti-Cheat System Migration
-- Database: questup_db

USE `questup_db`;

-- 1. Create quest_verification_attempts Table
CREATE TABLE IF NOT EXISTS `quest_verification_attempts` (
  `id` VARCHAR(64) NOT NULL,
  `attempt_id` VARCHAR(64) NOT NULL UNIQUE,
  `user_id` VARCHAR(64) NOT NULL,
  `quest_id` VARCHAR(64) NOT NULL,
  `verification_type` VARCHAR(50) NOT NULL,
  `challenge_token` VARCHAR(128) NOT NULL,
  `device_id` VARCHAR(100) DEFAULT NULL,
  `device_info` VARCHAR(255) DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `proof_data` LONGTEXT DEFAULT NULL,
  `image_hash` VARCHAR(64) DEFAULT NULL,
  `perceptual_hash` VARCHAR(64) DEFAULT NULL,
  `exif_metadata_json` LONGTEXT DEFAULT NULL,
  `analysis_result` TEXT DEFAULT NULL,
  `location_result` TEXT DEFAULT NULL,
  `media_url` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('started', 'submitted', 'verifying', 'approved', 'rejected', 'pending_admin', 'flagged') DEFAULT 'started',
  `started_at` DATETIME NOT NULL,
  `submitted_at` DATETIME DEFAULT NULL,
  `verified_at` DATETIME DEFAULT NULL,
  `expires_at` DATETIME NOT NULL,
  `client_capture_time` DATETIME DEFAULT NULL,
  `client_upload_time` DATETIME DEFAULT NULL,
  `failure_reason` TEXT DEFAULT NULL,
  `is_suspicious` TINYINT(1) DEFAULT 0,
  `suspicious_reason` TEXT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_att_user` (`user_id`),
  INDEX `idx_att_quest` (`quest_id`),
  INDEX `idx_att_status` (`status`),
  INDEX `idx_att_imghash` (`image_hash`),
  INDEX `idx_att_phash` (`perceptual_hash`),
  INDEX `idx_att_token` (`challenge_token`),
  INDEX `idx_att_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Clean up any historical duplicate completions before adding UNIQUE constraint
DELETE c1 FROM quest_completions c1
INNER JOIN quest_completions c2 
WHERE c1.id < c2.id 
  AND c1.user_id = c2.user_id 
  AND c1.quest_id = c2.quest_id;

-- 3. Add UNIQUE constraint to quest_completions (user_id, quest_id) if not exists
SET @dbname = DATABASE();
SET @tablename = 'quest_completions';
SET @indexname = 'uk_user_quest_completion';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND INDEX_NAME = @indexname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD UNIQUE KEY `uk_user_quest_completion` (`user_id`, `quest_id`)'
));
PREPARE addUniqueIndex FROM @preparedStatement;
EXECUTE addUniqueIndex;
DEALLOCATE PREPARE addUniqueIndex;

-- 4. Add attempt_id and image hashes to quest_completions if not exist
SET @columnname = 'attempt_id';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD COLUMN `attempt_id` VARCHAR(64) DEFAULT NULL AFTER `quest_id`'
));
PREPARE addAttemptId FROM @preparedStatement;
EXECUTE addAttemptId;
DEALLOCATE PREPARE addAttemptId;

SET @columnname = 'image_hash';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD COLUMN `image_hash` VARCHAR(64) DEFAULT NULL AFTER `proof_data`'
));
PREPARE addImgHash FROM @preparedStatement;
EXECUTE addImgHash;
DEALLOCATE PREPARE addImgHash;

SET @columnname = 'perceptual_hash';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quest_completions` ADD COLUMN `perceptual_hash` VARCHAR(64) DEFAULT NULL AFTER `image_hash`'
));
PREPARE addPHash FROM @preparedStatement;
EXECUTE addPHash;
DEALLOCATE PREPARE addPHash;

-- 5. Add verification extensions to quests table
SET @tablename = 'quests';

SET @columnname = 'verification_secret';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quests` ADD COLUMN `verification_secret` VARCHAR(255) DEFAULT NULL'
));
PREPARE addVerSecret FROM @preparedStatement;
EXECUTE addVerSecret;
DEALLOCATE PREPARE addVerSecret;

SET @columnname = 'quiz_data_json';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quests` ADD COLUMN `quiz_data_json` LONGTEXT DEFAULT NULL'
));
PREPARE addQuizData FROM @preparedStatement;
EXECUTE addQuizData;
DEALLOCATE PREPARE addQuizData;

SET @columnname = 'min_duration_seconds';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quests` ADD COLUMN `min_duration_seconds` INT DEFAULT 0'
));
PREPARE addMinDur FROM @preparedStatement;
EXECUTE addMinDur;
DEALLOCATE PREPARE addMinDur;

SET @columnname = 'requires_admin_review';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quests` ADD COLUMN `requires_admin_review` TINYINT(1) DEFAULT 0'
));
PREPARE addAdminRev FROM @preparedStatement;
EXECUTE addAdminRev;
DEALLOCATE PREPARE addAdminRev;

SET @columnname = 'allow_gallery_upload';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  'ALTER TABLE `quests` ADD COLUMN `allow_gallery_upload` TINYINT(1) DEFAULT 0'
));
PREPARE addGalleryUpload FROM @preparedStatement;
EXECUTE addGalleryUpload;
DEALLOCATE PREPARE addGalleryUpload;
