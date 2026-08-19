# Tech VPN Pro - Commercial-Grade Implementation Guide

> **Domain:** techvpnpro.com (Namecheap)
> **Current Server:** fr1.techvpnpro.com → 169.58.172.181

## Overview

This guide covers upgrading Tech VPN from a self-signed certificate setup (requires manual cert install) to a production-ready commercial VPN service that supports:

- **Zero-config connection** - No certificate installation by users
- **Multiple simultaneous users** - Hundreds of concurrent connections per server
- **Multiple VPN servers** - Scale across regions with a single domain
- **Auto-reconnect** - MOBIKE support for seamless WiFi/Cellular switching

---

## Part 1: Domain & Let's Encrypt Setup (No More Manual Cert Install)

### Why This Is Needed

Currently: Users must AirDrop `ca-cert.pem`, install it in Settings, and manually trust it.
After: Users install the app, tap "Allow" for VPN config, and connect. That's it.

### Prerequisites

- **One domain name** (~$10/year from Namecheap, Cloudflare, or Google Domains)
- DNS access to create A records

### Step 1: Buy a Domain & Configure DNS

Domain: `techvpnpro.com` (purchased from Namecheap). Create A records for each VPN server:

```
fr1.techvpnpro.com  →  169.58.172.181   (France - ACTIVE)
us1.techvpnpro.com  →  <US server IP>    (future)
sg1.techvpnpro.com  →  <SG server IP>    (future)
uk1.techvpnpro.com  →  <UK server IP>    (future)
```

### Step 2: Install Let's Encrypt on VPN Server

SSH into the server and run:

```bash
# Stop strongSwan temporarily (certbot needs port 80)
ipsec stop

# Install certbot
apt-get update && apt-get install -y certbot

# Get a free, publicly-trusted certificate
certbot certonly --standalone -d fr1.techvpnpro.com

# Certificate files will be at:
#   /etc/letsencrypt/live/fr1.techvpnpro.com/fullchain.pem  (server cert + chain)
#   /etc/letsencrypt/live/fr1.techvpnpro.com/privkey.pem    (private key)
```

### Step 3: Configure strongSwan with Let's Encrypt Cert

```bash
# Remove old self-signed certs
rm -f /etc/ipsec.d/certs/server-cert.pem
rm -f /etc/ipsec.d/private/server-key.pem
rm -f /etc/ipsec.d/cacerts/ca-cert.pem

# IMPORTANT: Copy files, NOT symlink. strongSwan cannot follow symlinks
# through /etc/letsencrypt/archive/ restricted permissions.
cp -L /etc/letsencrypt/live/fr1.techvpnpro.com/fullchain.pem /etc/ipsec.d/certs/server-cert.pem
cp -L /etc/letsencrypt/live/fr1.techvpnpro.com/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem
```

### Step 4: Update ipsec.conf

Change `leftid` from the IP to the domain:

```conf
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
    leftid=fr1.techvpnpro.com       # <-- CHANGED: domain instead of IP
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
```

### Step 5: Restart strongSwan

```bash
ipsec restart
ipsec statusall   # verify it's running
```

### Step 6: Auto-Renewal (Let's Encrypt expires every 90 days)

```bash
# Create renewal hook script (must COPY certs, not just restart)
DOMAIN="fr1.techvpnpro.com"
cat > /etc/letsencrypt/renewal-hooks/deploy/strongswan.sh << EOF
#!/bin/bash
# Copy renewed certs to strongSwan and restart
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/ipsec.d/certs/server-cert.pem
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem
ipsec reload
ipsec restart
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/strongswan.sh

# Test renewal (dry-run)
certbot renew --dry-run

# Certbot auto-renewal is already set up via systemd timer
# Verify: systemctl list-timers | grep certbot
```

### Step 7: Update iOS App

In `APIService.swift`, update the server config:

```swift
private let vpnServers: [VPNServer] = [
    VPNServer(id: 1, name: "France #1", country: "FR", ipAddress: "fr1.techvpnpro.com", load: 10)
]

func fetchServerConfig(serverId: Int) async throws -> VPNServerConfig {
    guard let server = vpnServers.first(where: { $0.id == serverId }) else {
        throw APIError.serverError("Server not found")
    }
    
    return VPNServerConfig(
        serverAddress: server.ipAddress,          // fr1.techvpnpro.com
        remoteIdentifier: server.ipAddress,       // must match leftid in ipsec.conf
        certificate: nil,
        presharedKey: nil
    )
}
```

---

## Part 2: Supporting Multiple Simultaneous Users

### Current Capacity

The current strongSwan config already supports multiple users, but is limited by:
- **IP Pool Size**: `10.10.10.0/24` = 253 simultaneous connections
- **Single credential**: All users share `techvpn / TechVPN@2026!`
- **Server resources**: RAM, CPU, bandwidth

### Scaling to Handle Real Traffic

#### A. Expand the IP Pool

For more than 253 users on one server, expand the pool:

```conf
# In ipsec.conf - change rightsourceip:
rightsourceip=10.10.0.0/16       # 65,534 addresses (unlikely to need this many)
```

