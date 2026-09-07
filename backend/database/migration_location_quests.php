<?php
require_once 'c:/Users/DELL/Desktop/questUP/backend/config/database.php';

$pdo = db();

echo "Running QuestUP Quests Schema Migration..." . PHP_EOL;

// 1. Add columns if not existing
$columns = [
    'source_type' => "VARCHAR(30) NOT NULL DEFAULT 'admin'",
    'user_id' => "VARCHAR(64) NULL",
    'google_place_id' => "VARCHAR(191) NULL",
    'generation_latitude' => "DOUBLE NULL",
    'generation_longitude' => "DOUBLE NULL"
];

foreach ($columns as $col => $definition) {
    $check = $pdo->query("SHOW COLUMNS FROM quests LIKE '$col'");
    if ($check->rowCount() === 0) {
        $pdo->exec("ALTER TABLE quests ADD COLUMN $col $definition");
        echo "Added column: $col" . PHP_EOL;
    } else {
        echo "Column already exists: $col" . PHP_EOL;
    }
}

// 2. Add indexes
try {
    $pdo->exec("CREATE INDEX idx_quests_source_user ON quests (source_type, user_id)");
    echo "Created index: idx_quests_source_user" . PHP_EOL;
} catch (PDOException $e) {
    echo "Index idx_quests_source_user already exists or notice: " . $e->getMessage() . PHP_EOL;
}

try {
    $pdo->exec("CREATE INDEX idx_quests_place_id ON quests (google_place_id)");
    echo "Created index: idx_quests_place_id" . PHP_EOL;
} catch (PDOException $e) {
    echo "Index idx_quests_place_id already exists or notice: " . $e->getMessage() . PHP_EOL;
}

// 3. Ensure existing quests have source_type='admin'
$updated = $pdo->exec("UPDATE quests SET source_type = 'admin' WHERE source_type IS NULL OR source_type = ''");
echo "Updated existing quests to source_type='admin': $updated rows." . PHP_EOL;

echo "Migration completed successfully!" . PHP_EOL;
