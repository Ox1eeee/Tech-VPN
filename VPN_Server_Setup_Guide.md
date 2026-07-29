# Tech VPN — VPN Server Setup Guide

Complete guide to set up a strongSwan IKEv2 VPN server on a VPS and connect it to the Tech VPN iOS app.

---

## Architecture

```
┌──────────────┐          ┌──────────────────────┐
│  Tech VPN    │  IKEv2   │  Your VPS Server     │
│  iOS App     │ ◀──────▶ │  (strongSwan)        │
│              │  UDP 500  │                      │
│ NEVPNManager │  UDP 4500 │  Ubuntu 22.04/24.04  │
└──────────────┘          └──────────────────────┘
```

**Protocol**: IKEv2/IPsec  
**Auth**: EAP-MSCHAPv2 (username + password)  
**Encryption**: Negotiated by Apple's stack (AES-256, SHA-256, DH Group 14+)  
**MOBIKE**: Enabled (seamless WiFi ↔ Cellular)

---

## Step 1 — Get a VPS

Any VPS provider works. Recommended:
- **DigitalOcean** — $4-6/month droplet
- **Hetzner** — €3.79/month (best value)
- **Vultr** — $5/month
- **AWS Lightsail** — $3.50/month
- **Linode** — $5/month

**Requirements:**
- Ubuntu 22.04 or 24.04 LTS
- At least 1 CPU, 512MB RAM, 10GB disk
- Public IPv4 address
- Root/sudo access

**Once created, note your server's public IP address** (e.g., `203.0.113.50`)

---

## Step 2 — Initial Server Setup

SSH into your server:

```bash
ssh root@YOUR_SERVER_IP
```

Update the system:

```bash
apt update && apt upgrade -y
```

Set hostname (optional):

```bash
hostnamectl set-hostname vpn.yourdomain.com
```

---

## Step 3 — Install strongSwan

```bash
apt install -y strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins
```

Verify installation:

```bash
ipsec version
```

---

## Step 4 — Generate Certificates

IKEv2 requires X.509 certificates. You'll create:
1. A Certificate Authority (CA)
2. A server certificate signed by that CA

### 4.1 — Create directories

```bash
mkdir -p ~/pki/{cacerts,certs,private}
chmod 700 ~/pki
```

### 4.2 — Generate CA key and certificate

```bash
# Generate CA private key
pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem

# Generate CA certificate (valid 10 years)
pki --self --ca --lifetime 3650 \
    --in ~/pki/private/ca-key.pem \
    --type rsa \
    --dn "CN=Tech VPN CA" \
    --outform pem > ~/pki/cacerts/ca-cert.pem
```

### 4.3 — Generate server key and certificate

**IMPORTANT:** Replace `YOUR_SERVER_IP` with your actual VPS IP address.

```bash
# Generate server private key
pki --gen --type rsa --size 2048 --outform pem > ~/pki/private/server-key.pem

# Generate server certificate (valid 2 years)
pki --pub --in ~/pki/private/server-key.pem --type rsa \
    | pki --issue --lifetime 730 \
    --cacert ~/pki/cacerts/ca-cert.pem \
    --cakey ~/pki/private/ca-key.pem \
    --dn "CN=YOUR_SERVER_IP" \
    --san="YOUR_SERVER_IP" \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem > ~/pki/certs/server-cert.pem
```

> **Note**: If you have a domain (e.g., `vpn.yourdomain.com`), use that instead of the IP:
> `--dn "CN=vpn.yourdomain.com" --san="vpn.yourdomain.com" --san="YOUR_SERVER_IP"`

### 4.4 — Install certificates into strongSwan

```bash
cp ~/pki/cacerts/ca-cert.pem /etc/ipsec.d/cacerts/
cp ~/pki/certs/server-cert.pem /etc/ipsec.d/certs/
cp ~/pki/private/server-key.pem /etc/ipsec.d/private/
```

---

## Step 5 — Configure strongSwan

### 5.1 — Backup and replace ipsec.conf

```bash
mv /etc/ipsec.conf /etc/ipsec.conf.bak
```

Create new config:

