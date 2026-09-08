#!/bin/bash
# ============================================================
# Tech VPN Pro — Automated strongSwan IKEv2 Server Setup (v2)
# Uses Let's Encrypt for trusted certificates (no manual cert install)
# Run this on your Mac — it will upload and execute on the VPS
# ============================================================

VPN_USER="techvpn"
VPN_PASS="TechVPN@2026!"
ADMIN_EMAIL="admin@techvpnpro.com"

echo "============================================"
echo "  Tech VPN Pro — Server Setup (v2)"
echo "  Let's Encrypt + IKEv2"
echo "============================================"
echo ""

# Ask for server details
read -p "  Server domain (e.g., fr1.techvpnpro.com): " SERVER_DOMAIN
read -p "  Server IP address: " SERVER_IP
read -p "  SSH username [root]: " SSH_USER
SSH_USER="${SSH_USER:-root}"

echo ""

# Validate inputs
if [ -z "$SERVER_DOMAIN" ] || [ -z "$SERVER_IP" ]; then
    echo "  ERROR: Domain and IP are required!"
    exit 1
fi

echo "  Domain:  $SERVER_DOMAIN"
echo "  IP:      $SERVER_IP"
echo ""

# Verify DNS resolves correctly
echo "  Checking DNS resolution..."
RESOLVED_IP=$(dig +short "$SERVER_DOMAIN" @8.8.8.8 2>/dev/null | tail -1)
if [ "$RESOLVED_IP" != "$SERVER_IP" ]; then
    echo "  WARNING: $SERVER_DOMAIN does not resolve to $SERVER_IP"
    echo "  Currently resolves to: ${RESOLVED_IP:-NXDOMAIN}"
    echo ""
    read -p "  Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "  Aborted. Please fix DNS and try again."
        exit 1
    fi
else
    echo "  DNS OK: $SERVER_DOMAIN -> $RESOLVED_IP"
fi

echo ""

# Step 1: Clean up any previous install
echo "  [Step 1/4] Cleaning up previous install..."
echo "  (Enter your SSH password when prompted)"
echo ""
ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "\
    chattr -i /usr/sbin/ipsec 2>/dev/null; \
    chattr -i /usr/bin/pki 2>/dev/null; \
    chattr -i /usr/bin/pt-tls-client 2>/dev/null; \
    chattr -i /usr/bin/tpm_extendpcr 2>/dev/null; \
    chattr -ia /usr/sbin/ 2>/dev/null; \
    chattr -ia /usr/bin/ 2>/dev/null; \
    dpkg --configure -a 2>/dev/null; \
    apt-get -f install -y 2>/dev/null; \
    rm -f /tmp/vpn-setup-v2.sh 2>/dev/null; \
    echo 'Cleanup done'"

# Create the remote setup script (clean up any leftover temp files first)
rm -f /tmp/vpn-setup-v2-*.sh 2>/dev/null
REMOTE_SCRIPT="/tmp/vpn-setup-v2-$$.sh"
cat > "$REMOTE_SCRIPT" << ENDSCRIPT
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

SERVER_DOMAIN="$SERVER_DOMAIN"
SERVER_IP="$SERVER_IP"
VPN_USER="$VPN_USER"
VPN_PASS="$VPN_PASS"
ADMIN_EMAIL="$ADMIN_EMAIL"
CLIENT_POOL="10.10.10.0/24"
DNS_SERVERS="1.1.1.1,8.8.8.8"

echo "============================================"
echo "  Setting up IKEv2 VPN with Let's Encrypt"
echo "  Domain: \$SERVER_DOMAIN"
echo "  IP:     \$SERVER_IP"
echo "============================================"
echo ""

# Step 0: Create swap if none exists
if [ ! -f /swapfile ]; then
    echo "[0/9] Creating 1GB swap..."
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "  Done"
else
    echo "[0/9] Swap already exists, skipping"
fi

# Step 1: Update packages
echo "[1/9] Updating package list..."
apt-get update -y
echo "  Done"

# Step 2: Install strongSwan + certbot
echo "[2/9] Installing strongSwan and Certbot..."
chattr -i /usr/sbin/ipsec /usr/bin/pki /usr/bin/pt-tls-client /usr/bin/tpm_extendpcr 2>/dev/null || true
chattr -ia /usr/sbin/ /usr/bin/ 2>/dev/null || true
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins \
    libcharon-extauth-plugins libstrongswan-extra-plugins certbot
echo "  Done"

