#!/bin/bash
# ============================================================
# Tech VPN — Automated strongSwan IKEv2 Server Setup
# Run this on your Mac — it will upload and execute on the VPS
# ============================================================

VPN_USER="techvpn"
VPN_PASS="TechVPN@2026!"

echo "============================================"
echo "  Tech VPN — VPN Server Setup"
echo "============================================"
echo ""

# Ask for SSH login details
read -p "  Server IP address: " SERVER_IP
read -p "  SSH username [root]: " SSH_USER
SSH_USER="${SSH_USER:-root}"

echo ""

# First, fix immutable file attrs + broken dpkg state from previous attempt
echo "  [Step 1/3] Cleaning up previous failed install..."
echo "  (Enter your SSH password when prompted)"
echo ""
ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "\
    echo 'Removing immutable file attributes...'; \
    chattr -i /usr/sbin/ipsec 2>/dev/null; \
    chattr -i /usr/bin/pki 2>/dev/null; \
    chattr -i /usr/bin/pt-tls-client 2>/dev/null; \
    chattr -i /usr/bin/tpm_extendpcr 2>/dev/null; \
    chattr -ia /usr/sbin/ 2>/dev/null; \
    chattr -ia /usr/bin/ 2>/dev/null; \
    echo 'Fixing broken packages...'; \
    dpkg --configure -a; \
    apt-get -f install -y; \
    echo 'Cleanup done'"

# Create the remote script as a temp file
REMOTE_SCRIPT=$(mktemp /tmp/vpn-setup-XXXXXX.sh)
cat > "$REMOTE_SCRIPT" << ENDSCRIPT
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

SERVER_IP="$SERVER_IP"
VPN_USER="$VPN_USER"
VPN_PASS="$VPN_PASS"
CA_NAME="Tech VPN CA"
CLIENT_POOL="10.10.10.0/24"
DNS_SERVERS="1.1.1.1,8.8.8.8"

echo "============================================"
echo "  Setting up IKEv2 VPN on \$SERVER_IP"
echo "============================================"
echo ""

# Step 0: Create swap if none exists
if [ ! -f /swapfile ]; then
    echo "[0/8] Creating 1GB swap..."
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "  Done"
else
    echo "[0/8] Swap already exists, skipping"
fi

# Step 1: Update package list
echo "[1/8] Updating package list..."
apt-get update -y
echo "  Done"

# Step 2: Install strongSwan
echo "[2/8] Installing strongSwan..."
# Remove immutable attributes that block dpkg writes
chattr -i /usr/sbin/ipsec /usr/bin/pki /usr/bin/pt-tls-client /usr/bin/tpm_extendpcr 2>/dev/null || true
chattr -ia /usr/sbin/ /usr/bin/ 2>/dev/null || true
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins
echo "  Done"

# Step 3: Generate certificates
echo "[3/8] Generating certificates..."
mkdir -p ~/pki/{cacerts,certs,private}
chmod 700 ~/pki

pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem

pki --self --ca --lifetime 3650 \
    --in ~/pki/private/ca-key.pem \
    --type rsa \
    --dn "CN=\$CA_NAME" \
    --outform pem > ~/pki/cacerts/ca-cert.pem

pki --gen --type rsa --size 2048 --outform pem > ~/pki/private/server-key.pem

pki --pub --in ~/pki/private/server-key.pem --type rsa \
    | pki --issue --lifetime 730 \
    --cacert ~/pki/cacerts/ca-cert.pem \
    --cakey ~/pki/private/ca-key.pem \
    --dn "CN=\$SERVER_IP" \
    --san="\$SERVER_IP" \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem > ~/pki/certs/server-cert.pem

cp ~/pki/cacerts/ca-cert.pem /etc/ipsec.d/cacerts/
cp ~/pki/certs/server-cert.pem /etc/ipsec.d/certs/
cp ~/pki/private/server-key.pem /etc/ipsec.d/private/
echo "  Done"

# Step 4: Configure strongSwan
echo "[4/8] Configuring strongSwan..."
cp /etc/ipsec.conf /etc/ipsec.conf.bak 2>/dev/null || true