```bash
cat > /etc/ipsec.conf << 'EOF'
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel

    # IKEv2 only
    keyexchange=ikev2

    # Don't close idle connections
    dpdaction=clear
    dpddelay=300s
    rekey=no

    # Server side
    left=%any
    leftid=YOUR_SERVER_IP
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0

    # Client side
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=1.1.1.1,8.8.8.8
    rightsendcert=never

    # Encryption (matches Apple's IKEv2 stack preferences)
    ike=aes256-sha256-modp2048,aes256-sha384-modp2048,aes256gcm16-sha256-modp2048!
    esp=aes256-sha256,aes256gcm16!

    # Enable MOBIKE (WiFi ↔ Cellular seamless handoff)
    mobike=yes

    # EAP identity
    eap_identity=%identity
    fragmentation=yes
EOF
```

**IMPORTANT:** Replace `YOUR_SERVER_IP` in `leftid=` with your actual server IP or domain.

### 5.2 — Configure VPN user credentials

```bash
cat > /etc/ipsec.secrets << 'EOF'
# Server certificate private key
: RSA "server-key.pem"

# VPN User credentials (username : EAP "password")
# Add one line per user:
testuser : EAP "StrongPassword123!"
user2 : EAP "AnotherPassword456!"
EOF
```

**These are the credentials you'll enter in the iOS app.**

Set permissions:

```bash
chmod 600 /etc/ipsec.secrets
```

---

## Step 6 — Configure Firewall & Networking

### 6.1 — Enable IP forwarding

```bash
cat >> /etc/sysctl.conf << 'EOF'

# VPN IP Forwarding
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv6.conf.all.forwarding=1
EOF

sysctl -p
```

### 6.2 — Configure UFW firewall

```bash
# Allow SSH (don't lock yourself out!)
ufw allow OpenSSH

# Allow IKEv2 VPN traffic
ufw allow 500/udp
ufw allow 4500/udp

# Enable UFW
ufw enable
```

### 6.3 — Configure NAT (masquerading)

Find your main network interface:

```bash
ip route show default
# Look for "dev eth0" or "dev ens3" etc.
```

Edit UFW before rules:

```bash
nano /etc/ufw/before.rules
```

Add these lines **BEFORE** the `*filter` section at the top:

```
# NAT for VPN clients
*nat
-A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE
COMMIT
```

> **Replace `eth0`** with your actual interface name (e.g., `ens3`, `enp1s0`)

Edit UFW sysctl:

```bash
nano /etc/ufw/sysctl.conf
```

Uncomment or add:

```
net/ipv4/ip_forward=1
```

Reload UFW:

```bash
ufw disable && ufw enable
```

---

## Step 7 — Start strongSwan

```bash
# Restart strongSwan to apply config
ipsec restart

# Check status
ipsec statusall
```

You should see `ikev2-vpn` connection loaded. No errors = ready.

Enable on boot:

```bash
systemctl enable strongswan-starter
```

---

## Step 8 — Get the CA Certificate for iOS

The iOS app needs to trust your CA certificate. Export it:

```bash
cat ~/pki/cacerts/ca-cert.pem
```

Copy the entire content (including `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`).

### Install on iPhone:

**Option A — Email it:**
1. Email the `ca-cert.pem` file to yourself
2. Open it on your iPhone
3. Go to **Settings → General → VPN & Device Management** → Install the profile
4. Go to **Settings → General → About → Certificate Trust Settings** → Enable full trust for "Tech VPN CA"

**Option B — Host it on a URL:**
1. Put `ca-cert.pem` on any HTTPS URL
2. Open that URL in Safari on iPhone
3. Install and trust as above

---

## Step 9 — Configure the iOS App

Now configure the Tech VPN app to connect to your server.

### 9.1 — Update the server list in the backend

Edit `backend/server.js` and replace the sample IP with your real server:

```javascript
const servers = [
    { id: 1, name: 'My VPN Server', country: 'Your Country', ip_address: 'YOUR_SERVER_IP', load: 10, active: true },
    // ... other servers
];
```

### 9.2 — Update VPN config endpoint

In `server.js`, the `/api/vpn/config/:serverId` route returns the config. Update the `remoteIdentifier` to match your server's `leftid`:

```javascript
res.json({
    serverAddress: server.ip_address,        // Your VPS IP
    remoteIdentifier: 'YOUR_SERVER_IP',      // Must match leftid in ipsec.conf
    certificate: null,
    presharedKey: null
});
```

