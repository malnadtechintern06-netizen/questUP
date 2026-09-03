<?php
/**
 * QuestUP Admin - Edit Quest
 */

declare(strict_types=1);

$questId = trim($_GET['id'] ?? '');
if (empty($questId)) {
    header('Location: quests.php');
    exit;
}

$pageTitle = 'Edit Quest';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';

$db = db();

$stmt = $db->prepare("SELECT * FROM quests WHERE id = :id LIMIT 1");
$stmt->execute(['id' => $questId]);
$quest = $stmt->fetch();

if (!$quest) {
    echo '<div class="alert alert-danger">Quest not found. <a href="quests.php">Back to Quests</a></div>';
    require_once __DIR__ . '/../includes/footer.php';
    exit;
}

$lat = (float)($quest['latitude'] ?? 12.971598);
$lng = (float)($quest['longitude'] ?? 77.594566);
$rad = (float)($quest['radius_meters'] ?? 150.0);
?>

<div class="mb-4">
    <a href="quests.php" class="text-secondary small text-decoration-none mb-1 d-inline-block">
        <i class="fas fa-arrow-left me-1"></i> Back to Quests
    </a>
    <h2 class="display-font fs-3 mb-0">Edit Quest: <?= e($quest['title']) ?></h2>
</div>

<form method="POST" action="../actions/quest_actions.php">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="update_quest">
    <input type="hidden" name="quest_id" value="<?= e($quest['id']) ?>">

    <div class="row g-4">
        <!-- Basic Info Column -->
        <div class="col-lg-7">
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-cyan border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-info-circle me-2"></i> Basic Information
                </h3>

                <div class="form-group">
                    <label class="form-label-gaming" for="title">Quest Title *</label>
                    <input type="text" class="form-control-gaming" id="title" name="title" value="<?= e($quest['title']) ?>" required>
                </div>

                <div class="form-group">
                    <label class="form-label-gaming" for="description">Quest Objective & Story *</label>
                    <textarea class="form-control-gaming" id="description" name="description" rows="4" required><?= e($quest['description']) ?></textarea>
                </div>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="category">Category *</label>
                        <select class="form-control-gaming" id="category" name="category" required>
                            <option value="exploration" <?= $quest['category'] === 'exploration' ? 'selected' : '' ?>>Exploration</option>
                            <option value="fitness" <?= $quest['category'] === 'fitness' ? 'selected' : '' ?>>Fitness</option>
                            <option value="creativity" <?= $quest['category'] === 'creativity' ? 'selected' : '' ?>>Creativity</option>
                            <option value="intellect" <?= $quest['category'] === 'intellect' ? 'selected' : '' ?>>Intellect</option>
                            <option value="social" <?= $quest['category'] === 'social' ? 'selected' : '' ?>>Social</option>
                        </select>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="difficulty">Difficulty Level *</label>
                        <select class="form-control-gaming" id="difficulty" name="difficulty" required>
                            <option value="easy" <?= $quest['difficulty'] === 'easy' ? 'selected' : '' ?>>Easy</option>
                            <option value="medium" <?= $quest['difficulty'] === 'medium' ? 'selected' : '' ?>>Medium</option>
                            <option value="hard" <?= $quest['difficulty'] === 'hard' ? 'selected' : '' ?>>Hard</option>
                            <option value="legendary" <?= $quest['difficulty'] === 'legendary' ? 'selected' : '' ?>>Legendary</option>
                        </select>
                    </div>
                </div>
            </div>

            <!-- Verification & Economy Rewards -->
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-gold border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-award me-2"></i> Verification & Rewards
                </h3>

                <div class="row g-3 mb-3">
                    <div class="col-md-12">
                        <label class="form-label-gaming" for="verification_type">Verification Mechanism *</label>
                        <select class="form-control-gaming" id="verification_type" name="verification_type" required>
                            <option value="locationGps" <?= $quest['verification_type'] === 'locationGps' ? 'selected' : '' ?>>GPS Location</option>
                            <option value="photo" <?= $quest['verification_type'] === 'photo' ? 'selected' : '' ?>>Photo</option>
                            <option value="drawing" <?= $quest['verification_type'] === 'drawing' ? 'selected' : '' ?>>Drawing Canvas</option>
                            <option value="writing" <?= $quest['verification_type'] === 'writing' ? 'selected' : '' ?>>Writing / Log</option>
                            <option value="qrCode" <?= $quest['verification_type'] === 'qrCode' ? 'selected' : '' ?>>QR Code</option>
                            <option value="codePhrase" <?= $quest['verification_type'] === 'codePhrase' ? 'selected' : '' ?>>Code Phrase</option>
                        </select>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="xp_reward">XP Reward *</label>
                        <input type="number" min="10" max="10000" class="form-control-gaming" id="xp_reward" name="xp_reward" value="<?= (int)$quest['xp_reward'] ?>" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="coins_reward">Gold Coins Reward *</label>
                        <input type="number" min="0" max="5000" class="form-control-gaming" id="coins_reward" name="coins_reward" value="<?= (int)$quest['coins_reward'] ?>" required>
                    </div>
                </div>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="image_asset_path">Image Asset Path</label>
                        <input type="text" class="form-control-gaming" id="image_asset_path" name="image_asset_path" value="<?= e($quest['image_asset_path'] ?? '') ?>">
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="is_active">Status</label>
                        <select class="form-control-gaming" id="is_active" name="is_active">
                            <option value="1" <?= (int)$quest['is_active'] === 1 ? 'selected' : '' ?>>Active (Visible in App)</option>
                            <option value="0" <?= (int)$quest['is_active'] === 0 ? 'selected' : '' ?>>Draft / Inactive</option>
                        </select>
                    </div>
                </div>
            </div>
        </div>

        <!-- Location Geofencing Column -->
        <div class="col-lg-5">
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-purple border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-map-marked-alt me-2"></i> Real-World Coordinates
                </h3>

                <div class="form-group">
                    <label class="form-label-gaming" for="location_name">Location Name / Landmark *</label>
                    <input type="text" class="form-control-gaming" id="location_name" name="location_name" value="<?= e($quest['location_name'] ?? '') ?>" required>
                </div>

                <div class="form-group">
                    <label class="form-label-gaming" for="place_type">Place Type</label>
                    <input type="text" class="form-control-gaming" id="place_type" name="place_type" value="<?= e($quest['place_type'] ?? '') ?>">
                </div>

                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <label class="form-label-gaming" for="latitude">Latitude *</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="latitude" name="latitude" value="<?= $lat ?>" required>
                    </div>
                    <div class="col-6">
                        <label class="form-label-gaming" for="longitude">Longitude *</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="longitude" name="longitude" value="<?= $lng ?>" required>
                    </div>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="radius_meters">Radar Geofence Radius (Meters) *</label>
                    <input type="number" min="20" max="5000" class="form-control-gaming" id="radius_meters" name="radius_meters" value="<?= $rad ?>" required>
                </div>

                <div class="mb-2 text-secondary small">
                    <i class="fas fa-crosshairs text-cyan me-1"></i> Drag pin to reposition quest waypoint:
                </div>
                <div id="map-picker"></div>
            </div>

            <!-- Submit -->
            <div class="glass-card text-end">
                <a href="quests.php" class="btn btn-gaming btn-gaming-outline me-2">Cancel</a>
                <button type="submit" class="btn btn-gaming btn-gaming-cyan px-4">
                    <i class="fas fa-save me-2"></i> Update Quest
                </button>
            </div>
        </div>
    </div>
</form>

<?php
$extraScripts = <<<HTML
<script>
document.addEventListener('DOMContentLoaded', () => {
    initQuestMapPicker({$lat}, {$lng}, {$rad}, 'latitude', 'longitude', 'radius_meters', 'map-picker');
});
</script>
HTML;

require_once __DIR__ . '/../includes/footer.php';
