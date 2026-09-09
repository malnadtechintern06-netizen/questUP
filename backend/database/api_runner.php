<?php
/**
 * CLI Runner for Testing PHP REST Endpoints
 */
declare(strict_types=1);

if ($argc < 2) {
    echo json_encode(['error' => 'No endpoint specified']);
    exit(1);
}

$endpointPath = $argv[1];
$method = strtoupper($argv[2] ?? 'GET');
$paramsJson = file_get_contents('php://stdin');
$params = json_decode($paramsJson, true) ?? [];

$_SERVER['REQUEST_METHOD'] = $method;

if ($method === 'GET') {
    $_GET = $params;
    $_POST = [];
} else {
    $_POST = $params;
    $_GET = [];
}

register_shutdown_function(function () {
    $code = http_response_code();
    file_put_contents(__DIR__ . '/last_response_code.txt', (string)$code);
});

require __DIR__ . '/../api/' . $endpointPath;