Or use a `/22` for ~1000 users:
```conf
rightsourceip=10.10.8.0/22       # 1,022 addresses
```

#### B. Per-User Credentials (Recommended for Production)

Instead of one shared credential, give each app user their own VPN credentials.

**Option 1: Static credentials in ipsec.secrets**

```bash
# /etc/ipsec.secrets
: RSA "server-key.pem"
user1 : EAP "randomPass1!"
user2 : EAP "randomPass2!"
user3 : EAP "randomPass3!"
```

**Option 2: RADIUS authentication (Best for scale)**

Use FreeRADIUS to authenticate users against a database:

```bash
# Install FreeRADIUS
apt-get install -y freeradius freeradius-mysql

# strongSwan connects to RADIUS for auth
# Users are managed in a database (MySQL/PostgreSQL)
```

In `ipsec.conf`:
```conf
rightauth=eap-radius
```

This allows:
- Unlimited users without editing files
- User management via database/API
- Per-user bandwidth tracking
- Account enable/disable without restarting VPN

#### C. Server Resource Optimization

```bash
# /etc/sysctl.d/99-vpn-performance.conf

# Connection tracking
net.netfilter.nf_conntrack_max=262144

# Network buffers
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# IP forwarding (already set)
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# Reduce TIME_WAIT
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_tw_reuse=1
```

Apply: `sysctl -p /etc/sysctl.d/99-vpn-performance.conf`

#### D. Server Sizing Recommendations

| Users | Server Spec | IP Pool |
|-------|------------|---------|
| 1-50 | 1 vCPU, 1GB RAM, 1Gbps | /24 (253 IPs) |
| 50-200 | 2 vCPU, 2GB RAM, 1Gbps | /23 (510 IPs) |
| 200-500 | 4 vCPU, 4GB RAM, 2Gbps | /22 (1022 IPs) |
| 500+ | Multiple servers with load balancing | /22 per server |

---

## Part 3: Adding New VPN Servers

### Automated Setup Script (Per Server)

For each new VPN server, the process is:

1. **Provision a VPS** in the desired region
2. **Create DNS record**: `<region>.techvpn.app → <server IP>`
3. **Wait for DNS propagation** (~5 minutes)
4. **Run the setup script** (updated version below)

### New Server Checklist

```
[ ] VPS provisioned (Ubuntu 22.04+, 1GB+ RAM)
[ ] DNS A record created and propagated
[ ] Run setup script with domain parameter
[ ] Verify: ipsec statusall shows "listening on <IP>"
[ ] Test connection from iPhone
[ ] Add server to iOS app's server list
```

### Updated Setup Script Usage

```bash
# Run from your Mac:
./vpn-server-setup-v2.sh

# It will ask:
#   Server domain: sg1.techvpnpro.com
#   Server IP: 103.44.55.66
#   SSH user: root
```

---

## Part 4: iOS App Server List (Multiple Servers)

### APIService.swift

```swift
private let vpnServers: [VPNServer] = [
    VPNServer(id: 1, name: "France #1",      country: "FR", ipAddress: "fr1.techvpnpro.com", load: 10),
    VPNServer(id: 2, name: "United States",   country: "US", ipAddress: "us1.techvpnpro.com", load: 25),
    VPNServer(id: 3, name: "Singapore",       country: "SG", ipAddress: "sg1.techvpnpro.com", load: 15),
    VPNServer(id: 4, name: "United Kingdom",  country: "UK", ipAddress: "uk1.techvpnpro.com", load: 20),
    VPNServer(id: 5, name: "Japan",           country: "JP", ipAddress: "jp1.techvpnpro.com", load: 30),
]
```

### Dynamic Server List (Optional - Future)

Instead of hardcoding, fetch from your backend API or Supabase:

```swift
func fetchServers() async throws -> [VPNServer] {
    let url = URL(string: "https://api.techvpnpro.com/servers")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([VPNServer].self, from: data)
}
```

This lets you add/remove servers without app updates.

---

## Part 5: Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    USER'S iPHONE                         │
│                                                         │
│  ┌─────────────┐    ┌──────────────────────────────┐   │
│  │ Tech VPN App│───>│ iOS NetworkExtension (IKEv2)  │   │
│  │             │    │ - EAP-MSCHAPv2 auth           │   │
│  │ Server List │    │ - Auto-reconnect (MOBIKE)     │   │
│  │ Connect/Disc│    │ - Kill switch capable         │   │
│  └─────────────┘    └──────────────┬───────────────┘   │
└────────────────────────────────────┼───────────────────┘
                                     │ IKEv2 (UDP 500/4500)
                                     ▼