# Step 3: Stop any services using port 80 (needed for certbot)
echo "[3/9] Preparing for Let's Encrypt certificate..."
systemctl stop apache2 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
# Stop strongSwan cleanly and remove stale PID files
ipsec stop 2>/dev/null || true
killall -9 charon 2>/dev/null || true
killall -9 starter 2>/dev/null || true
rm -f /var/run/charon.pid /var/run/starter.charon.pid 2>/dev/null || true
sleep 1
echo "  Done"

# Step 4: Obtain Let's Encrypt certificate
echo "[4/9] Obtaining Let's Encrypt certificate for \$SERVER_DOMAIN..."
certbot certonly --standalone \
    -d \$SERVER_DOMAIN \
    --non-interactive \
    --agree-tos \
    -m \$ADMIN_EMAIL \
    --key-type rsa \
    --preferred-challenges http

if [ \$? -ne 0 ]; then
    echo ""
    echo "  ERROR: Failed to obtain certificate!"
    echo "  Make sure:"
    echo "    1. DNS record points \$SERVER_DOMAIN to \$SERVER_IP"
    echo "    2. Port 80 is open"
    echo "    3. No other service is using port 80"
    exit 1
fi
echo "  Certificate obtained!"

# Step 5: Copy Let's Encrypt certs to strongSwan
echo "[5/9] Copying certificates to strongSwan..."
# Remove old certs (self-signed or symlinks)
rm -f /etc/ipsec.d/certs/server-cert.pem
rm -f /etc/ipsec.d/private/server-key.pem
rm -f /etc/ipsec.d/cacerts/ca-cert.pem

# Copy actual cert files (symlinks don't work - strongSwan can't follow them
# through /etc/letsencrypt/archive/ restricted permissions)
cp -L /etc/letsencrypt/live/\$SERVER_DOMAIN/fullchain.pem /etc/ipsec.d/certs/server-cert.pem
cp -L /etc/letsencrypt/live/\$SERVER_DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem
echo "  Done"

# Step 6: Configure strongSwan with domain identity
echo "[6/9] Configuring strongSwan..."
cp /etc/ipsec.conf /etc/ipsec.conf.bak 2>/dev/null || true

cat > /etc/ipsec.conf << IPSECEOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=\$SERVER_DOMAIN
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=\$CLIENT_POOL
    rightdns=\$DNS_SERVERS
    rightsendcert=never
    ike=aes256-sha256-modp2048,aes256gcm16-sha256-modp2048!
    esp=aes256-sha256,aes256gcm16!
    mobike=yes
    eap_identity=%identity
    fragmentation=yes
IPSECEOF
echo "  Done"

# Step 7: Configure credentials
echo "[7/9] Setting up VPN credentials..."
cat > /etc/ipsec.secrets << SECEOF
: RSA "server-key.pem"
\$VPN_USER : EAP "\$VPN_PASS"
SECEOF
chmod 600 /etc/ipsec.secrets
echo "  Done"

# Step 8: Network configuration (IP forwarding + NAT)
echo "[8/9] Configuring network..."

# Detect network interface
IFACE=\$(ip route show default | awk '/default/ {print \$5}' | head -1)
IFACE=\${IFACE:-eth0}
echo "  Network interface: \$IFACE"

# IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.all.send_redirects=0
sysctl -w net.ipv6.conf.all.forwarding=1

cat > /etc/sysctl.d/99-vpn.conf << 'SYSEOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv6.conf.all.forwarding=1
net.core.rmem_max=16777216
net.core.wmem_max=16777216
SYSEOF

# Load nf_conntrack if available (some VPS kernels don't have it)
modprobe nf_conntrack 2>/dev/null && {
    sysctl -w net.netfilter.nf_conntrack_max=262144 2>/dev/null || true
    echo "net.netfilter.nf_conntrack_max=262144" >> /etc/sysctl.d/99-vpn.conf
} || echo "  nf_conntrack not available (ok for most VPS)"

# NAT masquerade (direct iptables — works with or without ufw)
iptables -t nat -C POSTROUTING -s 10.10.10.0/24 -o \$IFACE -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o \$IFACE -j MASQUERADE

# Persist iptables rules
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y iptables-persistent 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

