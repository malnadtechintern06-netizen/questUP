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
$cat = (string)($quest['category'] ?? 'location');
$vtype = (string)($quest['verification_type'] ?? 'locationGps');
$iconKey = (string)($quest['icon_key'] ?? 'landmark');
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
        <!-- Left Column: Story, Rules & Target Parameters -->
        <div class="col-lg-7">
            <!-- Basic Information Card -->
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-cyan border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-info-circle me-2"></i> Basic Information & Lore
                </h3>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="title">Quest Title *</label>
                    <input type="text" class="form-control-gaming" id="title" name="title" value="<?= e($quest['title']) ?>" required>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="description">Objective & Player Instructions *</label>
                    <textarea class="form-control-gaming" id="description" name="description" rows="3" required><?= e($quest['description']) ?></textarea>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="storyline">Storyline / Quest Lore (Optional)</label>
                    <textarea class="form-control-gaming" id="storyline" name="storyline" rows="2" placeholder="Immersive backstory or narrative lore..."><?= e($quest['storyline'] ?? '') ?></textarea>
                </div>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="category">Category *</label>
                        <select class="form-control-gaming" id="category" name="category" required onchange="onCategoryOrVerificationChange()">
                            <option value="location" <?= in_array($cat, ['location', 'exploration', 'landmark']) ? 'selected' : '' ?>>Exploration (Landmarks & GPS)</option>
                            <option value="photo" <?= $cat === 'photo' ? 'selected' : '' ?>>Photo / Object Detection</option>
                            <option value="drawing" <?= in_array($cat, ['drawing', 'creativity']) ? 'selected' : '' ?>>Creativity (Drawing Canvas)</option>
                            <option value="writing" <?= in_array($cat, ['writing', 'intellect']) ? 'selected' : '' ?>>Intellect (Writing & Journal)</option>
                            <option value="walking" <?= in_array($cat, ['walking', 'fitness']) ? 'selected' : '' ?>>Walking & Fitness (GPS Steps)</option>
                            <option value="reading" <?= $cat === 'reading' ? 'selected' : '' ?>>Reading & Study</option>
                            <option value="exercise" <?= $cat === 'exercise' ? 'selected' : '' ?>>Exercise & Workout</option>
                            <option value="gaming" <?= $cat === 'gaming' ? 'selected' : '' ?>>Gaming & Puzzle</option>
                            <option value="nature" <?= $cat === 'nature' ? 'selected' : '' ?>>Nature & Outdoors</option>
                            <option value="food" <?= $cat === 'food' ? 'selected' : '' ?>>Food & Culinary</option>
                            <option value="observation" <?= $cat === 'observation' ? 'selected' : '' ?>>Observation & City</option>
                            <option value="social" <?= $cat === 'social' ? 'selected' : '' ?>>Social & Multiplayer</option>
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

            <!-- Dynamic Verification Engine Configuration -->
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-gold border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-cogs me-2"></i> Verification Engine & Target Parameters
                </h3>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="verification_type">Primary Verification Mode *</label>
                    <select class="form-control-gaming" id="verification_type" name="verification_type" required onchange="onCategoryOrVerificationChange()">
                        <option value="locationGps" <?= $vtype === 'locationGps' ? 'selected' : '' ?>>GPS Geofence Arrival (Live coordinates check)</option>
                        <option value="photoProof" <?= in_array($vtype, ['photoProof', 'photo']) ? 'selected' : '' ?>>Photo Proof / Camera Object Scan</option>
                        <option value="quiz" <?= $vtype === 'quiz' ? 'selected' : '' ?>>Quiz / Trivia Questions (Server-Validated Answers)</option>
                        <option value="qrCode" <?= in_array($vtype, ['qrCode', 'qr']) ? 'selected' : '' ?>>QR Code Scanning (Secret Token Match)</option>
                        <option value="secretCode" <?= in_array($vtype, ['secretCode', 'code']) ? 'selected' : '' ?>>Secret Code / Passphrase Input</option>
                        <option value="taskConfirmation" <?= in_array($vtype, ['taskConfirmation', 'task']) ? 'selected' : '' ?>>Task Checklist / Self-Confirmation</option>
                        <option value="adminApproval" <?= in_array($vtype, ['adminApproval', 'admin']) ? 'selected' : '' ?>>Manual Admin Review & Approval Required</option>
                        <option value="drawingCanvas" <?= in_array($vtype, ['drawingCanvas', 'drawing']) ? 'selected' : '' ?>>Drawing Canvas Sketch</option>
                        <option value="writingText" <?= in_array($vtype, ['writingText', 'writing']) ? 'selected' : '' ?>>Writing / Word Count Logbook</option>
                        <option value="walkingGps" <?= in_array($vtype, ['walkingGps', 'walking']) ? 'selected' : '' ?>>Walking Distance Tracking (GPS)</option>
                        <option value="timedActivity" <?= $vtype === 'timedActivity' ? 'selected' : '' ?>>Timed Activity Timer</option>
                        <option value="timedVideo" <?= $vtype === 'timedVideo' ? 'selected' : '' ?>>Timed Video Recording Proof</option>
                        <option value="gameplayTime" <?= $vtype === 'gameplayTime' ? 'selected' : '' ?>>Game Session Duration</option>
                        <option value="compositeRules" <?= $vtype === 'compositeRules' ? 'selected' : '' ?>>Composite / Multi-Rule Verification</option>
                    </select>
                </div>

                <!-- Dynamic Parameter Inputs -->
                <div class="row g-3 mb-3">
                    <div class="col-md-6" id="field-required-object">
                        <label class="form-label-gaming" for="required_object">
                            <i class="fas fa-camera text-cyan me-1"></i> Target Object to Detect
                        </label>
                        <input type="text" class="form-control-gaming" id="required_object" name="required_object" value="<?= e($quest['required_object'] ?? '') ?>" placeholder="e.g. cow, car, dog, tree, apple, bicycle, book, meal">
                        <div class="form-text text-secondary small">Object detected by AI camera verifier.</div>
                    </div>

                    <div class="col-md-6" id="field-verification-secret">
                        <label class="form-label-gaming" for="verification_secret">
                            <i class="fas fa-key text-gold me-1"></i> Secret Passphrase / QR Token
                        </label>
                        <input type="text" class="form-control-gaming" id="verification_secret" name="verification_secret" value="<?= e($quest['verification_secret'] ?? '') ?>" placeholder="e.g. QUEST_SECRET_99 or QR payload">
                        <div class="form-text text-secondary small">Required for Secret Code and QR Code verification.</div>
                    </div>

                    <div class="col-md-6" id="field-required-drawing">
                        <label class="form-label-gaming" for="required_drawing_subject">
                            <i class="fas fa-paint-brush text-purple me-1"></i> Drawing Subject
                        </label>
                        <input type="text" class="form-control-gaming" id="required_drawing_subject" name="required_drawing_subject" value="<?= e($quest['required_drawing_subject'] ?? '') ?>" placeholder="e.g. tree, cat, house, mountain, portrait">
                        <div class="form-text text-secondary small">Target subject user sketches on canvas.</div>
                    </div>

                    <div class="col-md-6" id="field-required-words">
                        <label class="form-label-gaming" for="required_words">
                            <i class="fas fa-file-alt text-gold me-1"></i> Min Word Count
                        </label>
                        <input type="number" min="0" max="5000" class="form-control-gaming" id="required_words" name="required_words" value="<?= (int)($quest['required_words'] ?? 0) ?>" placeholder="e.g. 100">
                        <div class="form-text text-secondary small">Required words for writing journal logs.</div>
                    </div>

                    <div class="col-md-6" id="field-required-duration">
                        <label class="form-label-gaming" for="required_duration_seconds">
                            <i class="fas fa-stopwatch text-success me-1"></i> Timer / Min Duration (Seconds)
                        </label>
                        <input type="number" min="0" max="86400" class="form-control-gaming" id="required_duration_seconds" name="required_duration_seconds" value="<?= (int)($quest['required_duration_seconds'] ?? 0) ?>" placeholder="e.g. 600 (for 10 min)">
                        <div class="form-text text-secondary small">Anti-cheat rejects completion if completed faster.</div>
                    </div>

                    <div class="col-md-6" id="field-required-distance">
                        <label class="form-label-gaming" for="required_distance_meters">
                            <i class="fas fa-running text-info me-1"></i> Walking Distance (Meters)
                        </label>
                        <input type="number" min="0" max="100000" class="form-control-gaming" id="required_distance_meters" name="required_distance_meters" value="<?= (float)($quest['required_distance_meters'] ?? 0) ?>" placeholder="e.g. 1000 (for 1 km)">
                        <div class="form-text text-secondary small">GPS distance player must walk/travel.</div>
                    </div>

                    <div class="col-12" id="field-quiz-data">
                        <label class="form-label-gaming" for="quiz_data_json">
                            <i class="fas fa-question-circle text-info me-1"></i> Quiz Questions & Answers (JSON)
                        </label>
                        <textarea class="form-control-gaming font-monospace small" id="quiz_data_json" name="quiz_data_json" rows="3" placeholder='[{"id":"q1","question":"What year was this founded?","options":["1947","1950","1965","1980"],"correct_index":1}]'><?= e($quest['quiz_data_json'] ?? '') ?></textarea>
                        <div class="form-text text-secondary small">Server verifies answers without exposing correct answers to mobile clients.</div>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="icon_key">
                            <i class="fas fa-icons text-warning me-1"></i> Icon / Badge Key
                        </label>
                        <select class="form-control-gaming" id="icon_key" name="icon_key">
                            <option value="landmark" <?= $iconKey === 'landmark' ? 'selected' : '' ?>>landmark (Default Waypoint)</option>
                            <option value="directions_walk" <?= $iconKey === 'directions_walk' ? 'selected' : '' ?>>directions_walk (Walking & Running)</option>
                            <option value="brush" <?= $iconKey === 'brush' ? 'selected' : '' ?>>brush (Drawing & Creativity)</option>
                            <option value="edit_note" <?= $iconKey === 'edit_note' ? 'selected' : '' ?>>edit_note (Writing & Lore)</option>
                            <option value="camera_alt" <?= $iconKey === 'camera_alt' ? 'selected' : '' ?>>camera_alt (Photo Scan)</option>
                            <option value="nature" <?= $iconKey === 'nature' ? 'selected' : '' ?>>nature (Nature & Wildlife)</option>
                            <option value="park" <?= $iconKey === 'park' ? 'selected' : '' ?>>park (Trees & Forests)</option>
                            <option value="restaurant" <?= $iconKey === 'restaurant' ? 'selected' : '' ?>>restaurant (Food & Meals)</option>
                            <option value="apple" <?= $iconKey === 'apple' ? 'selected' : '' ?>>apple (Fruits & Health)</option>
                            <option value="pedal_bike" <?= $iconKey === 'pedal_bike' ? 'selected' : '' ?>>pedal_bike (Bicycle & Transit)</option>
                            <option value="menu_book" <?= $iconKey === 'menu_book' ? 'selected' : '' ?>>menu_book (Reading & Books)</option>
                            <option value="timer" <?= $iconKey === 'timer' ? 'selected' : '' ?>>timer (Timer & Clock)</option>
                            <option value="fitness_center" <?= $iconKey === 'fitness_center' ? 'selected' : '' ?>>fitness_center (Workout)</option>
                            <option value="local_florist" <?= $iconKey === 'local_florist' ? 'selected' : '' ?>>local_florist (Flowers & Plants)</option>
                            <option value="extension" <?= $iconKey === 'extension' ? 'selected' : '' ?>>extension (Gaming & Puzzles)</option>
                        </select>
                    </div>
                </div>

                <!-- Verification Proof Checklist -->
                <div class="border rounded p-3 mb-2" style="background: rgba(0,0,0,0.2); border-color: var(--border-subtle) !important;">
                    <div class="text-secondary small fw-bold mb-2">ACTIVE VERIFICATION RULES & ANTI-CHEAT FLAGS:</div>
                    <div class="row g-2">
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_gps" name="requires_gps" value="1" <?= !empty($quest['requires_gps']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_gps">Requires GPS Geofence Check</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_photo" name="requires_photo" value="1" <?= !empty($quest['requires_photo']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_photo">Requires Camera Photo Proof</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_fresh_photo" name="requires_fresh_photo" value="1" <?= !empty($quest['requires_fresh_photo']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_fresh_photo">Block Gallery Uploads (Live In-App Camera Only)</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_admin_review" name="requires_admin_review" value="1" <?= !empty($quest['requires_admin_review']) ? 'checked' : '' ?>>
                                <label class="form-check-label small text-warning" for="requires_admin_review">Require Manual Admin Review Before Awarding</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_drawing" name="requires_drawing" value="1" <?= !empty($quest['requires_drawing']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_drawing">Requires Canvas Drawing</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_text" name="requires_text" value="1" <?= !empty($quest['requires_text']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_text">Requires Written Text Entry</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_video" name="requires_video" value="1" <?= !empty($quest['requires_video']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_video">Requires Timed Video Recording</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_game_session" name="requires_game_session" value="1" <?= !empty($quest['requires_game_session']) ? 'checked' : '' ?>>
                                <label class="form-check-label small" for="requires_game_session">Requires Game Session</label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Economy & Rewards Card -->
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-gold border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-award me-2"></i> Economy Rewards & Status
                </h3>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="xp_reward">XP Reward *</label>
                        <input type="number" min="10" max="10000" class="form-control-gaming" id="xp_reward" name="xp_reward" value="<?= (int)$quest['xp_reward'] ?>" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="coins_reward">Gold Coins Reward *</label>
                        <input type="number" min="0" max="5000" class="form-control-gaming" id="coins_reward" name="coins_reward" value="<?= (int)$quest['coins_reward'] ?>" required>
                    </div>

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

        <!-- Right Column: Location Geofencing & Map Picker -->
        <div class="col-lg-5">
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-purple border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-map-marked-alt me-2"></i> Real-World Coordinates & Geofence
                </h3>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="location_name">Location Name / Landmark *</label>
                    <input type="text" class="form-control-gaming" id="location_name" name="location_name" value="<?= e($quest['location_name'] ?? '') ?>" required>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="place_type">Place Type</label>
                    <input type="text" class="form-control-gaming" id="place_type" name="place_type" value="<?= e($quest['place_type'] ?? '') ?>">
                </div>

                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <label class="form-label-gaming" for="latitude">Latitude</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="latitude" name="latitude" value="<?= $lat ?>">
                    </div>
                    <div class="col-6">
                        <label class="form-label-gaming" for="longitude">Longitude</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="longitude" name="longitude" value="<?= $lng ?>">
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
function onCategoryOrVerificationChange() {
    const cat = document.getElementById('category').value;
    const vtype = document.getElementById('verification_type').value;

    const reqGps = document.getElementById('requires_gps');
    const reqPhoto = document.getElementById('requires_photo');
    const reqFreshPhoto = document.getElementById('requires_fresh_photo');
    const reqDraw = document.getElementById('requires_drawing');
    const reqText = document.getElementById('requires_text');
    const reqVideo = document.getElementById('requires_video');
    const reqGame = document.getElementById('requires_game_session');
    const iconKey = document.getElementById('icon_key');

    // Suggest configurations if empty
    if (vtype === 'photoProof' || cat === 'photo') {
        reqPhoto.checked = true;
    }
    if (vtype === 'drawingCanvas' || cat === 'drawing') {
        reqDraw.checked = true;
    }
    if (vtype === 'writingText' || cat === 'writing') {
        reqText.checked = true;
    }
    if (vtype === 'walkingGps' || cat === 'walking') {
        reqGps.checked = true;
    }
    if (vtype === 'timedVideo' || cat === 'reading' || cat === 'exercise') {
        reqVideo.checked = true;
    }
}

document.addEventListener('DOMContentLoaded', () => {
    initQuestMapPicker({$lat}, {$lng}, {$rad}, 'latitude', 'longitude', 'radius_meters', 'map-picker');
});
</script>
HTML;

require_once __DIR__ . '/../includes/footer.php';

