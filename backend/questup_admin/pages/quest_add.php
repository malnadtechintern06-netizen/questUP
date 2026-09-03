<?php
/**
 * QuestUP Admin - Create New Quest
 */

declare(strict_types=1);

$pageTitle = 'Create New Quest';
require_once __DIR__ . '/../includes/header.php';
require_once __DIR__ . '/../includes/sidebar.php';
require_once __DIR__ . '/../includes/navbar.php';
?>

<div class="mb-4">
    <a href="quests.php" class="text-secondary small text-decoration-none mb-1 d-inline-block">
        <i class="fas fa-arrow-left me-1"></i> Back to Quests
    </a>
    <h2 class="display-font fs-3 mb-0">Craft Real-World Adventure Quest</h2>
</div>

<form method="POST" action="../actions/quest_actions.php" enctype="multipart/form-data">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="create_quest">

    <div class="row g-4">
        <!-- Basic Info & Rewards Column -->
        <div class="col-lg-7">
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-cyan border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-info-circle me-2"></i> Basic Information
                </h3>

                <div class="form-group">
                    <label class="form-label-gaming" for="title">Quest Title *</label>
                    <input type="text" class="form-control-gaming" id="title" name="title" placeholder="e.g. Conquer the Clock Tower" required>
                </div>

                <div class="form-group">
                    <label class="form-label-gaming" for="description">Quest Objective & Story *</label>
                    <textarea class="form-control-gaming" id="description" name="description" rows="4" placeholder="Describe the lore, exploration target, and verification instructions for the adventurer..." required></textarea>
                </div>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="category">Category *</label>
                        <select class="form-control-gaming" id="category" name="category" required>
                            <option value="exploration">Exploration (Landmarks & Places)</option>
                            <option value="fitness">Fitness (Running & Steps)</option>
                            <option value="creativity">Creativity (Drawing Canvas)</option>
                            <option value="intellect">Intellect (Writing & Puzzles)</option>
                            <option value="social">Social & Multiplayer</option>
                        </select>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="difficulty">Difficulty Level *</label>
                        <select class="form-control-gaming" id="difficulty" name="difficulty" required>
                            <option value="easy">Easy (Novice Explorer)</option>
                            <option value="medium" selected>Medium (Standard Trial)</option>
                            <option value="hard">Hard (Experienced Pathfinder)</option>
                            <option value="legendary">Legendary (Master Quest)</option>
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
                            <option value="locationGps">GPS Geofence Arrival (Automatic radar check)</option>
                            <option value="photo">Photo / Landmark Camera Scan</option>
                            <option value="drawing">Drawing / Creative Canvas Sketch</option>
                            <option value="writing">Writing / Journal Logbook</option>
                            <option value="qrCode">QR Code Discovery Scan</option>
                            <option value="codePhrase">Secret Codephrase Entry</option>
                        </select>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="xp_reward">XP Reward *</label>
                        <input type="number" min="10" max="10000" class="form-control-gaming" id="xp_reward" name="xp_reward" value="150" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="coins_reward">Gold Coins Reward *</label>
                        <input type="number" min="0" max="5000" class="form-control-gaming" id="coins_reward" name="coins_reward" value="50" required>
                    </div>
                </div>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="image_asset_path">Image Asset / Poster Path</label>
                        <input type="text" class="form-control-gaming" id="image_asset_path" name="image_asset_path" value="assets/images/hero_poster.jpg" placeholder="assets/images/...">
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="is_active">Initial Status</label>
                        <select class="form-control-gaming" id="is_active" name="is_active">
                            <option value="1">Active (Visible in App)</option>
                            <option value="0">Draft / Inactive</option>
                        </select>
                    </div>
                </div>
            </div>
        </div>

        <!-- Location Geofencing & Map Picker Column -->
        <div class="col-lg-5">
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-purple border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-map-marked-alt me-2"></i> Real-World Coordinates
                </h3>

                <div class="form-group">
                    <label class="form-label-gaming" for="location_name">Location Name / Landmark *</label>
                    <input type="text" class="form-control-gaming" id="location_name" name="location_name" placeholder="e.g. Central City Park" required>
                </div>

                <div class="form-group">
                    <label class="form-label-gaming" for="place_type">Place Type / Category</label>
                    <input type="text" class="form-control-gaming" id="place_type" name="place_type" placeholder="e.g. park, monument, college, museum" value="landmark">
                </div>

                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <label class="form-label-gaming" for="latitude">Latitude *</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="latitude" name="latitude" value="12.971598" required>
                    </div>
                    <div class="col-6">
                        <label class="form-label-gaming" for="longitude">Longitude *</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="longitude" name="longitude" value="77.594566" required>
                    </div>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="radius_meters">Radar Geofence Radius (Meters) *</label>
                    <input type="number" min="20" max="5000" class="form-control-gaming" id="radius_meters" name="radius_meters" value="150" required>
                </div>

                <div class="mb-2 text-secondary small">
                    <i class="fas fa-crosshairs text-cyan me-1"></i> Click or drag map pin to position target coordinates:
                </div>
                <div id="map-picker"></div>
            </div>

            <!-- Submit Buttons -->
            <div class="glass-card text-end">
                <a href="quests.php" class="btn btn-gaming btn-gaming-outline me-2">Cancel</a>
                <button type="submit" class="btn btn-gaming btn-gaming-cyan px-4">
                    <i class="fas fa-check-circle me-2"></i> Publish Quest
                </button>
            </div>
        </div>
    </div>
</form>

<?php
$extraScripts = <<<HTML
<script>
document.addEventListener('DOMContentLoaded', () => {
    initQuestMapPicker(12.971598, 77.594566, 150, 'latitude', 'longitude', 'radius_meters', 'map-picker');
});
</script>
HTML;

require_once __DIR__ . '/../includes/footer.php';