# Open firewall ports (ufw may or may not be installed)
if command -v ufw &>/dev/null; then
    if ! grep -q "POSTROUTING.*10.10.10" /etc/ufw/before.rules 2>/dev/null; then
        sed -i "1i# NAT for VPN\n*nat\n-A POSTROUTING -s 10.10.10.0/24 -o \$IFACE -j MASQUERADE\nCOMMIT\n" /etc/ufw/before.rules
    fi
    sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    ufw allow OpenSSH 2>/dev/null || true
    ufw allow 500/udp 2>/dev/null || true
    ufw allow 4500/udp 2>/dev/null || true
    ufw allow 80/tcp 2>/dev/null || true
    ufw --force enable 2>/dev/null || true
else
    echo "  ufw not found — using iptables only (NAT rule already added)"
fi
echo "  Done"

# Step 9: Setup auto-renewal + start strongSwan
echo "[9/9] Setting up auto-renewal and starting VPN..."

# Create certbot renewal hook (copies new certs + restarts strongSwan)
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/strongswan.sh << HOOKEOF
#!/bin/bash
# Copy renewed certs to strongSwan and restart
cp -L /etc/letsencrypt/live/\$SERVER_DOMAIN/fullchain.pem /etc/ipsec.d/certs/server-cert.pem
cp -L /etc/letsencrypt/live/\$SERVER_DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem
ipsec reload
ipsec restart
HOOKEOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/strongswan.sh

# Clean up any stale PID files before starting
ipsec stop 2>/dev/null || true
killall -9 charon 2>/dev/null || true
killall -9 starter 2>/dev/null || true
rm -f /var/run/charon.pid /var/run/starter.charon.pid 2>/dev/null || true
sleep 1

# Start strongSwan
systemctl enable strongswan-starter
systemctl restart strongswan-starter
sleep 3

if systemctl is-active --quiet strongswan-starter && ipsec status > /dev/null 2>&1; then
    echo "  strongSwan is running!"
else
    echo "  WARNING: strongSwan may have issues. Checking..."
    ipsec statusall
fi

# Verify certbot timer
echo ""
echo "  Cert auto-renewal status:"
systemctl list-timers | grep certbot || echo "  (certbot timer will be set up on next reboot)"

echo ""
echo "============================================"
echo "  VPN SERVER SETUP COMPLETE!"
echo "============================================"
echo ""
echo "  Domain:       \$SERVER_DOMAIN"
echo "  Server IP:    \$SERVER_IP"
echo "  VPN Username: \$VPN_USER"
echo "  VPN Password: \$VPN_PASS"
echo "  Protocol:     IKEv2 + EAP-MSCHAPv2"
echo "  Certificate:  Let's Encrypt (auto-renews)"
echo ""
echo "  No manual certificate install needed!"
echo "  Users just connect with username/password."
echo ""
ENDSCRIPT

# Step 2: Upload the script
echo ""
echo "  [Step 2/4] Uploading setup script to server..."
echo "  (Enter your SSH password when prompted)"
echo ""
scp -o StrictHostKeyChecking=no "$REMOTE_SCRIPT" "$SSH_USER@$SERVER_IP:/tmp/vpn-setup-v2.sh"

if [ $? -ne 0 ]; then
    echo "  ERROR: Failed to upload script. Check SSH credentials."
    rm -f "$REMOTE_SCRIPT"
    exit 1
fi

# Step 3: Open port 80 for certbot (if UFW is active)
echo ""
echo "  [Step 3/4] Opening port 80 for certificate issuance..."
echo ""
ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "ufw allow 80/tcp 2>/dev/null || true"

# Step 4: Execute the script
echo ""
echo "  [Step 4/4] Running setup on server..."
echo "  (Enter your SSH password when prompted)"
echo ""
ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "chmod +x /tmp/vpn-setup-v2.sh && /tmp/vpn-setup-v2.sh"

STATUS=$?
rm -f "$REMOTE_SCRIPT"

if [ $STATUS -ne 0 ]; then
    echo ""
    echo "  Setup encountered errors. SSH into the server to check:"
    echo "  ssh $SSH_USER@$SERVER_IP"
    echo "  Then run: ipsec statusall"
    exit 1
fi

echo ""
echo "============================================"
echo "  ALL DONE! NO CERTIFICATE INSTALL NEEDED!"
echo "============================================"
echo ""
echo "  Your VPN is ready at: $SERVER_DOMAIN"
echo ""
echo "  Users can connect with:"
echo "    Server:   $SERVER_DOMAIN"
echo "    Username: $VPN_USER"
echo "    Password: $VPN_PASS"
echo ""
echo "  The certificate auto-renews every 60-90 days."
echo "  No action needed from you or your users."
echo ""
echo "============================================"