cat > /etc/ipsec.conf << 'IPSECEOF'
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
    leftid=SERVER_IP_PLACEHOLDER
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=1.1.1.1,8.8.8.8
    rightsendcert=never
    ike=aes256-sha256-modp2048,aes256gcm16-sha256-modp2048!
    esp=aes256-sha256,aes256gcm16!
    mobike=yes
    eap_identity=%identity
    fragmentation=yes
IPSECEOF

sed -i "s/SERVER_IP_PLACEHOLDER/\$SERVER_IP/" /etc/ipsec.conf
echo "  Done"

# Step 5: Configure credentials
echo "[5/8] Setting up VPN credentials..."
cat > /etc/ipsec.secrets << SECEOF
: RSA "server-key.pem"
\$VPN_USER : EAP "\$VPN_PASS"
SECEOF
chmod 600 /etc/ipsec.secrets
echo "  Done"

# Step 6: Enable IP forwarding
echo "[6/8] Enabling IP forwarding..."
cat > /etc/sysctl.d/99-vpn.conf << 'SYSEOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv6.conf.all.forwarding=1
SYSEOF
sysctl -p /etc/sysctl.d/99-vpn.conf
echo "  Done"

# Step 7: Configure firewall + NAT
echo "[7/8] Configuring firewall..."

IFACE=\$(ip route show default | awk '/default/ {print \$5}' | head -1)
echo "  Network interface: \$IFACE"

if ! grep -q "POSTROUTING.*10.10.10" /etc/ufw/before.rules 2>/dev/null; then
    sed -i "1i# NAT for VPN\n*nat\n-A POSTROUTING -s 10.10.10.0/24 -o \$IFACE -j MASQUERADE\nCOMMIT\n" /etc/ufw/before.rules
fi

sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

ufw allow OpenSSH
ufw allow 500/udp
ufw allow 4500/udp
ufw --force enable
echo "  Done"

# Step 8: Start strongSwan
echo "[8/8] Starting strongSwan..."
ipsec restart
systemctl enable strongswan-starter
sleep 2

if ipsec status > /dev/null 2>&1; then
    echo "  strongSwan is running!"
else
    echo "  WARNING: strongSwan may have issues"
    ipsec statusall
fi

echo ""
echo "============================================"
echo "  VPN SERVER SETUP COMPLETE!"
echo "============================================"
echo ""
echo "  Server IP:     \$SERVER_IP"
echo "  VPN Username:  \$VPN_USER"
echo "  VPN Password:  \$VPN_PASS"
echo "  Protocol:      IKEv2 + EAP-MSCHAPv2"
echo ""
echo "--- CA CERTIFICATE ---"
cat ~/pki/cacerts/ca-cert.pem
echo "--- END CA CERTIFICATE ---"
echo ""
ENDSCRIPT

# Upload the script to the server
echo ""
echo "  [Step 2/3] Uploading setup script to server..."
echo "  (Enter your SSH password when prompted)"
echo ""
scp -o StrictHostKeyChecking=no "$REMOTE_SCRIPT" "$SSH_USER@$SERVER_IP:/tmp/vpn-setup.sh"

# Execute the script on the server
echo ""
echo "  [Step 3/3] Running setup on server..."
echo "  (Enter your SSH password when prompted)"
echo ""
ssh -t -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "chmod +x /tmp/vpn-setup.sh && /tmp/vpn-setup.sh"

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
echo "  NEXT STEPS:"
echo "============================================"
echo ""
echo "  1. Copy the CA certificate above (between the --- markers)"
echo "     Save it as ca-cert.pem and email it to your iPhone"
echo ""
echo "  2. On iPhone:"
echo "     - Settings > General > VPN & Device Management > Install"
echo "     - Settings > General > About > Certificate Trust Settings > Enable"
echo ""
echo "  3. In the Tech VPN app, use:"
echo "     Username: $VPN_USER"
echo "     Password: $VPN_PASS"
echo ""
echo "============================================"
