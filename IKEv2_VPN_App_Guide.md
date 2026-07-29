# Complete IKEv2 VPN App Development Guide for iOS

## Table of Contents

- [Phase 1 – Planning & Understanding](#phase-1--planning--understanding)
- [Phase 2 – VPN Server Setup](#phase-2--vpn-server-setup)
- [Phase 3 – Backend API Server](#phase-3--backend-api-server)
- [Phase 4 – iOS App Development](#phase-4--ios-app-development)
- [Phase 5 – Security & Encryption](#phase-5--security--encryption)
- [Phase 6 – Testing & QA](#phase-6--testing--qa)
- [Phase 7 – Deployment & Launch](#phase-7--deployment--launch)
- [Phase 8 – Post-Launch & Maintenance](#phase-8--post-launch--maintenance)

---

# Phase 1 – Planning & Understanding

## 1.1 Introduction

This guide provides a comprehensive walkthrough for building a production-ready IKEv2 VPN application for iOS. IKEv2 is the recommended protocol for iOS due to its native support, excellent mobile optimization, and automatic reconnection capabilities.

## 1.2 Why IKEv2 is Great for iOS

- ✅ Built-in iOS support (easier implementation)
- ✅ MOBIKE (Mobility and Multihoming Protocol) – automatic reconnection on network changes
- ✅ Battery efficient
- ✅ Fast connection establishment
- ✅ Works seamlessly with WiFi ↔ Cellular switching

## 1.3 IKEv2 Protocol Stack

### How IKEv2 Works

```
iOS App
  ↓
NetworkExtension (NEVPNManager)
  ↓
IKEv2 Protocol Handler
  ↓
IPSec Tunnel (Encryption)
  ↓
VPN Server (strongSwan/libreswan)
  ↓
Internet
```

### Key Components

- **IKE Phase 1** – Establishes secure channel between client and server
- **IKE Phase 2** – Negotiates IPSec parameters
- **IPSec** – Actual data encryption (AES-256, ChaCha20)
- **Authentication** – PSK (Pre-Shared Key) or certificates

---

# Phase 2 – VPN Server Setup

## 2.1 Server Software: StrongSwan (Recommended)

**Why strongSwan:**
- Industry standard
- Excellent iOS compatibility
- Well-documented
- Open-source and free

## 2.2 Server Architecture

```
Linux Server (Ubuntu 22.04)
  ├── strongSwan daemon
  ├── IKEv2/IPSec engine
  ├── User authentication (EAP)
  └── Network routing
```

## 2.3 Installation & Certificate Generation (Linux/Ubuntu)

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install strongSwan
sudo apt install strongswan strongswan-plugin-eap-mschapv2 -y

# 3. Generate certificates (self-signed for testing)
cd /etc/ipsec.d/

# Generate CA key
ipsec pki --gen --type rsa --size 4096 --outform pem > private/ca-key.pem

# Generate CA certificate
ipsec pki --self --in private/ca-key.pem --type rsa \
  --dn "C=US, O=MyVPN, CN=MyVPN-CA" --ca --lifetime 3650 \
  --outform pem > cacerts/ca-cert.pem

# Generate server key
ipsec pki --gen --type rsa --size 2048 --outform pem > private/server-key.pem

# Generate server certificate
ipsec pki --pub --in private/server-key.pem | ipsec pki --issue \
  --cacert cacerts/ca-cert.pem --cakey private/ca-key.pem \
  --type rsa --dn "C=US, O=MyVPN, CN=vpn.example.com" \
  --san vpn.example.com --lifetime 1825 \
  --outform pem > certs/server-cert.pem

# 4. Fix permissions
sudo chown -R root:root /etc/ipsec.d/
sudo chmod -R 700 /etc/ipsec.d/private/
```

## 2.4 StrongSwan Configuration: `/etc/ipsec.conf`

```ini
config setup
    charondebug="ike 2, knl 2, cfg 2"
    uniqueids=no

conn %default
    ikelifetime=60m
    lifetime=30m
    margintime=3m
    rekeytime=27m
    rekeymargin=3m
    keyingtries=1
    reauth=no

conn ikev2-vpn
    keyexchange=ikev2
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!
    dpdaction=clear
    dpddelay=30s
    rekey=no
    left=%any
    leftid=vpn.example.com
    leftcert=server-cert.pem
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightgroups=system:vpn-users
    rightaddresspool=10.0.0.0/24
    rightsourceip=%dhcp
    auto=add
    fragmentation=yes
    compress=yes
```

## 2.5 Secrets Configuration: `/etc/ipsec.secrets`

```ini
: RSA server-key.pem

# User credentials (EAP authentication)
user1 : EAP "password123"
user2 : EAP "password456"
```

## 2.6 Enable IP Forwarding

```bash
# Edit /etc/sysctl.conf
sudo nano /etc/sysctl.conf

# Uncomment or add:
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0

# Apply
sudo sysctl -p
```

## 2.7 Firewall Configuration (UFW/iptables)

```bash
# Allow IKEv2 traffic
sudo ufw allow 500/udp    # IKE
sudo ufw allow 4500/udp   # IPSec NAT-T
sudo ufw allow in on eth0 from 10.0.0.0/24  # VPN subnet

# NAT masquerading
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Start strongSwan
sudo systemctl start strongswan-starter
sudo systemctl enable strongswan-starter
```

---

# Phase 3 – Backend API Server

## 3.1 Database Schema (PostgreSQL)

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    subscription_status VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- VPN Servers table
CREATE TABLE servers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL,
    ip_address VARCHAR(15) NOT NULL,
    certificate TEXT,
    preshared_key TEXT,
    load INT DEFAULT 0,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Connections table (for logging/analytics)
CREATE TABLE connections (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    server_id INT REFERENCES servers(id),
    connected_at TIMESTAMP,
    disconnected_at TIMESTAMP,
    bytes_sent INT,
    bytes_received INT
);
```

## 3.2 Node.js + Express API

```javascript
// server.js
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const pg = require('pg');
const cors = require('cors');

const app = express();
const pool = new pg.Pool({
    connectionString: process.env.DATABASE_URL
});

app.use(express.json());
app.use(cors());

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

// MARK: - User Registration
app.post('/api/auth/signup', async (req, res) => {
    const { email, password, username } = req.body;
    
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        
        const result = await pool.query(
            'INSERT INTO users (email, username, password) VALUES ($1, $2, $3) RETURNING id',
            [email, username, hashedPassword]
        );
        
        res.status(201).json({ 
            message: 'User created', 
            userId: result.rows[0].id 
        });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

// MARK: - User Login
app.post('/api/auth/login', async (req, res) => {
    const { username, password } = req.body;
    
    try {
        const result = await pool.query(
            'SELECT * FROM users WHERE username = $1',
            [username]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const user = result.rows[0];
        const validPassword = await bcrypt.compare(password, user.password);
        
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const token = jwt.sign(
            { userId: user.id, username: user.username },
            JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.json({ 
            token, 
            user: { id: user.id, username: user.username, email: user.email }
        });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

// MARK: - Get Available VPN Servers
app.get('/api/servers', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT id, name, country, ip_address, load FROM servers WHERE active = true'
        );
        
        res.json(result.rows);
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

// MARK: - Get Server Config for IKEv2
app.get('/api/vpn/config/:serverId', authenticateToken, async (req, res) => {
    const { serverId } = req.params;
    
    try {
        const result = await pool.query(
            'SELECT ip_address, certificate, preshared_key FROM servers WHERE id = $1',
            [serverId]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Server not found' });
        }
        
        const server = result.rows[0];
        
        // Return IKEv2 specific configuration
        res.json({
            serverAddress: server.ip_address,
            remoteIdentifier: `vpn-${serverId}.example.com`,
            certificate: server.certificate,
            presharedKey: server.preshared_key
        });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

// MARK: - Log Connection Event
app.post('/api/vpn/connect', authenticateToken, async (req, res) => {
    const { serverId } = req.body;
    const userId = req.user.userId;
    
    try {
        await pool.query(
            'INSERT INTO connections (user_id, server_id, connected_at) VALUES ($1, $2, NOW())',
            [userId, serverId]
        );
        
        res.json({ message: 'Connection logged' });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

// MARK: - Log Disconnection
app.post('/api/vpn/disconnect', authenticateToken, async (req, res) => {
    const { connectionId } = req.body;
    
    try {
        await pool.query(
            'UPDATE connections SET disconnected_at = NOW() WHERE id = $1',
            [connectionId]
        );
        
        res.json({ message: 'Disconnection logged' });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

// Middleware to verify token
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'No token provided' });
    }
    
    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid token' });
        }
        
        req.user = user;
        next();
    });
}

// Start server
app.listen(3000, () => {
    console.log('Server running on port 3000');
});
```

---

# Phase 4 – iOS App Development

## 4.1 VPN Configuration Manager

```swift
import SwiftUI
import NetworkExtension

class VPNManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var selectedServer = "US Server 1"
    
    let vpnManager = NEVPNManager.shared()
    
    // MARK: - Configure VPN
    func setupIKEv2VPN(server: String, username: String, password: String) {
        let config = NEVPNProtocolIKEv2()
        
        // Server details
        config.serverAddress = "vpn.example.com"  // Your server IP
        
        // IKEv2 specific settings
        config.username = username
        config.passwordReference = try? password.data(using: .utf8)
        config.remoteIdentifier = "vpn.example.com"
        config.localIdentifier = username
        
        // IPSec encryption
        config.encryptionLevel = .require
        config.integrityAlgorithm = .SHA256
        config.diffieHellmanGroup = .group14
        
        // Advanced IKEv2 settings
        config.useExtendedAuthentication = true
        config.disableMOBIKE = false  // Enable MOBIKE for network switching
        config.enableFallback = true
        
        // DNS settings (prevent DNS leaks)
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dnsSettings.matchDomains = nil  // Apply to all domains
        
        // IPv4 settings
        let ipv4Settings = NEIPv4Settings()
        ipv4Settings.configurationMethod = .automatic
        
        let settings = NEVPNConfiguration()
        settings.protocolConfiguration = config
        settings.dnsSettings = dnsSettings
        settings.ipv4Settings = ipv4Settings
        settings.isEnabled = true
        settings.isOnDemandEnabled = true
        settings.disconnectOnSleep = false
        
        // Save configuration
        vpnManager.protocolConfiguration = config
        vpnManager.localizedDescription = "MyVPN - IKEv2"
        
        vpnManager.saveConfiguration { [weak self] error in
            if error == nil {
                self?.loadVPNConfiguration()
            }
        }
    }
    
    // MARK: - Load VPN Configuration
    func loadVPNConfiguration() {
        vpnManager.loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                self?.updateConnectionStatus()
            }
        }
    }
    
    // MARK: - Connect to VPN
    func connectVPN() {
        loadVPNConfiguration()
        do {
            try vpnManager.connection.startVPNTunnel()
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionStatus = "Connecting..."
            }
        } catch {
            print("Failed to connect VPN: \(error)")
            self.connectionStatus = "Connection failed"
        }
    }
    
    // MARK: - Disconnect VPN
    func disconnectVPN() {
        vpnManager.connection.stopVPNTunnel()
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
    }
    
    // MARK: - Monitor Connection Status
    func monitorVPNStatus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }
    
    @objc func vpnStatusDidChange() {
        updateConnectionStatus()
    }
    
    func updateConnectionStatus() {
        DispatchQueue.main.async {
            switch self.vpnManager.connection.status {
            case .connected:
                self.isConnected = true
                self.connectionStatus = "Connected"
            case .connecting:
                self.connectionStatus = "Connecting..."
            case .disconnecting:
                self.connectionStatus = "Disconnecting..."
            case .disconnected:
                self.isConnected = false
                self.connectionStatus = "Disconnected"
            case .invalid:
                self.connectionStatus = "Invalid"
            @unknown default:
                self.connectionStatus = "Unknown"
            }
        }
    }
}
```

## 4.2 Main UI View

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var vpnManager = VPNManager()
    @State private var showServerList = false
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Text("MyVPN")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(vpnManager.connectionStatus)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Connection Status Circle
                ZStack {
                    Circle()
                        .fill(vpnManager.isConnected ? Color.green : Color.red)
                        .opacity(0.2)
                        .frame(width: 150, height: 150)
                    
                    VStack {
                        Text(vpnManager.isConnected ? "CONNECTED" : "DISCONNECTED")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(vpnManager.selectedServer)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Server Selection
                Button(action: { showServerList = true }) {
                    HStack {
                        Image(systemName: "server.rack")
                        VStack(alignment: .leading) {
                            Text("VPN Server")
                                .font(.subheadline)
                            Text(vpnManager.selectedServer)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Connect/Disconnect Button
                Button(action: {
                    if vpnManager.isConnected {
                        vpnManager.disconnectVPN()
                    } else {
                        // Setup VPN before connecting
                        vpnManager.setupIKEv2VPN(
                            server: "vpn.example.com",
                            username: username,
                            password: password
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            vpnManager.connectVPN()
                        }
                    }
                }) {
                    Text(vpnManager.isConnected ? "DISCONNECT" : "CONNECT")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vpnManager.isConnected ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            vpnManager.monitorVPNStatus()
            vpnManager.loadVPNConfiguration()
        }
    }
}

#Preview {
    ContentView()
}
```

---

# Phase 5 – Security & Encryption

## 5.1 Recommended Encryption Configuration

```
IKE Encryption:     AES-256-GCM
IKE Integrity:      SHA-256 / SHA-512
DH Group:           Group 14 (2048-bit) or Group 20 (384-bit)
IPSec Encryption:   AES-256-GCM
IPSec Integrity:    SHA-256 / SHA-512
```

---

# Phase 6 – Testing & QA

## 6.1 Testing from Your iOS App

```swift
// Test if VPN is connected
print(vpnManager.connection.status)

// Check connection details
if let config = vpnManager.protocolConfiguration as? NEVPNProtocolIKEv2 {
    print("Server: \(config.serverAddress ?? "")")
    print("Username: \(config.username ?? "")")
}
```

## 6.2 Testing from Your Linux Server

```bash
# Check if strongSwan is running
sudo systemctl status strongswan-starter

# View active connections
sudo ipsec statusall

# Check logs
sudo tail -f /var/log/syslog | grep charon

# Test connectivity
ping 10.0.0.1  # Your VPN subnet

# Monitor network traffic
sudo tcpdump -i eth0 -n port 500 or port 4500
```

## 6.3 iOS-Specific Test Cases

- [ ] Test on real device
- [ ] Verify DNS leak protection
- [ ] Test network switching (WiFi ↔ Cellular)
- [ ] Test reconnection on network change
- [ ] Verify battery consumption

---

# Phase 7 – Deployment & Launch

## 7.1 VPN Server Deployment Checklist

- [ ] Install and configure strongSwan
- [ ] Generate SSL certificates
- [ ] Configure firewall (UDP 500, 4500)
- [ ] Enable IP forwarding
- [ ] Test with iOS client
- [ ] Monitor server logs
- [ ] Set up automatic backups
- [ ] Configure logging

## 7.2 Backend API Deployment Checklist

- [ ] Deploy on cloud (AWS, DigitalOcean, Linode)
- [ ] Set up PostgreSQL database
- [ ] Configure SSL/TLS
- [ ] Set up logging and monitoring
- [ ] Create backup strategy
- [ ] Configure rate limiting
- [ ] Set up error tracking

## 7.3 iOS App Store Submission Checklist

- [ ] Create privacy policy
- [ ] Prepare App Store listing
- [ ] Submit to App Store

---

# Phase 8 – Post-Launch & Maintenance

## 8.1 Support & Troubleshooting

### Common Issues

**Issue:** VPN won't connect
- Check firewall rules (UDP 500, 4500 open?)
- Verify server certificate
- Check strongSwan logs

**Issue:** Frequent disconnections
- Enable MOBIKE in iOS configuration
- Check network stability
- Increase DPD timeout values

**Issue:** DNS leaks
- Set DNS settings in NEVPNConfiguration
- Verify DNS is routed through VPN
- Use online DNS leak testers

## 8.2 Additional Resources

- **strongSwan Documentation:** https://www.strongswan.org/documentation.html
- **Apple NetworkExtension:** https://developer.apple.com/documentation/networkextension
- **IKEv2 RFC:** https://tools.ietf.org/html/rfc7296
- **iOS Security Guide:** https://developer.apple.com/documentation/Security

## 8.3 Key Takeaways

1. **IKEv2 is ideal for iOS** due to native support and MOBIKE
2. **strongSwan** is the best VPN server software for iOS compatibility
3. **NetworkExtension framework** handles all VPN connectivity on iOS
4. **Backend API** manages user authentication and server configuration
5. **Security is critical** – use strong encryption and follow Apple's guidelines
6. **Testing on real devices** is essential before App Store submission

---

**Document Version:** 1.1
**Last Updated:** March 20, 2026
**Author:** VPN Development Guide
