<?php
function testSearch($query, $currentUserId = '') {
    $url = "http://127.0.0.1/questUP/backend/api/friends/search.php?query=" . urlencode($query);
    if (!empty($currentUserId)) {
        $url .= "&current_user_id=" . urlencode($currentUserId);
    }
    $res = @file_get_contents($url);
    echo "QUERY: '$query' (current_user_id: '$currentUserId')\n";
    echo "RESPONSE: $res\n\n";
}

testSearch("QST-9762"); // Exact tag
testSearch("9762");     // Tag without QST-
testSearch("qst-9762"); // Lowercase tag
testSearch("Sujan");    // First name
testSearch("Sujan Explorer"); // Full name
testSearch("sujan.test@questup.app"); // Email
testSearch("79e175fe-0263-4704-8dda-1001caf68e9b"); // User UUID
testSearch("QST-9762", "79e175fe-0263-4704-8dda-1001caf68e9b"); // Self search (should be blocked)
testSearch("QST-7249"); // Another real user Rohan
testSearch("Rohan");    // Another real user by name
testSearch("non_existing_random_player_xyz"); // Non existing
