<?php
/**
 * Tech VPN Server List API
 * Returns the active server list as JSON
 * The app fetches: https://techvpnpro.com/api/servers.json
 * This file serves as fallback if servers.json doesn't exist
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Cache-Control: public, max-age=60'); // Cache for 60 seconds

$jsonFile = __DIR__ . '/servers.json';

if (file_exists($jsonFile)) {
    readfile($jsonFile);
} else {
    // Fallback: read from data file and filter active
    $dataFile = __DIR__ . '/../data/servers.json';
    if (file_exists($dataFile)) {
        $servers = json_decode(file_get_contents($dataFile), true) ?: [];
        $active = array_values(array_filter($servers, fn($s) => $s['is_active'] ?? false));
        echo json_encode($active);
    } else {
        echo '[]';
    }
}
