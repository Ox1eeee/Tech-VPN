# Tech VPN — Progress Tracker

> **Last Updated:** July 8, 2026

---

## Overview

Tech VPN is an IKEv2-based VPN app for iOS with a Node.js/Express backend and user-managed strongSwan VPN servers.

```
iOS App (SwiftUI + NetworkExtension)
  ↕ REST API
Backend (Node.js + Express + PostgreSQL)
  ↕ Server metadata
VPN Servers (strongSwan on Linux — user-managed)
```

---

## Phase 1 — iOS App Core (✅ Complete)

| Task | Status | Notes |
|------|--------|-------|
| Project structure (`Models/`, `Views/`, `Managers/`, `Services/`) | ✅ Done | |
| `ServerModel.swift` — VPN server data model | ✅ Done | |
| `UserModel.swift` — User/Auth data models | ✅ Done | Added `ConnectionLogResponse` model |
| `ConnectionStatus.swift` — VPN state enum | ✅ Done | |
| `VPNManager.swift` — IKEv2 connect/disconnect/monitor | ✅ Done | AES-256-GCM, SHA-256, DH Group 14, MOBIKE, connection logging |
| `KeychainHelper.swift` — Secure credential storage | ✅ Done | `@discardableResult` on save methods, persistent ref for NEVPNProtocol |
| `AuthService.swift` — Signup/Login/Logout with JWT | ✅ Done | Token stored in Keychain |
| `APIService.swift` — REST client for backend | ✅ Done | Returns `ConnectionLogResponse` for logging |
| `AppTheme.swift` — Kinetic Red design system | ✅ Done | Colors, spacing, radius tokens |
| `Tech_VPN.entitlements` — Personal VPN + Network Extensions | ✅ Done | Entitlements file created, wired into project.pbxproj |

---

## Phase 2 — iOS UI / Design (✅ Complete)

| Task | Status | Notes |
|------|--------|-------|
| `MainTabView.swift` — Bottom tab navigation (4 tabs) | ✅ Done | Home, Servers, Stats, Settings |
| `HomeView.swift` — Shield connect button, server selector, speed metrics | ✅ Done | Pulse animation, connected/disconnected states |
| `ServerListView.swift` — Search, recommended, location list | ✅ Done | Fallback sample servers when API unavailable |
| `StatsView.swift` — Data usage circle, speed chart, stat grid, audit log | ✅ Done | Data is currently hardcoded/mock |
| `SettingsView.swift` — Account, Connection, Security sections | ✅ Done | Logout with alert confirmation |
| `ContentView.swift` — App entry point → MainTabView | ✅ Done | Splash/Login removed per user request |
| Design system applied (Kinetic Red — dark + red accents) | ✅ Done | All screens match provided HTML/CSS designs |
| "Shield VPN" → "Tech VPN" branding replacement | ✅ Done | |

### Files No Longer Used (can be deleted)
- `SplashView.swift` — splash screen removed
- `LoginView.swift` — login/signup removed

---

## Phase 3 — Backend API (✅ 100% — No Database Required)

| Task | Status | Notes |
|------|--------|-------|
| `package.json` — Node.js project setup | ✅ Done | Express, JWT, bcrypt, cors, helmet, rate-limit |
| `server.js` — All API routes (in-memory) | ✅ Done | No PostgreSQL, uses in-memory arrays |
| 8 sample servers hardcoded | ✅ Done | US×2, UK, DE, JP, SG, AU, IN |
| `npm install` — Install dependencies | ✅ Done | `pg` removed, no database needed |
| Backend running locally | ✅ Done | Starts with `npm run dev` |

