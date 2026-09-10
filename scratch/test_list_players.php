<?php
$res = file_get_contents("http://127.0.0.1/questUP/backend/api/friends/list_players.php?limit=10");
echo "LIST PLAYERS RESPONSE:\n$res\n";
