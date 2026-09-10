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
        <!-- Left Column: Story, Rules & Target Parameters -->
        <div class="col-lg-7">
            <!-- Basic Information Card -->
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-cyan border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-info-circle me-2"></i> Basic Information & Lore
                </h3>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="title">Quest Title *</label>
                    <input type="text" class="form-control-gaming" id="title" name="title" placeholder="e.g. Photograph a Red Sports Car / Walk 1.0 km" required>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="description">Objective & Player Instructions *</label>
                    <textarea class="form-control-gaming" id="description" name="description" rows="3" placeholder="Provide clear instructions for the player on how to complete the quest..." required></textarea>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="storyline">Storyline / Quest Lore (Optional)</label>
                    <textarea class="form-control-gaming" id="storyline" name="storyline" rows="2" placeholder="Immersive backstory or narrative lore displayed in the quest log..."></textarea>
                </div>

                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label-gaming" for="category">Category *</label>
                        <select class="form-control-gaming" id="category" name="category" required onchange="onCategoryOrVerificationChange()">
                            <option value="location">Exploration (Landmarks & GPS)</option>
                            <option value="photo">Photo / Object Detection</option>
                            <option value="drawing">Creativity (Drawing Canvas)</option>
                            <option value="writing">Intellect (Writing & Journal)</option>
                            <option value="walking">Walking & Fitness (GPS Steps)</option>
                            <option value="reading">Reading & Study</option>
                            <option value="exercise">Exercise & Workout</option>
                            <option value="gaming">Gaming & Puzzle</option>
                            <option value="nature">Nature & Outdoors</option>
                            <option value="food">Food & Culinary</option>
                            <option value="observation">Observation & City</option>
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

            <!-- Dynamic Verification Engine Configuration -->
            <div class="glass-card mb-4">
                <h3 class="fs-5 text-gold border-bottom pb-2 mb-3" style="border-color: var(--border-subtle) !important;">
                    <i class="fas fa-cogs me-2"></i> Verification Engine & Target Parameters
                </h3>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="verification_type">Primary Verification Mode *</label>
                    <select class="form-control-gaming" id="verification_type" name="verification_type" required onchange="onCategoryOrVerificationChange()">
                        <option value="locationGps">GPS Geofence Arrival (Live coordinates check)</option>
                        <option value="photoProof">Photo Proof / Camera Object Scan</option>
                        <option value="quiz">Quiz / Trivia Questions (Server-Validated Answers)</option>
                        <option value="qrCode">QR Code Scanning (Secret Token Match)</option>
                        <option value="secretCode">Secret Code / Passphrase Input</option>
                        <option value="taskConfirmation">Task Checklist / Self-Confirmation</option>
                        <option value="adminApproval">Manual Admin Review & Approval Required</option>
                        <option value="drawingCanvas">Drawing Canvas Sketch</option>
                        <option value="writingText">Writing / Word Count Logbook</option>
                        <option value="walkingGps">Walking Distance Tracking (GPS)</option>
                        <option value="timedActivity">Timed Activity Timer</option>
                        <option value="timedVideo">Timed Video Recording Proof</option>
                        <option value="gameplayTime">Game Session Duration</option>
                        <option value="compositeRules">Composite / Multi-Rule Verification</option>
                    </select>
                </div>

                <!-- Dynamic Parameter Inputs -->
                <div class="row g-3 mb-3">
                    <div class="col-md-6" id="field-required-object">
                        <label class="form-label-gaming" for="required_object">
                            <i class="fas fa-camera text-cyan me-1"></i> Target Object to Detect
                        </label>
                        <input type="text" class="form-control-gaming" id="required_object" name="required_object" placeholder="e.g. cow, car, dog, tree, apple, bicycle, book, meal">
                        <div class="form-text text-secondary small">Object detected by AI camera verifier.</div>
                    </div>

                    <div class="col-md-6" id="field-verification-secret">
                        <label class="form-label-gaming" for="verification_secret">
                            <i class="fas fa-key text-gold me-1"></i> Secret Passphrase / QR Token
                        </label>
                        <input type="text" class="form-control-gaming" id="verification_secret" name="verification_secret" placeholder="e.g. QUEST_SECRET_99 or QR payload">
                        <div class="form-text text-secondary small">Required for Secret Code and QR Code verification.</div>
                    </div>

                    <div class="col-md-6" id="field-required-drawing">
                        <label class="form-label-gaming" for="required_drawing_subject">
                            <i class="fas fa-paint-brush text-purple me-1"></i> Drawing Subject
                        </label>
                        <input type="text" class="form-control-gaming" id="required_drawing_subject" name="required_drawing_subject" placeholder="e.g. tree, cat, house, mountain, portrait">
                        <div class="form-text text-secondary small">Target subject user sketches on canvas.</div>
                    </div>

                    <div class="col-md-6" id="field-required-words">
                        <label class="form-label-gaming" for="required_words">
                            <i class="fas fa-file-alt text-gold me-1"></i> Min Word Count
                        </label>
                        <input type="number" min="0" max="5000" class="form-control-gaming" id="required_words" name="required_words" value="0" placeholder="e.g. 100">
                        <div class="form-text text-secondary small">Required words for writing journal logs.</div>
                    </div>

                    <div class="col-md-6" id="field-required-duration">
                        <label class="form-label-gaming" for="required_duration_seconds">
                            <i class="fas fa-stopwatch text-success me-1"></i> Timer / Min Duration (Seconds)
                        </label>
                        <input type="number" min="0" max="86400" class="form-control-gaming" id="required_duration_seconds" name="required_duration_seconds" value="0" placeholder="e.g. 600 (for 10 min)">
                        <div class="form-text text-secondary small">Anti-cheat rejects completion if completed faster.</div>
                    </div>

                    <div class="col-md-6" id="field-required-distance">
                        <label class="form-label-gaming" for="required_distance_meters">
                            <i class="fas fa-running text-info me-1"></i> Walking Distance (Meters)
                        </label>
                        <input type="number" min="0" max="100000" class="form-control-gaming" id="required_distance_meters" name="required_distance_meters" value="0" placeholder="e.g. 1000 (for 1 km)">
                        <div class="form-text text-secondary small">GPS distance player must walk/travel.</div>
                    </div>

                    <div class="col-12" id="field-quiz-data">
                        <label class="form-label-gaming" for="quiz_data_json">
                            <i class="fas fa-question-circle text-info me-1"></i> Quiz Questions & Answers (JSON)
                        </label>
                        <textarea class="form-control-gaming font-monospace small" id="quiz_data_json" name="quiz_data_json" rows="3" placeholder='[{"id":"q1","question":"What year was this founded?","options":["1947","1950","1965","1980"],"correct_index":1}]'></textarea>
                        <div class="form-text text-secondary small">Server verifies answers without exposing correct answers to mobile clients.</div>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="icon_key">
                            <i class="fas fa-icons text-warning me-1"></i> Icon / Badge Key
                        </label>
                        <select class="form-control-gaming" id="icon_key" name="icon_key">
                            <option value="landmark">landmark (Default Waypoint)</option>
                            <option value="directions_walk">directions_walk (Walking & Running)</option>
                            <option value="brush">brush (Drawing & Creativity)</option>
                            <option value="edit_note">edit_note (Writing & Lore)</option>
                            <option value="camera_alt">camera_alt (Photo Scan)</option>
                            <option value="nature">nature (Nature & Wildlife)</option>
                            <option value="park">park (Trees & Forests)</option>
                            <option value="restaurant">restaurant (Food & Meals)</option>
                            <option value="apple">apple (Fruits & Health)</option>
                            <option value="pedal_bike">pedal_bike (Bicycle & Transit)</option>
                            <option value="menu_book">menu_book (Reading & Books)</option>
                            <option value="timer">timer (Timer & Clock)</option>
                            <option value="fitness_center">fitness_center (Workout)</option>
                            <option value="local_florist">local_florist (Flowers & Plants)</option>
                            <option value="extension">extension (Gaming & Puzzles)</option>
                        </select>
                    </div>
                </div>

                <!-- Verification Proof Checklist -->
                <div class="border rounded p-3 mb-2" style="background: rgba(0,0,0,0.2); border-color: var(--border-subtle) !important;">
                    <div class="text-secondary small fw-bold mb-2">ACTIVE VERIFICATION RULES & ANTI-CHEAT FLAGS:</div>
                    <div class="row g-2">
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_gps" name="requires_gps" value="1">
                                <label class="form-check-label small" for="requires_gps">Requires GPS Geofence Check</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_photo" name="requires_photo" value="1">
                                <label class="form-check-label small" for="requires_photo">Requires Camera Photo Proof</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_fresh_photo" name="requires_fresh_photo" value="1" checked>
                                <label class="form-check-label small" for="requires_fresh_photo">Block Gallery Uploads (Live In-App Camera Only)</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_admin_review" name="requires_admin_review" value="1">
                                <label class="form-check-label small text-warning" for="requires_admin_review">Require Manual Admin Review Before Awarding</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_drawing" name="requires_drawing" value="1">
                                <label class="form-check-label small" for="requires_drawing">Requires Canvas Drawing</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_text" name="requires_text" value="1">
                                <label class="form-check-label small" for="requires_text">Requires Written Text Entry</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_video" name="requires_video" value="1">
                                <label class="form-check-label small" for="requires_video">Requires Timed Video Recording</label>
                            </div>
                        </div>
                        <div class="col-sm-6">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="requires_game_session" name="requires_game_session" value="1">
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
                        <input type="number" min="10" max="10000" class="form-control-gaming" id="xp_reward" name="xp_reward" value="150" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="coins_reward">Gold Coins Reward *</label>
                        <input type="number" min="0" max="5000" class="form-control-gaming" id="coins_reward" name="coins_reward" value="50" required>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="image_asset_path">Image Asset / Poster Path</label>
                        <input type="text" class="form-control-gaming" id="image_asset_path" name="image_asset_path" value="assets/images/logo.png" placeholder="assets/images/...">
                    </div>

                    <div class="col-md-6">
                        <label class="form-label-gaming" for="is_active">Status</label>
                        <select class="form-control-gaming" id="is_active" name="is_active">
                            <option value="1">Active (Visible in App)</option>
                            <option value="0">Draft / Inactive</option>
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
                    <input type="text" class="form-control-gaming" id="location_name" name="location_name" value="Hosanagara Area" placeholder="e.g. Central City Park" required>
                </div>

                <div class="form-group mb-3">
                    <label class="form-label-gaming" for="place_type">Place Type / Category</label>
                    <input type="text" class="form-control-gaming" id="place_type" name="place_type" placeholder="e.g. park, landmark, college, museum" value="landmark">
                </div>

                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <label class="form-label-gaming" for="latitude">Latitude</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="latitude" name="latitude" value="13.921406">
                    </div>
                    <div class="col-6">
                        <label class="form-label-gaming" for="longitude">Longitude</label>
                        <input type="number" step="0.000001" class="form-control-gaming" id="longitude" name="longitude" value="75.078056">
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

    // Auto-configure checkboxes and icon based on mode
    if (vtype === 'photoProof' || cat === 'photo' || cat === 'food' || cat === 'nature' || cat === 'observation' || cat === 'study') {
        reqPhoto.checked = true;
        reqFreshPhoto.checked = true;
        if (cat === 'food') iconKey.value = 'restaurant';
        else if (cat === 'nature') iconKey.value = 'nature';
        else if (cat === 'observation') iconKey.value = 'pedal_bike';
        else if (cat === 'study') iconKey.value = 'menu_book';
        else iconKey.value = 'camera_alt';
    }
    if (vtype === 'drawingCanvas' || cat === 'drawing') {
        reqDraw.checked = true;
        iconKey.value = 'brush';
    }
    if (vtype === 'writingText' || cat === 'writing') {
        reqText.checked = true;
        iconKey.value = 'edit_note';
        if (parseInt(document.getElementById('required_words').value || '0') === 0) {
            document.getElementById('required_words').value = '100';
        }
    }
    if (vtype === 'walkingGps' || cat === 'walking') {
        reqGps.checked = true;
        iconKey.value = 'directions_walk';
        if (parseFloat(document.getElementById('required_distance_meters').value || '0') === 0) {
            document.getElementById('required_distance_meters').value = '1000';
        }
    }
    if (vtype === 'timedVideo' || vtype === 'timedActivity' || cat === 'reading' || cat === 'exercise') {
        reqVideo.checked = (vtype === 'timedVideo' || cat === 'reading' || cat === 'exercise');
        if (cat === 'reading') iconKey.value = 'timer';
        else if (cat === 'exercise') iconKey.value = 'fitness_center';
        else iconKey.value = 'timer';
        if (parseInt(document.getElementById('required_duration_seconds').value || '0') === 0) {
            document.getElementById('required_duration_seconds').value = '600';
        }
    }
    if (vtype === 'gameplayTime' || cat === 'gaming') {
        reqGame.checked = true;
        iconKey.value = 'extension';
        if (parseInt(document.getElementById('required_duration_seconds').value || '0') === 0) {
            document.getElementById('required_duration_seconds').value = '300';
        }
    }
    if (vtype === 'locationGps' || cat === 'location') {
        reqGps.checked = true;
        iconKey.value = 'landmark';
    }
}

document.addEventListener('DOMContentLoaded', () => {
    initQuestMapPicker(12.971598, 77.594566, 150, 'latitude', 'longitude', 'radius_meters', 'map-picker');
    onCategoryOrVerificationChange();
});
</script>
HTML;

require_once __DIR__ . '/../includes/footer.php';

