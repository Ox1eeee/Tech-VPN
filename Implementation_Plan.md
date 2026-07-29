# Tech VPN – Implementation Plan

> **Priority Order:** iOS App First → Backend API → VPN Servers (User-managed)

---

## Phase 1 – iOS App (SwiftUI)

### Step 1.1 – Project Structure & Models
- [ ] Create folder structure: `Models/`, `Views/`, `Managers/`, `Services/`
- [ ] Create `ServerModel.swift` – data model for VPN servers
- [ ] Create `UserModel.swift` – data model for user/auth
- [ ] Create `ConnectionStatus.swift` – enum for VPN states

### Step 1.2 – VPN Manager (Core)
- [ ] Create `VPNManager.swift` – ObservableObject
  - Configure IKEv2 via `NEVPNProtocolIKEv2`
  - Connect / Disconnect
  - Monitor connection status via `NEVPNStatusDidChange`
  - MOBIKE enabled (auto-reconnect on WiFi ↔ Cellular)
  - DNS leak protection (custom DNS servers)
  - Save/load VPN configuration from `NEVPNManager`

### Step 1.3 – Authentication Service
- [ ] Create `AuthService.swift`
  - Sign up (POST `/api/auth/signup`)
  - Login (POST `/api/auth/login`)
  - Store JWT token in Keychain
  - Auto-login on app launch if token is valid

### Step 1.4 – API Service
- [ ] Create `APIService.swift`
  - Fetch server list (GET `/api/servers`)
  - Fetch IKEv2 config for a server (GET `/api/vpn/config/:serverId`)
  - Log connection event (POST `/api/vpn/connect`)
  - Log disconnection event (POST `/api/vpn/disconnect`)
  - Base URL configuration
  - Auth header injection (Bearer token)

### Step 1.5 – Keychain Helper
- [ ] Create `KeychainHelper.swift`
  - Save password/token to Keychain
  - Read password/token from Keychain
  - Delete password/token from Keychain
  - Required for `NEVPNProtocolIKEv2.passwordReference`

### Step 1.6 – UI Screens
- [ ] **LoginView** – Email/username + password login & signup
- [ ] **HomeView** – Main VPN screen
  - Connection status circle (green/red)
  - Connect / Disconnect button
  - Selected server display
  - Connection timer
- [ ] **ServerListView** – Browse & select VPN servers
  - Server name, country, flag, load indicator
  - Tap to select
- [ ] **SettingsView** – App settings
  - Account info
  - Logout
  - DNS leak protection toggle
  - Auto-connect on launch toggle
- [ ] **App Entry Point** – Update `Tech_VPNApp.swift`
  - Route to LoginView or HomeView based on auth state

### Step 1.7 – iOS Entitlements & Capabilities
- [ ] Add **Network Extensions** capability in Xcode
- [ ] Add **Personal VPN** entitlement
- [ ] Add `NEVPNManager` usage to Info.plist if needed

---

## Phase 2 – Backend API (Node.js + Express)

> **Note:** VPN server infrastructure (strongSwan, certificates, firewall) is managed by the user separately. This phase covers only the API that the iOS app talks to.

### Step 2.1 – Project Setup
- [ ] Initialize Node.js project (`package.json`)
- [ ] Install dependencies: `express`, `jsonwebtoken`, `bcryptjs`, `pg`, `cors`, `dotenv`, `helmet`, `express-rate-limit`
- [ ] Create `.env.example` with required environment variables
- [ ] Create `server.js` entry point

### Step 2.2 – Database Schema (PostgreSQL)
- [ ] Create migration file `schema.sql`
  - `users` table (id, email, username, password, subscription_status, created_at)
  - `servers` table (id, name, country, ip_address, certificate, preshared_key, load, active, created_at)
  - `connections` table (id, user_id, server_id, connected_at, disconnected_at, bytes_sent, bytes_received)

### Step 2.3 – Auth Routes
- [ ] POST `/api/auth/signup` – Register new user (hash password with bcrypt)
- [ ] POST `/api/auth/login` – Login, return JWT token

### Step 2.4 – Server Routes
- [ ] GET `/api/servers` – List active VPN servers (public or auth-required)
- [ ] GET `/api/vpn/config/:serverId` – Return IKEv2 config for a server (auth-required)

### Step 2.5 – Connection Logging Routes
- [ ] POST `/api/vpn/connect` – Log connection event (auth-required)
- [ ] POST `/api/vpn/disconnect` – Log disconnection event (auth-required)

### Step 2.6 – Middleware & Security
- [ ] `authenticateToken` middleware (JWT verification)
- [ ] Rate limiting
- [ ] CORS configuration
- [ ] Helmet for security headers
- [ ] Input validation

---

## Phase 3 – VPN Servers (User-Managed)

> The user will add and configure VPN servers (strongSwan on Linux) themselves. The backend `servers` table holds server metadata. The user populates it manually or via an admin route.

- [ ] User provisions Linux server(s) with strongSwan
- [ ] User generates certificates (CA, server certs)
- [ ] User configures `ipsec.conf`, `ipsec.secrets`
- [ ] User enables IP forwarding & firewall rules
- [ ] User inserts server records into the `servers` database table

---

## Execution Order

| # | Task | Status |
|---|------|--------|
| 1 | iOS Models & Project Structure | ✅ Done |
| 2 | VPNManager (core IKEv2 logic) | ✅ Done |
| 3 | KeychainHelper | ✅ Done |
| 4 | AuthService + APIService | ✅ Done |
| 5 | UI Screens (Login, Home, ServerList, Settings) | ✅ Done |
| 6 | iOS Entitlements (Network Extensions + Personal VPN) | ⚠️ Manual – Add in Xcode |
| 7 | Backend project setup + DB schema | ✅ Done |
| 8 | Backend auth + server + connection routes | ✅ Done |
| 9 | VPN servers (user does this) | User-managed |

---

**Document Version:** 1.1  
**Created:** March 20, 2026
