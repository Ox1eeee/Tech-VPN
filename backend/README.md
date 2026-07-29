# Tech VPN – Backend API

## Setup

1. **Install dependencies:**
   ```bash
   cd backend
   npm install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your PostgreSQL credentials and JWT secret
   ```

3. **Create the database:**
   ```bash
   createdb techvpn
   psql -d techvpn -f schema.sql
   ```

4. **Run the server:**
   ```bash
   npm run dev    # development (with auto-reload)
   npm start      # production
   ```

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/signup` | No | Register a new user |
| POST | `/api/auth/login` | No | Login, returns JWT |
| GET | `/api/servers` | No | List active VPN servers |
| GET | `/api/vpn/config/:serverId` | Yes | Get IKEv2 config for a server |
| POST | `/api/vpn/connect` | Yes | Log a VPN connection |
| POST | `/api/vpn/disconnect` | Yes | Log a VPN disconnection |
| GET | `/api/health` | No | Health check |

## Adding VPN Servers

Insert server records directly into the `servers` table:

```sql
INSERT INTO servers (name, country, ip_address, load, active)
VALUES ('US East', 'US', '203.0.113.10', 0, true);
```
