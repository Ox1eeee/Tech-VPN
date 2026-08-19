#!/bin/bash
# ============================================================
# Tech VPN — Deploy Backend API to VPS
# Uploads and runs the Node.js backend on your VPS
# ============================================================

echo "============================================"
echo "  Tech VPN — Deploy Backend to VPS"
echo "============================================"
echo ""

read -p "  Server IP address [169.58.172.181]: " SERVER_IP
SERVER_IP="${SERVER_IP:-169.58.172.181}"
read -p "  SSH username [root]: " SSH_USER
SSH_USER="${SSH_USER:-root}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  [1/4] Installing Node.js on server..."
echo "  (Enter your SSH password when prompted)"
echo ""

ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "\
    if command -v node &>/dev/null; then \
        echo 'Node.js already installed:' && node --version; \
    else \
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
        apt-get install -y nodejs; \
    fi"

echo ""
echo "  [2/4] Uploading backend files..."
echo ""

ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "mkdir -p /opt/techvpn-backend"
scp -o StrictHostKeyChecking=no "$SCRIPT_DIR/server.js" "$SCRIPT_DIR/package.json" "$SSH_USER@$SERVER_IP:/opt/techvpn-backend/"

echo ""
echo "  [3/4] Installing dependencies on server..."
echo ""

ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "\
    cd /opt/techvpn-backend && \
    npm install --production"

echo ""
echo "  [4/4] Starting backend as a service..."
echo ""

ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" bash -s << 'REMOTE'
# Create systemd service
cat > /etc/systemd/system/techvpn-api.service << 'EOF'
[Unit]
Description=Tech VPN Backend API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/techvpn-backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=PORT=3000
Environment=JWT_SECRET=tech-vpn-production-secret-2026

[Install]
WantedBy=multi-user.target
EOF

# Open port 3000
ufw allow 3000/tcp 2>/dev/null

# Start service
systemctl daemon-reload
systemctl enable techvpn-api
systemctl restart techvpn-api
sleep 2

if systemctl is-active --quiet techvpn-api; then
    echo ""
    echo "============================================"
    echo "  Backend API is running!"
    echo "============================================"
    echo "  URL: http://$(hostname -I | awk '{print $1}'):3000"
    echo "  Health check: http://$(hostname -I | awk '{print $1}'):3000/api/health"
    echo ""
else
    echo "  Failed to start backend. Check: journalctl -u techvpn-api"
fi
REMOTE

echo ""
echo "  Done! Your backend API is live at:"
echo "  http://$SERVER_IP:3000"
echo ""
