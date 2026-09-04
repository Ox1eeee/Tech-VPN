<?php
require_once __DIR__ . '/auth.php';
requireLogin();

$dataFile = __DIR__ . '/../data/servers.json';
$apiFile = __DIR__ . '/../api/servers.json';

// Load servers
function loadServers() {
    global $dataFile;
    if (!file_exists($dataFile)) return [];
    $data = json_decode(file_get_contents($dataFile), true);
    return is_array($data) ? $data : [];
}

// Save servers and update the public API file
function saveServers($servers) {
    global $dataFile, $apiFile;
    // Re-index IDs
    foreach ($servers as $i => &$s) {
        $s['id'] = $i + 1;
    }
    file_put_contents($dataFile, json_encode($servers, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    
    // Public API only shows active servers
    $active = array_values(array_filter($servers, fn($s) => $s['is_active']));
    file_put_contents($apiFile, json_encode($active, JSON_UNESCAPED_SLASHES));
}

$servers = loadServers();
$message = '';
$messageType = '';

// Handle actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    
    if ($action === 'add') {
        $newServer = [
            'id' => count($servers) + 1,
            'name' => trim($_POST['name'] ?? ''),
            'country' => trim($_POST['country'] ?? ''),
            'country_code' => strtoupper(trim($_POST['country_code'] ?? '')),
            'city' => trim($_POST['city'] ?? '') ?: null,
            'ip_address' => trim($_POST['ip_address'] ?? ''),
            'load' => intval($_POST['load'] ?? 0),
            'is_active' => isset($_POST['is_active']),
            'is_premium' => isset($_POST['is_premium']),
        ];
        
        if (!empty($newServer['name']) && !empty($newServer['ip_address']) && !empty($newServer['country_code'])) {
            $servers[] = $newServer;
            saveServers($servers);
            $servers = loadServers();
            $message = "Server \"{$newServer['name']}\" added successfully.";
            $messageType = 'success';
        } else {
            $message = 'Name, IP Address, and Country Code are required.';
            $messageType = 'error';
        }
    }
    
    if ($action === 'delete') {
        $id = intval($_POST['server_id'] ?? 0);
        $servers = array_values(array_filter($servers, fn($s) => $s['id'] !== $id));
        saveServers($servers);
        $servers = loadServers();
        $message = 'Server deleted.';
        $messageType = 'success';
    }
    
    if ($action === 'toggle') {
        $id = intval($_POST['server_id'] ?? 0);
        foreach ($servers as &$s) {
            if ($s['id'] === $id) {
                $s['is_active'] = !$s['is_active'];
                $message = $s['is_active'] ? "Server \"{$s['name']}\" enabled." : "Server \"{$s['name']}\" disabled.";
                $messageType = 'success';
                break;
            }
        }
        saveServers($servers);
        $servers = loadServers();
    }
    
    if ($action === 'update') {
        $id = intval($_POST['server_id'] ?? 0);
        foreach ($servers as &$s) {
            if ($s['id'] === $id) {
                $s['name'] = trim($_POST['name'] ?? $s['name']);
                $s['country'] = trim($_POST['country'] ?? $s['country']);
                $s['country_code'] = strtoupper(trim($_POST['country_code'] ?? $s['country_code']));
                $s['city'] = trim($_POST['city'] ?? '') ?: null;
                $s['ip_address'] = trim($_POST['ip_address'] ?? $s['ip_address']);
                $s['load'] = intval($_POST['load'] ?? $s['load']);
                $s['is_active'] = isset($_POST['is_active']);
                $s['is_premium'] = isset($_POST['is_premium']);
                $message = "Server \"{$s['name']}\" updated.";
                $messageType = 'success';
                break;
            }
        }
        saveServers($servers);
        $servers = loadServers();
    }
    
    if ($action === 'change_password') {
        $newPass = $_POST['new_password'] ?? '';
        $confirmPass = $_POST['confirm_password'] ?? '';
        if (strlen($newPass) < 8) {
            $message = 'Password must be at least 8 characters.';
            $messageType = 'error';
        } elseif ($newPass !== $confirmPass) {
            $message = 'Passwords do not match.';
            $messageType = 'error';
        } else {
            changePassword($newPass);
            $message = 'Password changed successfully.';
            $messageType = 'success';
        }
    }
    
    if ($action === 'logout') {
        logout();
    }
}

// Count stats
$totalServers = count($servers);
$activeServers = count(array_filter($servers, fn($s) => $s['is_active']));
$premiumServers = count(array_filter($servers, fn($s) => $s['is_premium']));

// Country flags
$flags = [
    'US' => "\xF0\x9F\x87\xBA\xF0\x9F\x87\xB8",
    'UK' => "\xF0\x9F\x87\xAC\xF0\x9F\x87\xA7",
    'GB' => "\xF0\x9F\x87\xAC\xF0\x9F\x87\xA7",
    'DE' => "\xF0\x9F\x87\xA9\xF0\x9F\x87\xAA",
    'FR' => "\xF0\x9F\x87\xAB\xF0\x9F\x87\xB7",
    'JP' => "\xF0\x9F\x87\xAF\xF0\x9F\x87\xB5",
    'SG' => "\xF0\x9F\x87\xB8\xF0\x9F\x87\xAC",
    'AU' => "\xF0\x9F\x87\xA6\xF0\x9F\x87\xBA",
    'CA' => "\xF0\x9F\x87\xA8\xF0\x9F\x87\xA6",
    'NL' => "\xF0\x9F\x87\xB3\xF0\x9F\x87\xB1",
    'IN' => "\xF0\x9F\x87\xAE\xF0\x9F\x87\xB3",
    'BR' => "\xF0\x9F\x87\xA7\xF0\x9F\x87\xB7",
    'KR' => "\xF0\x9F\x87\xB0\xF0\x9F\x87\xB7",
];
function getFlag($code) {
    global $flags;
    return $flags[strtoupper($code)] ?? "\xF0\x9F\x8C\x90";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tech VPN - Admin Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0a0a0a;
            color: #e0e0e0;
            min-height: 100vh;
        }
        
        /* Header */
        .header {
            background: #161616;
            border-bottom: 1px solid #2a2a2a;
            padding: 16px 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .header-left { display: flex; align-items: center; gap: 16px; }
        .header h1 { font-size: 20px; color: #e74c3c; letter-spacing: 2px; }
        .header .badge {
            background: rgba(231, 76, 60, 0.15);
            color: #e74c3c;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 600;
        }
        .header-right { display: flex; gap: 12px; align-items: center; }
        .btn-sm {
            padding: 8px 16px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            border: 1px solid #333;
            background: transparent;
            color: #aaa;
            transition: all 0.2s;
        }
        .btn-sm:hover { background: #222; color: #fff; }
        .btn-danger { color: #e74c3c; border-color: rgba(231,76,60,0.3); }
        .btn-danger:hover { background: rgba(231,76,60,0.1); }
        
        /* Main Layout */
        .container { max-width: 1200px; margin: 0 auto; padding: 32px 24px; }
        
        /* Stats */
        .stats {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 16px;
            margin-bottom: 32px;
        }
        .stat-card {
            background: #161616;
            border: 1px solid #2a2a2a;
            border-radius: 12px;
            padding: 20px;
        }
        .stat-card .label {
            font-size: 11px;
            font-weight: 600;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .stat-card .value {
            font-size: 32px;
            font-weight: 700;
            color: #fff;
            margin-top: 4px;
        }
        .stat-card .sub { font-size: 12px; color: #555; margin-top: 2px; }
        
        /* Message */
        .alert {
            padding: 12px 16px;
            border-radius: 8px;
            margin-bottom: 24px;
            font-size: 14px;
        }
        .alert-success { background: rgba(46, 204, 113, 0.1); border: 1px solid rgba(46, 204, 113, 0.3); color: #2ecc71; }
        .alert-error { background: rgba(231, 76, 60, 0.1); border: 1px solid rgba(231, 76, 60, 0.3); color: #e74c3c; }
        
        /* Server Table */
        .section-title {
            font-size: 13px;
            font-weight: 600;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .table-card {
            background: #161616;
            border: 1px solid #2a2a2a;
            border-radius: 12px;
            overflow: hidden;
            margin-bottom: 32px;
        }
        table { width: 100%; border-collapse: collapse; }
        th {
            text-align: left;
            padding: 14px 16px;
            font-size: 11px;
            font-weight: 600;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
            border-bottom: 1px solid #2a2a2a;
            background: #111;
        }
        td {
            padding: 14px 16px;
            font-size: 14px;
            border-bottom: 1px solid #1a1a1a;
        }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: rgba(255,255,255,0.02); }
        .server-name { font-weight: 600; color: #fff; }
        .server-ip { font-family: monospace; font-size: 13px; color: #888; }
        .badge-active {
            padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 600;
        }
        .badge-on { background: rgba(46, 204, 113, 0.15); color: #2ecc71; }
        .badge-off { background: rgba(231, 76, 60, 0.15); color: #e74c3c; }
        .badge-premium { background: rgba(241, 196, 15, 0.15); color: #f1c40f; }
        .badge-free { background: rgba(149, 165, 166, 0.15); color: #95a5a6; }
        
        .load-bar {
            width: 60px; height: 6px; background: #222; border-radius: 3px; overflow: hidden; display: inline-block; vertical-align: middle;
        }
        .load-fill { height: 100%; border-radius: 3px; }
        .load-low { background: #2ecc71; }
        .load-mid { background: #f1c40f; }
        .load-high { background: #e74c3c; }
        
        .actions { display: flex; gap: 8px; }
        .btn-icon {
            width: 32px; height: 32px; border-radius: 6px; border: 1px solid #333;
            background: transparent; color: #888; cursor: pointer;
            display: flex; align-items: center; justify-content: center;
            font-size: 14px; transition: all 0.2s;
        }
        .btn-icon:hover { background: #222; color: #fff; }
        .btn-icon.danger:hover { background: rgba(231,76,60,0.1); color: #e74c3c; border-color: rgba(231,76,60,0.3); }
        
        /* Add Server Form */
        .form-card {
            background: #161616;
            border: 1px solid #2a2a2a;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 32px;
        }
        .form-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 16px;
        }
        .form-group { display: flex; flex-direction: column; gap: 6px; }
        .form-group label {
            font-size: 11px; font-weight: 600; color: #666;
            text-transform: uppercase; letter-spacing: 1px;
        }
        .form-group input, .form-group select {
            padding: 10px 12px;
            background: #0a0a0a;
            border: 1px solid #333;
            border-radius: 6px;
            color: #e0e0e0;
            font-size: 14px;
            outline: none;
        }
        .form-group input:focus { border-color: #e74c3c; }
        .checkbox-group {
            display: flex; gap: 20px; align-items: center; padding-top: 24px;
        }
        .checkbox-group label {
            display: flex; align-items: center; gap: 6px;
            font-size: 13px; color: #aaa; text-transform: none; letter-spacing: 0;
            cursor: pointer;
        }
        .checkbox-group input[type="checkbox"] {
            width: 16px; height: 16px; accent-color: #e74c3c;
        }
        .form-actions {
            margin-top: 20px;
            display: flex;
            gap: 12px;
        }
        .btn-primary {
            padding: 10px 24px;
            background: #e74c3c;
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s;
        }
        .btn-primary:hover { background: #c0392b; }
        
        /* Modal */
        .modal-overlay {
            display: none;
            position: fixed; top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.7);
            z-index: 100;
            align-items: center; justify-content: center;
        }
        .modal-overlay.active { display: flex; }
        .modal {
            background: #161616;
            border: 1px solid #2a2a2a;
            border-radius: 16px;
            padding: 32px;
            width: 100%;
            max-width: 600px;
            max-height: 90vh;
            overflow-y: auto;
        }
        .modal h3 { font-size: 18px; margin-bottom: 20px; color: #fff; }
        
        /* API Info */
        .api-info {
            background: #161616;
            border: 1px solid #2a2a2a;
            border-radius: 12px;
            padding: 20px;
        }
        .api-url {
            font-family: monospace;
            background: #0a0a0a;
            padding: 10px 14px;
            border-radius: 6px;
            font-size: 13px;
            color: #2ecc71;
            margin-top: 8px;
            word-break: break-all;
        }
        
        @media (max-width: 768px) {
            .stats { grid-template-columns: 1fr; }
            .form-grid { grid-template-columns: 1fr; }
            .header { padding: 12px 16px; }
            .container { padding: 16px; }
        }
    </style>
</head>
<body>
    <!-- Header -->
    <div class="header">
        <div class="header-left">
            <h1>TECH VPN</h1>
            <span class="badge">ADMIN</span>
        </div>
        <div class="header-right">
            <button class="btn-sm" onclick="document.getElementById('settingsModal').classList.add('active')">Settings</button>
            <form method="POST" style="display:inline;">
                <input type="hidden" name="action" value="logout">
                <button type="submit" class="btn-sm btn-danger">Logout</button>
            </form>
        </div>
    </div>
    
    <div class="container">
        <!-- Message -->
        <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?>"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>
        
        <!-- Stats -->
        <div class="stats">
            <div class="stat-card">
                <div class="label">Total Servers</div>
                <div class="value"><?= $totalServers ?></div>
                <div class="sub">configured</div>
            </div>
            <div class="stat-card">
                <div class="label">Active Servers</div>
                <div class="value"><?= $activeServers ?></div>
                <div class="sub">visible to users</div>
            </div>
            <div class="stat-card">
                <div class="label">Premium Servers</div>
                <div class="value"><?= $premiumServers ?></div>
                <div class="sub">premium tier</div>
            </div>
        </div>
        
        <!-- Add Server -->
        <div class="section-title">
            Add New Server
        </div>
        <div class="form-card">
            <form method="POST">
                <input type="hidden" name="action" value="add">
                <div class="form-grid">
                    <div class="form-group">
                        <label>Server Name *</label>
                        <input type="text" name="name" placeholder="e.g. US East #1" required>
                    </div>
                    <div class="form-group">
                        <label>Country *</label>
                        <input type="text" name="country" placeholder="e.g. United States" required>
                    </div>
                    <div class="form-group">
                        <label>Country Code *</label>
                        <input type="text" name="country_code" placeholder="e.g. US" maxlength="2" required style="text-transform:uppercase;">
                    </div>
                    <div class="form-group">
                        <label>City</label>
                        <input type="text" name="city" placeholder="e.g. New York">
                    </div>
                    <div class="form-group">
                        <label>IP / Domain *</label>
                        <input type="text" name="ip_address" placeholder="e.g. us1.techvpnpro.com" required>
                    </div>
                    <div class="form-group">
                        <label>Load (0-100)</label>
                        <input type="number" name="load" value="0" min="0" max="100">
                    </div>
                </div>
                <div class="checkbox-group">
                    <label><input type="checkbox" name="is_active" checked> Active</label>
                    <label><input type="checkbox" name="is_premium"> Premium</label>
                </div>
                <div class="form-actions">
                    <button type="submit" class="btn-primary">+ Add Server</button>
                </div>
            </form>
        </div>
        
        <!-- Server List -->
        <div class="section-title">
            Server List
            <span style="font-weight:400; color:#555;"><?= $totalServers ?> servers</span>
        </div>
        <div class="table-card">
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Server</th>
                        <th>Address</th>
                        <th>Load</th>
                        <th>Status</th>
                        <th>Tier</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($servers)): ?>
                        <tr><td colspan="7" style="text-align:center; color:#555; padding:40px;">No servers configured. Add one above.</td></tr>
                    <?php endif; ?>
                    <?php foreach ($servers as $server): ?>
                        <tr>
                            <td style="color:#555;">#<?= $server['id'] ?></td>
                            <td>
                                <span style="font-size:18px; margin-right:8px;"><?= getFlag($server['country_code']) ?></span>
                                <span class="server-name"><?= htmlspecialchars($server['name']) ?></span>
                                <?php if ($server['city']): ?>
                                    <br><span style="font-size:12px; color:#555; margin-left:30px;"><?= htmlspecialchars($server['city']) ?>, <?= htmlspecialchars($server['country']) ?></span>
                                <?php endif; ?>
                            </td>
                            <td><span class="server-ip"><?= htmlspecialchars($server['ip_address']) ?></span></td>
                            <td>
                                <div class="load-bar">
                                    <div class="load-fill <?= $server['load'] < 30 ? 'load-low' : ($server['load'] < 70 ? 'load-mid' : 'load-high') ?>" style="width:<?= $server['load'] ?>%;"></div>
                                </div>
                                <span style="font-size:12px; color:#666; margin-left:6px;"><?= $server['load'] ?>%</span>
                            </td>
                            <td>
                                <span class="badge-active <?= $server['is_active'] ? 'badge-on' : 'badge-off' ?>">
                                    <?= $server['is_active'] ? 'ACTIVE' : 'DISABLED' ?>
                                </span>
                            </td>
                            <td>
                                <span class="badge-active <?= $server['is_premium'] ? 'badge-premium' : 'badge-free' ?>">
                                    <?= $server['is_premium'] ? 'PREMIUM' : 'FREE' ?>
                                </span>
                            </td>
                            <td>
                                <div class="actions">
                                    <button class="btn-icon" title="Edit" onclick="openEditModal(<?= htmlspecialchars(json_encode($server)) ?>)">&#9998;</button>
                                    <form method="POST" style="display:inline;">
                                        <input type="hidden" name="action" value="toggle">
                                        <input type="hidden" name="server_id" value="<?= $server['id'] ?>">
                                        <button type="submit" class="btn-icon" title="Toggle Active">
                                            <?= $server['is_active'] ? '&#9724;' : '&#9654;' ?>
                                        </button>
                                    </form>
                                    <form method="POST" style="display:inline;" onsubmit="return confirm('Delete <?= htmlspecialchars($server['name']) ?>?');">
                                        <input type="hidden" name="action" value="delete">
                                        <input type="hidden" name="server_id" value="<?= $server['id'] ?>">
                                        <button type="submit" class="btn-icon danger" title="Delete">&#10005;</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        
        <!-- API Info -->
        <div class="section-title">API Endpoint</div>
        <div class="api-info">
            <div class="label" style="font-size:12px; color:#666;">The iOS app fetches the server list from:</div>
            <div class="api-url">https://techvpnpro.com/api/servers.json</div>
            <p style="font-size:12px; color:#555; margin-top:12px;">Changes are instant. Add or remove servers here and the app picks them up automatically.</p>
        </div>
    </div>
    
    <!-- Edit Modal -->
    <div class="modal-overlay" id="editModal">
        <div class="modal">
            <h3>Edit Server</h3>
            <form method="POST" id="editForm">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="server_id" id="edit_id">
                <div class="form-grid">
                    <div class="form-group">
                        <label>Server Name</label>
                        <input type="text" name="name" id="edit_name" required>
                    </div>
                    <div class="form-group">
                        <label>Country</label>
                        <input type="text" name="country" id="edit_country" required>
                    </div>
                    <div class="form-group">
                        <label>Country Code</label>
                        <input type="text" name="country_code" id="edit_country_code" maxlength="2" required style="text-transform:uppercase;">
                    </div>
                    <div class="form-group">
                        <label>City</label>
                        <input type="text" name="city" id="edit_city">
                    </div>
                    <div class="form-group">
                        <label>IP / Domain</label>
                        <input type="text" name="ip_address" id="edit_ip_address" required>
                    </div>
                    <div class="form-group">
                        <label>Load (0-100)</label>
                        <input type="number" name="load" id="edit_load" min="0" max="100">
                    </div>
                </div>
                <div class="checkbox-group">
                    <label><input type="checkbox" name="is_active" id="edit_is_active"> Active</label>
                    <label><input type="checkbox" name="is_premium" id="edit_is_premium"> Premium</label>
                </div>
                <div class="form-actions">
                    <button type="submit" class="btn-primary">Save Changes</button>
                    <button type="button" class="btn-sm" onclick="document.getElementById('editModal').classList.remove('active')">Cancel</button>
                </div>
            </form>
        </div>
    </div>
    
    <!-- Settings Modal -->
    <div class="modal-overlay" id="settingsModal">
        <div class="modal">
            <h3>Settings</h3>
            <form method="POST">
                <input type="hidden" name="action" value="change_password">
                <div class="form-group" style="margin-bottom:16px;">
                    <label>New Password</label>
                    <input type="password" name="new_password" required minlength="8" style="width:100%; padding:10px 12px; background:#0a0a0a; border:1px solid #333; border-radius:6px; color:#e0e0e0; font-size:14px;">
                </div>
                <div class="form-group" style="margin-bottom:20px;">
                    <label>Confirm Password</label>
                    <input type="password" name="confirm_password" required minlength="8" style="width:100%; padding:10px 12px; background:#0a0a0a; border:1px solid #333; border-radius:6px; color:#e0e0e0; font-size:14px;">
                </div>
                <div class="form-actions">
                    <button type="submit" class="btn-primary">Change Password</button>
                    <button type="button" class="btn-sm" onclick="document.getElementById('settingsModal').classList.remove('active')">Cancel</button>
                </div>
            </form>
        </div>
    </div>
    
    <script>
        function openEditModal(server) {
            document.getElementById('edit_id').value = server.id;
            document.getElementById('edit_name').value = server.name;
            document.getElementById('edit_country').value = server.country;
            document.getElementById('edit_country_code').value = server.country_code;
            document.getElementById('edit_city').value = server.city || '';
            document.getElementById('edit_ip_address').value = server.ip_address;
            document.getElementById('edit_load').value = server.load;
            document.getElementById('edit_is_active').checked = server.is_active;
            document.getElementById('edit_is_premium').checked = server.is_premium;
            document.getElementById('editModal').classList.add('active');
        }
        
        // Close modals on overlay click
        document.querySelectorAll('.modal-overlay').forEach(overlay => {
            overlay.addEventListener('click', function(e) {
                if (e.target === this) this.classList.remove('active');
            });
        });
    </script>
</body>
</html>