### 9.3 — How the app connects (already implemented)

The `VPNManager.swift` already does this correctly:

```swift
let ikev2 = NEVPNProtocolIKEv2()
ikev2.serverAddress = config.serverAddress       // Your VPS IP
ikev2.remoteIdentifier = config.remoteIdentifier // Must match leftid
ikev2.localIdentifier = username                 // EAP username

ikev2.username = username                        // "testuser"
ikev2.passwordReference = keychain.persistentRef // "StrongPassword123!"
ikev2.authenticationMethod = .none               // Server uses cert
ikev2.useExtendedAuthentication = true           // EAP-MSCHAPv2
```

**The flow:**
1. User selects a server in the app
2. App calls `configureVPN()` with server IP + user credentials
3. iOS negotiates IKEv2 with strongSwan
4. strongSwan verifies EAP credentials from `ipsec.secrets`
5. Tunnel established ✓

---

## Step 10 — Test the Connection

### On the server, monitor logs:

```bash
journalctl -u strongswan-starter -f
```

### On the iPhone:
1. Make sure the CA certificate is installed and trusted
2. Open the Tech VPN app
3. Enter VPN credentials (username/password from `ipsec.secrets`)
4. Select the server and tap Connect

### Verify connection on server:

```bash
ipsec status
```

You should see an active CHILD_SA tunnel.

### Verify IP change on phone:
Visit https://whatismyipaddress.com — it should show your VPS IP.

---

## Troubleshooting

### "Unable to connect" / connection times out
- Check firewall: `ufw status` — ports 500/udp and 4500/udp must be open
- Check VPS provider firewall/security group (some providers have separate firewall)
- Verify strongSwan is running: `ipsec status`

### "Authentication failed"
- Credentials in `ipsec.secrets` must match exactly what's in the app
- Format: `username : EAP "password"` (note the spaces around `:`)
- Restart after changes: `ipsec restart`

### "Certificate error" / "Server identity could not be verified"
- The CA cert must be installed AND trusted on the iPhone
- `leftid` in `ipsec.conf` must match `remoteIdentifier` in the app
- The server cert's `--san` must include the server IP/domain

### MOBIKE not working (disconnects on network switch)
- Verify `mobike=yes` in ipsec.conf
- Verify `ikev2.disableMOBIKE = false` in VPNManager.swift (already set)
- Both UDP 500 and 4500 must be open

### Check logs
```bash
# strongSwan logs
journalctl -u strongswan-starter --no-pager -n 50

# More verbose logging (temporary)
# In ipsec.conf, change: charondebug="ike 2, knl 2, cfg 2, net 2"
# Then: ipsec restart
```

---

## Security Hardening (Optional)

### Disable password auth for SSH
```bash
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

### Auto-update security patches
```bash
apt install unattended-upgrades -y
dpkg-reconfigure -plow unattended-upgrades
```

### Fail2ban for SSH protection
```bash
apt install fail2ban -y
systemctl enable fail2ban
```

---

## Quick Reference

| Item | Value |
|------|-------|
| VPN Protocol | IKEv2/IPsec |
| Auth Method | EAP-MSCHAPv2 |
| Server Software | strongSwan |
| Ports | UDP 500, UDP 4500 |
| Client IP Pool | 10.10.10.0/24 |
| DNS Servers | 1.1.1.1, 8.8.8.8 |
| CA Cert Validity | 10 years |
| Server Cert Validity | 2 years |
| iOS API | NEVPNManager + NEVPNProtocolIKEv2 |

---

## Adding More Users

Simply edit `/etc/ipsec.secrets`:

```bash
nano /etc/ipsec.secrets
```

Add a new line per user:

```
newuser : EAP "NewUserPassword789!"
```

Then reload:

```bash
ipsec rereadsecrets
```

No restart needed — new users can connect immediately.

---

## Summary

1. Get a VPS (Ubuntu 22.04+)
2. Install strongSwan
3. Generate CA + server certificates
4. Configure `ipsec.conf` (IKEv2 + EAP + MOBIKE)
5. Add user credentials to `ipsec.secrets`
6. Open firewall (UDP 500, 4500) + enable NAT
7. Start strongSwan
8. Install CA cert on iPhone (trust it)
9. Update backend `server.js` with real server IP
10. Connect from the app ✓
