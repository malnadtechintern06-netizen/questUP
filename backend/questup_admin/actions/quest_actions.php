<?php
/**
 * QuestUP Admin - Quest Actions Handler
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/auth.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../includes/functions.php';

require_admin();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ../pages/quests.php');
    exit;
}

$token = $_POST['csrf_token'] ?? '';
if (!verify_csrf_token($token)) {
    set_flash('danger', 'Security validation failed (CSRF token invalid).');
    header('Location: ../pages/quests.php');
    exit;
}

$action = trim($_POST['action'] ?? '');
$db = db();

switch ($action) {
    case 'create_quest':
        $title = trim($_POST['title'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $storyline = trim($_POST['storyline'] ?? '');
        $category = trim($_POST['category'] ?? 'location');
        $difficulty = trim($_POST['difficulty'] ?? 'medium');
        $vtype = trim($_POST['verification_type'] ?? 'locationGps');
        $locationName = trim($_POST['location_name'] ?? 'Current Area');
        $placeType = trim($_POST['place_type'] ?? 'landmark');
        $lat = (float)($_POST['latitude'] ?? 12.971598);
        $lng = (float)($_POST['longitude'] ?? 77.594566);
        $radius = max(20.0, (float)($_POST['radius_meters'] ?? 150.0));
        $xp = max(0, (int)($_POST['xp_reward'] ?? 100));
        $coins = max(0, (int)($_POST['coins_reward'] ?? 50));
        $imagePath = trim($_POST['image_asset_path'] ?? 'assets/images/logo.png');
        $isActive = (int)($_POST['is_active'] ?? 1);

        $reqObj = trim($_POST['required_object'] ?? '') ?: null;
        $reqDrawing = trim($_POST['required_drawing_subject'] ?? '') ?: null;
        $reqPlace = trim($_POST['required_place'] ?? '') ?: null;
        $reqTarget = trim($_POST['required_target'] ?? '') ?: null;
        $reqWords = max(0, (int)($_POST['required_words'] ?? 0));
        $reqDuration = max(0, (int)($_POST['required_duration_seconds'] ?? 0));
        $reqDist = max(0.0, (float)($_POST['required_distance_meters'] ?? 0.0));
        $reqLines = max(0, (int)($_POST['required_lines'] ?? 0));
        $reqReps = max(0, (int)($_POST['required_repetitions'] ?? 0));

        $reqGps = isset($_POST['requires_gps']) ? 1 : ($vtype === 'locationGps' || $vtype === 'walkingGps' ? 1 : 0);
        $reqPhoto = isset($_POST['requires_photo']) ? 1 : ($vtype === 'photoProof' ? 1 : 0);
        $reqFreshPhoto = isset($_POST['requires_fresh_photo']) ? 1 : ($reqPhoto ? 1 : 0);
        $reqDrawingFlag = isset($_POST['requires_drawing']) ? 1 : ($vtype === 'drawingCanvas' ? 1 : 0);
        $reqText = isset($_POST['requires_text']) ? 1 : ($vtype === 'writingText' ? 1 : 0);
        $reqVideo = isset($_POST['requires_video']) ? 1 : ($vtype === 'timedVideo' ? 1 : 0);
        $reqGame = isset($_POST['requires_game_session']) ? 1 : ($vtype === 'gameplayTime' ? 1 : 0);
        $iconKey = trim($_POST['icon_key'] ?? 'landmark') ?: 'landmark';

        if (empty($title) || empty($description)) {
            set_flash('danger', 'Please provide a quest title and description.');
            header('Location: ../pages/quest_add.php');
            exit;
        }

        $questId = generate_uuid();

        try {
            $stmt = $db->prepare("
                INSERT INTO quests (
                    id, title, description, storyline, category, verification_type,
                    latitude, longitude, radius_meters, xp_reward, coins_reward,
                    location_name, place_type, image_asset_path, difficulty, is_active,
                    required_object, required_drawing_subject, required_place, required_target,
                    required_words, required_duration_seconds, required_distance_meters,
                    required_lines, required_repetitions,
                    requires_gps, requires_photo, requires_fresh_photo, requires_drawing,
                    requires_text, requires_video, requires_game_session, icon_key,
                    created_at
                ) VALUES (
                    :id, :title, :description, :storyline, :category, :verification_type,
                    :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward,
                    :location_name, :place_type, :image_asset_path, :difficulty, :is_active,
                    :required_object, :required_drawing_subject, :required_place, :required_target,
                    :required_words, :required_duration_seconds, :required_distance_meters,
                    :required_lines, :required_repetitions,
                    :requires_gps, :requires_photo, :requires_fresh_photo, :requires_drawing,
                    :requires_text, :requires_video, :requires_game_session, :icon_key,
                    NOW()
                )
            ");
            $stmt->execute([
                'id' => $questId,
                'title' => $title,
                'description' => $description,
                'storyline' => $storyline ?: $description,
                'category' => $category,
                'verification_type' => $vtype,
                'latitude' => $lat,
                'longitude' => $lng,
                'radius_meters' => $radius,
                'xp_reward' => $xp,
                'coins_reward' => $coins,
                'location_name' => $locationName,
                'place_type' => $placeType,
                'image_asset_path' => $imagePath,
                'difficulty' => $difficulty,
                'is_active' => $isActive,
                'required_object' => $reqObj,
                'required_drawing_subject' => $reqDrawing,
                'required_place' => $reqPlace,
                'required_target' => $reqTarget,
                'required_words' => $reqWords,
                'required_duration_seconds' => $reqDuration,
                'required_distance_meters' => $reqDist,
                'required_lines' => $reqLines,
                'required_repetitions' => $reqReps,
                'requires_gps' => $reqGps,
                'requires_photo' => $reqPhoto,
                'requires_fresh_photo' => $reqFreshPhoto,
                'requires_drawing' => $reqDrawingFlag,
                'requires_text' => $reqText,
                'requires_video' => $reqVideo,
                'requires_game_session' => $reqGame,
                'icon_key' => $iconKey,
            ]);

            set_flash('success', "Quest '{$title}' created and deployed successfully!");
            header("Location: ../pages/quest_view.php?id=" . urlencode($questId));
            exit;
        } catch (PDOException $e) {
            error_log('[Create Quest Error] ' . $e->getMessage());
            set_flash('danger', 'Failed to create quest: ' . $e->getMessage());
            header('Location: ../pages/quest_add.php');
            exit;
        }

    case 'update_quest':
        $questId = trim($_POST['quest_id'] ?? '');
        $title = trim($_POST['title'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $storyline = trim($_POST['storyline'] ?? '');
        $category = trim($_POST['category'] ?? 'location');
        $difficulty = trim($_POST['difficulty'] ?? 'medium');
        $vtype = trim($_POST['verification_type'] ?? 'locationGps');
        $locationName = trim($_POST['location_name'] ?? 'Current Area');
        $placeType = trim($_POST['place_type'] ?? 'landmark');
        $lat = (float)($_POST['latitude'] ?? 12.971598);
        $lng = (float)($_POST['longitude'] ?? 77.594566);
        $radius = max(20.0, (float)($_POST['radius_meters'] ?? 150.0));
        $xp = max(0, (int)($_POST['xp_reward'] ?? 100));
        $coins = max(0, (int)($_POST['coins_reward'] ?? 50));
        $imagePath = trim($_POST['image_asset_path'] ?? '');
        $isActive = (int)($_POST['is_active'] ?? 1);

        $reqObj = trim($_POST['required_object'] ?? '') ?: null;
        $reqDrawing = trim($_POST['required_drawing_subject'] ?? '') ?: null;
        $reqPlace = trim($_POST['required_place'] ?? '') ?: null;
        $reqTarget = trim($_POST['required_target'] ?? '') ?: null;
        $reqWords = max(0, (int)($_POST['required_words'] ?? 0));
        $reqDuration = max(0, (int)($_POST['required_duration_seconds'] ?? 0));
        $reqDist = max(0.0, (float)($_POST['required_distance_meters'] ?? 0.0));
        $reqLines = max(0, (int)($_POST['required_lines'] ?? 0));
        $reqReps = max(0, (int)($_POST['required_repetitions'] ?? 0));

        $reqGps = isset($_POST['requires_gps']) ? 1 : 0;
        $reqPhoto = isset($_POST['requires_photo']) ? 1 : 0;
        $reqFreshPhoto = isset($_POST['requires_fresh_photo']) ? 1 : 0;
        $reqDrawingFlag = isset($_POST['requires_drawing']) ? 1 : 0;
        $reqText = isset($_POST['requires_text']) ? 1 : 0;
        $reqVideo = isset($_POST['requires_video']) ? 1 : 0;
        $reqGame = isset($_POST['requires_game_session']) ? 1 : 0;
        $iconKey = trim($_POST['icon_key'] ?? 'landmark') ?: 'landmark';

        if (empty($questId) || empty($title) || empty($description)) {
            set_flash('danger', 'Please provide valid quest details.');
            header("Location: ../pages/quest_edit.php?id=" . urlencode($questId));
            exit;
        }

        try {
            $stmt = $db->prepare("
                UPDATE quests
                SET title = :title,
                    description = :description,
                    storyline = :storyline,
                    category = :category,
                    difficulty = :difficulty,
                    verification_type = :vtype,
                    location_name = :location_name,
                    place_type = :place_type,
                    latitude = :lat,
                    longitude = :lng,
                    radius_meters = :radius,
                    xp_reward = :xp,
                    coins_reward = :coins,
                    image_asset_path = :image_path,
                    is_active = :is_active,
                    required_object = :required_object,
                    required_drawing_subject = :required_drawing_subject,
                    required_place = :required_place,
                    required_target = :required_target,
                    required_words = :required_words,
                    required_duration_seconds = :required_duration_seconds,
                    required_distance_meters = :required_distance_meters,
                    required_lines = :required_lines,
                    required_repetitions = :required_repetitions,
                    requires_gps = :requires_gps,
                    requires_photo = :requires_photo,
                    requires_fresh_photo = :requires_fresh_photo,
                    requires_drawing = :requires_drawing,
                    requires_text = :requires_text,
                    requires_video = :requires_video,
                    requires_game_session = :requires_game_session,
                    icon_key = :icon_key
                WHERE id = :id
            ");
            $stmt->execute([
                'title' => $title,
                'description' => $description,
                'storyline' => $storyline ?: $description,
                'category' => $category,
                'difficulty' => $difficulty,
                'vtype' => $vtype,
                'location_name' => $locationName,
                'place_type' => $placeType,
                'lat' => $lat,
                'lng' => $lng,
                'radius' => $radius,
                'xp' => $xp,
                'coins' => $coins,
                'image_path' => $imagePath,
                'is_active' => $isActive,
                'required_object' => $reqObj,
                'required_drawing_subject' => $reqDrawing,
                'required_place' => $reqPlace,
                'required_target' => $reqTarget,
                'required_words' => $reqWords,
                'required_duration_seconds' => $reqDuration,
                'required_distance_meters' => $reqDist,
                'required_lines' => $reqLines,
                'required_repetitions' => $reqReps,
                'requires_gps' => $reqGps,
                'requires_photo' => $reqPhoto,
                'requires_fresh_photo' => $reqFreshPhoto,
                'requires_drawing' => $reqDrawingFlag,
                'requires_text' => $reqText,
                'requires_video' => $reqVideo,
                'requires_game_session' => $reqGame,
                'icon_key' => $iconKey,
                'id' => $questId,
            ]);

            set_flash('success', "Quest '{$title}' updated successfully!");
            header("Location: ../pages/quest_view.php?id=" . urlencode($questId));
            exit;
        } catch (PDOException $e) {
            error_log('[Update Quest Error] ' . $e->getMessage());
            set_flash('danger', 'Failed to update quest: ' . $e->getMessage());
            header("Location: ../pages/quest_edit.php?id=" . urlencode($questId));
            exit;
        }

    case 'toggle_active':
        $questId = trim($_POST['quest_id'] ?? '');
        $currentStatus = (int)($_POST['current_status'] ?? 1);
        $newStatus = ($currentStatus === 1) ? 0 : 1;

        if (!empty($questId)) {
            try {
                $stmt = $db->prepare("UPDATE quests SET is_active = :status WHERE id = :id");
                $stmt->execute(['status' => $newStatus, 'id' => $questId]);
                set_flash('success', "Quest status updated to " . ($newStatus === 1 ? 'Active' : 'Inactive') . ".");
            } catch (PDOException $e) {
                set_flash('danger', 'Error updating quest status: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/quests.php');
        exit;

    case 'duplicate_quest':
        $questId = trim($_POST['quest_id'] ?? '');
        if (!empty($questId)) {
            try {
                $stmt = $db->prepare("SELECT * FROM quests WHERE id = :id LIMIT 1");
                $stmt->execute(['id' => $questId]);
                $src = $stmt->fetch();

                if ($src) {
                    $newId = generate_uuid();
                    $newTitle = $src['title'] . ' (Copy)';
                    $insert = $db->prepare("
                        INSERT INTO quests (
                            id, title, description, storyline, category, verification_type,
                            latitude, longitude, radius_meters, xp_reward, coins_reward,
                            location_name, place_type, image_asset_path, difficulty, is_active,
                            required_object, required_drawing_subject, required_place, required_target,
                            required_words, required_duration_seconds, required_distance_meters,
                            required_lines, required_repetitions,
                            requires_gps, requires_photo, requires_fresh_photo, requires_drawing,
                            requires_text, requires_video, requires_game_session, icon_key,
                            created_at
                        ) VALUES (
                            :id, :title, :description, :storyline, :category, :verification_type,
                            :latitude, :longitude, :radius_meters, :xp_reward, :coins_reward,
                            :location_name, :place_type, :image_asset_path, :difficulty, :is_active,
                            :required_object, :required_drawing_subject, :required_place, :required_target,
                            :required_words, :required_duration_seconds, :required_distance_meters,
                            :required_lines, :required_repetitions,
                            :requires_gps, :requires_photo, :requires_fresh_photo, :requires_drawing,
                            :requires_text, :requires_video, :requires_game_session, :icon_key,
                            NOW()
                        )
                    ");
                    $insert->execute([
                        'id' => $newId,
                        'title' => $newTitle,
                        'description' => $src['description'],
                        'storyline' => $src['storyline'] ?? $src['description'],
                        'category' => $src['category'],
                        'verification_type' => $src['verification_type'],
                        'latitude' => $src['latitude'],
                        'longitude' => $src['longitude'],
                        'radius_meters' => $src['radius_meters'],
                        'xp_reward' => $src['xp_reward'],
                        'coins_reward' => $src['coins_reward'],
                        'location_name' => $src['location_name'],
                        'place_type' => $src['place_type'],
                        'image_asset_path' => $src['image_asset_path'],
                        'difficulty' => $src['difficulty'],
                        'is_active' => 0, // Inactive draft copy
                        'required_object' => $src['required_object'] ?? null,
                        'required_drawing_subject' => $src['required_drawing_subject'] ?? null,
                        'required_place' => $src['required_place'] ?? null,
                        'required_target' => $src['required_target'] ?? null,
                        'required_words' => (int)($src['required_words'] ?? 0),
                        'required_duration_seconds' => (int)($src['required_duration_seconds'] ?? 0),
                        'required_distance_meters' => (float)($src['required_distance_meters'] ?? 0),
                        'required_lines' => (int)($src['required_lines'] ?? 0),
                        'required_repetitions' => (int)($src['required_repetitions'] ?? 0),
                        'requires_gps' => (int)($src['requires_gps'] ?? 0),
                        'requires_photo' => (int)($src['requires_photo'] ?? 0),
                        'requires_fresh_photo' => (int)($src['requires_fresh_photo'] ?? 0),
                        'requires_drawing' => (int)($src['requires_drawing'] ?? 0),
                        'requires_text' => (int)($src['requires_text'] ?? 0),
                        'requires_video' => (int)($src['requires_video'] ?? 0),
                        'requires_game_session' => (int)($src['requires_game_session'] ?? 0),
                        'icon_key' => $src['icon_key'] ?? 'landmark',
                    ]);
                    set_flash('success', "Duplicated quest as '{$newTitle}' (Draft).");
                }
            } catch (PDOException $e) {
                set_flash('danger', 'Failed to duplicate quest: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/quests.php');
        exit;

    case 'delete_quest':
        $questId = trim($_POST['quest_id'] ?? '');
        if (!empty($questId)) {
            try {
                $db->beginTransaction();
                $stmt = $db->prepare("DELETE FROM quest_completions WHERE quest_id = :id");
                $stmt->execute(['id' => $questId]);

                $stmt = $db->prepare("DELETE FROM quests WHERE id = :id");
                $stmt->execute(['id' => $questId]);
                $db->commit();

                set_flash('success', 'Quest deleted successfully.');
            } catch (PDOException $e) {
                if ($db->inTransaction()) {
                    $db->rollBack();
                }
                set_flash('danger', 'Failed to delete quest: ' . $e->getMessage());
            }
        }
        header('Location: ../pages/quests.php');
        exit;

    default:
        set_flash('warning', 'Unknown action.');
        header('Location: ../pages/quests.php');
        exit;
}