### API Routes Implemented
| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/api/auth/signup` | No | Register new user |
| POST | `/api/auth/login` | No | Login, return JWT |
| GET | `/api/servers` | No | List active VPN servers |
| GET | `/api/vpn/config/:serverId` | Yes | Get IKEv2 config for a server |
| POST | `/api/vpn/connect` | Yes | Log connection event |
| POST | `/api/vpn/disconnect` | Yes | Log disconnection event |
| GET | `/api/stats/usage` | Yes | Usage stats (data, sessions, speed, daily chart) |
| GET | `/api/stats/security` | Yes | Security audit log (last 20 connections) |
| GET | `/api/account/profile` | Yes | User profile (email, username, subscription) |
| GET | `/api/health` | No | Health check |

---

## Phase 4 — iOS ↔ Backend Integration (✅ Code Complete)

| Task | Status | Notes |
|------|--------|-------|
| `APIService` base URL points to backend | ⚠️ Partial | Set to `http://localhost:3000`, needs real URL for production |
| Server list fetches from API | ⚠️ Partial | Falls back to hardcoded sample servers on error |
| VPN config fetch from API | ⚠️ Partial | Code exists but untested against real backend |
| Connection logging to API | ✅ Done | VPNManager calls logConnection/logDisconnection |
| StatsView wired to real API | ✅ Done | Fetches usage stats + security audit, falls back to mock |
| SettingsView wired to real API | ✅ Done | Fetches profile (email, username, subscription), falls back to Keychain |
| ATS (App Transport Security) config | ✅ Done | `NSAllowsLocalNetworking` added to both Debug + Release |
| `StatsModel.swift` — Response models | ✅ Done | `UsageStats`, `SecurityAudit`, `AuditLogEntry`, `UserProfile` |

---

## Phase 5 — VPN Server Setup (👤 User-Managed)

| Task | Status | Notes |
|------|--------|-------|
| Provision Linux server(s) | ❌ Not done | Ubuntu 22.04 recommended |
| Install strongSwan | ❌ Not done | `apt install strongswan strongswan-plugin-eap-mschapv2` |
| Generate CA + server certificates | ❌ Not done | RSA 4096-bit CA, 2048-bit server |
| Configure `ipsec.conf` | ❌ Not done | IKEv2, AES-256-SHA256-MODP2048 |
| Configure `ipsec.secrets` | ❌ Not done | EAP credentials for VPN users |
| Enable IP forwarding | ❌ Not done | `net.ipv4.ip_forward=1` |
| Firewall (UFW/iptables) | ❌ Not done | Open UDP 500 + 4500, NAT masquerading |
| Insert server records into DB | ❌ Not done | IP, cert, preshared key, country, load |

---

## Phase 6 — Testing & QA (❌ Not Started)

| Task | Status | Notes |
|------|--------|-------|
| Test VPN connect on real device | ❌ Not done | Simulator doesn't support VPN |
| Test WiFi ↔ Cellular handoff (MOBIKE) | ❌ Not done | |
| Verify DNS leak protection | ❌ Not done | |
| Test backend API endpoints | ❌ Not done | |
| Test auth flow (signup/login/logout) | ❌ Not done | |
| Battery consumption test | ❌ Not done | |
| Test reconnection on network drop | ❌ Not done | |

---

## Phase 7 — Deployment & Launch (❌ Not Started)

| Task | Status | Notes |
|------|--------|-------|
| Deploy backend (Railway/Render/Fly.io) | ❌ Not done | |
| Set up PostgreSQL in production | ❌ Not done | |
| Configure SSL/TLS for backend | ❌ Not done | |
| Add real VPN server IPs to DB | ❌ Not done | |
| Create privacy policy | ❌ Not done | Required for App Store |
| Prepare App Store listing | ❌ Not done | Screenshots, description, etc. |
| Submit to App Store | ❌ Not done | |

---

## Summary

| Phase | Progress |
|-------|----------|
| Phase 1 — iOS App Core | ✅ 100% |
| Phase 2 — iOS UI / Design | ✅ 100% |
| Phase 3 — Backend API | ✅ 100% (in-memory, no database needed) |
| Phase 4 — iOS ↔ Backend Integration | ✅ 85% (code done, untested against real backend) |
| Phase 5 — VPN Server Setup | ❌ 0% (user-managed) |
| Phase 6 — Testing & QA | ❌ 0% |
| Phase 7 — Deployment & Launch | ❌ 0% |

**Overall: ~60% complete**

---

## Recommended Next Steps

1. **Start backend** — `cd backend && npm run dev` (no database needed)
2. **Set up VPN server** — Install strongSwan, generate certs, configure firewall
3. **Test on real device** — VPN requires physical iPhone, simulator won't work
4. **Deploy backend** — Host API so app can connect from anywhere