┌─────────────────────────────────────────────────────────┐
│                   VPN SERVERS                            │
│                                                         │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │fr1.techvpnpro  │  │us1.techvpnpro  │  │sg1.techvpnpro  │ │
│  │169.58.172.181│  │  45.33.22.11 │  │ 103.44.55.66 │ │
│  │              │  │              │  │              │ │
│  │ strongSwan   │  │ strongSwan   │  │ strongSwan   │ │
│  │ Let's Encrypt│  │ Let's Encrypt│  │ Let's Encrypt│ │
│  │ NAT/Firewall │  │ NAT/Firewall │  │ NAT/Firewall │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                         │
│  Each server: Independent cert, independent config      │
│  Shared: Same VPN credentials (or RADIUS for per-user) │
└─────────────────────────────────────────────────────────┘
```

---

## Part 6: Quick Reference - Full Server Setup Commands

Run these on a **new VPS** after DNS is configured:

```bash
#!/bin/bash
DOMAIN="fr1.techvpnpro.com"     # Change per server
VPN_USER="techvpn"
VPN_PASS="TechVPN@2026!"

# 1. Install packages
apt-get update && apt-get install -y strongswan strongswan-pki \
    libcharon-extra-plugins libcharon-extauth-plugins certbot

# 2. Get Let's Encrypt cert (MUST use --key-type rsa for IKEv2 compatibility)
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@techvpnpro.com --key-type rsa

# 3. Copy certs to strongSwan (DO NOT symlink - strongSwan can't follow the symlink chain)
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/ipsec.d/certs/server-cert.pem
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem

# 4. Configure strongSwan
cat > /etc/ipsec.conf << EOF
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
    leftid=$DOMAIN
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
EOF

# 5. Set credentials
cat > /etc/ipsec.secrets << EOF
: RSA "server-key.pem"
$VPN_USER : EAP "$VPN_PASS"
EOF
chmod 600 /etc/ipsec.secrets

# 6. Enable IP forwarding
cat > /etc/sysctl.d/99-vpn.conf << 'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv6.conf.all.forwarding=1
EOF
sysctl -p /etc/sysctl.d/99-vpn.conf

# 7. Firewall + NAT
IFACE=$(ip route show default | awk '/default/ {print $5}' | head -1)
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $IFACE -j MASQUERADE
ufw allow 500/udp
ufw allow 4500/udp
ufw allow 80/tcp    # For certbot renewal
ufw allow OpenSSH
ufw --force enable

# 8. Persist iptables
apt-get install -y iptables-persistent
netfilter-persistent save

# 9. Auto-renewal hook (must copy certs on renewal)
cat > /etc/letsencrypt/renewal-hooks/deploy/strongswan.sh << EOF
#!/bin/bash
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/ipsec.d/certs/server-cert.pem
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem
ipsec reload
ipsec restart
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/strongswan.sh

# 10. Start
ipsec restart
systemctl enable strongswan-starter
echo "VPN server ready: $DOMAIN"
```

---

## Action Items (In Order)

1. ~~**Buy a domain**~~ - DONE: `techvpnpro.com` from Namecheap
2. ~~**Create DNS A record**~~ - DONE: `fr1.techvpnpro.com` → `169.58.172.181`
3. **Wait for DNS propagation** (check: `dig fr1.techvpnpro.com`)
4. **Run setup script**: `./backend/vpn-server-setup-v2.sh`
5. ~~**Update iOS app**~~ - DONE: `APIService.swift` uses `fr1.techvpnpro.com`
6. **Test** - connect from iPhone without any cert install
7. **Delete** the old `ca-cert.pem` - no longer needed

---

## Security Notes

- Let's Encrypt certs auto-renew every 60-90 days (handled by certbot)
- EAP-MSCHAPv2 credentials are encrypted inside the IKEv2 tunnel
- All traffic is AES-256 encrypted
- MOBIKE ensures connection persists across network changes
- Consider per-user credentials (RADIUS) before launching publicly

---

## Known Issues & Gotchas (Lessons Learned)

### 1. NEVER symlink Let's Encrypt certs for strongSwan
strongSwan cannot follow the symlink chain through `/etc/letsencrypt/archive/` (restricted permissions). Always **copy** the files:
```bash
# WRONG - strongSwan will say "no private key found"
ln -sf /etc/letsencrypt/live/DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem

# CORRECT - copy the actual file
cp -L /etc/letsencrypt/live/DOMAIN/privkey.pem /etc/ipsec.d/private/server-key.pem
chmod 600 /etc/ipsec.d/private/server-key.pem
```

### 2. ALWAYS use `--key-type rsa` with certbot
Let's Encrypt defaults to ECDSA keys. iOS `NEVPNProtocolIKEv2` with `certificateType = .RSA` will reject ECDSA certs. Always specify:
```bash
certbot certonly --standalone -d DOMAIN --key-type rsa
```
If you already have an ECDSA cert, force renewal with RSA:
```bash
certbot certonly --standalone -d DOMAIN --key-type rsa --force-renewal --cert-name DOMAIN
```

### 3. Renewal hook must COPY, not just restart
The certbot deploy hook must copy the renewed certs to `/etc/ipsec.d/` before restarting strongSwan, otherwise strongSwan will still use the old (expired) copies.

### 4. Delete old VPN config on iPhone when changing server identity
If you change `remoteIdentifier` (e.g., from IP to domain), the old VPN config cached on the device must be deleted first: Settings > General > VPN & Device Management > delete "Tech VPN".
