<?php
/**
 * Tech VPN Admin Authentication
 * Simple session-based login with hashed password
 */

session_start();

// Admin credentials — change the password hash after first login
// Default password: TechVPN@Admin2026!
// To generate a new hash: php -r "echo password_hash('YourNewPassword', PASSWORD_DEFAULT);"
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD_HASH', '$2y$10$placeholder_hash_replace_me');

// Path to config file that stores the real hash (set on first login)
define('AUTH_CONFIG_FILE', __DIR__ . '/../data/admin_config.json');

function getAdminPasswordHash() {
    $configFile = AUTH_CONFIG_FILE;
    if (file_exists($configFile)) {
        $config = json_decode(file_get_contents($configFile), true);
        if (!empty($config['password_hash'])) {
            return $config['password_hash'];
        }
    }
    // First-time setup: hash the default password
    $defaultHash = password_hash('TechVPN@Admin2026!', PASSWORD_DEFAULT);
    saveAdminConfig(['password_hash' => $defaultHash]);
    return $defaultHash;
}

function saveAdminConfig($config) {
    $configFile = AUTH_CONFIG_FILE;
    $existing = [];
    if (file_exists($configFile)) {
        $existing = json_decode(file_get_contents($configFile), true) ?: [];
    }
    $merged = array_merge($existing, $config);
    file_put_contents($configFile, json_encode($merged, JSON_PRETTY_PRINT));
}

function isLoggedIn() {
    return isset($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true;
}

function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: login.php');
        exit;
    }
}

function attemptLogin($username, $password) {
    if ($username !== ADMIN_USERNAME) {
        return false;
    }
    $hash = getAdminPasswordHash();
    return password_verify($password, $hash);
}

function changePassword($newPassword) {
    $hash = password_hash($newPassword, PASSWORD_DEFAULT);
    saveAdminConfig(['password_hash' => $hash]);
    return true;
}

function logout() {
    session_destroy();
    header('Location: login.php');
    exit;
}
