require('dotenv').config();

const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const port = process.env.PORT || 3000;

// ============================================================
// IN-MEMORY DATA (no database required)
// ============================================================

const users = [];
const connections = [];
let nextUserId = 1;
let nextConnectionId = 1;

const servers = [
    { id: 1, name: 'France #1', country: 'France', ip_address: 'fr1.techvpnpro.com', load: 10, active: true }
];

// Middleware
app.use(express.json());
app.use(cors());
app.use(helmet());

// Rate limiting
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    message: { error: 'Too many requests, please try again later.' }
});

const generalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: { error: 'Too many requests, please try again later.' }
});

app.use('/api/auth', authLimiter);
app.use('/api', generalLimiter);

const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret-key';

// ============================================================
// AUTH ROUTES
// ============================================================

app.post('/api/auth/signup', async (req, res) => {
    const { email, password, username } = req.body;

    if (!email || !password || !username) {
        return res.status(400).json({ error: 'Email, username, and password are required.' });
    }

    if (password.length < 6) {
        return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    }

    if (users.find(u => u.email === email || u.username === username)) {
        return res.status(409).json({ error: 'Email or username already exists.' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = { id: nextUserId++, email, username, password: hashedPassword, subscription_status: 'free', created_at: new Date().toISOString() };
    users.push(user);

    res.status(201).json({ message: 'User created', userId: user.id });
});

app.post('/api/auth/login', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ error: 'Username and password are required.' });
    }

    const user = users.find(u => u.username === username);
    if (!user) {
        return res.status(401).json({ error: 'Invalid credentials.' });
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
        return res.status(401).json({ error: 'Invalid credentials.' });
    }

    const token = jwt.sign({ userId: user.id, username: user.username }, JWT_SECRET, { expiresIn: '24h' });

    res.json({ token, user: { id: user.id, username: user.username, email: user.email } });
});

// ============================================================
// SERVER ROUTES
// ============================================================

app.get('/api/servers', (req, res) => {
    res.json(servers.filter(s => s.active).map(s => ({
        id: s.id, name: s.name, country: s.country, ip_address: s.ip_address, load: s.load
    })));
});

app.get('/api/vpn/config/:serverId', authenticateToken, (req, res) => {
    const server = servers.find(s => s.id === parseInt(req.params.serverId) && s.active);
    if (!server) {
        return res.status(404).json({ error: 'Server not found.' });
    }

    res.json({
        serverAddress: server.ip_address,
        remoteIdentifier: server.ip_address,
        certificate: null,
        presharedKey: null
    });
});

// ============================================================
// CONNECTION LOGGING ROUTES
// ============================================================

app.post('/api/vpn/connect', authenticateToken, (req, res) => {
    const { serverId } = req.body;
    if (!serverId) {
        return res.status(400).json({ error: 'serverId is required.' });
    }

    const conn = {
        id: nextConnectionId++,
        user_id: req.user.userId,
        server_id: serverId,
        connected_at: new Date().toISOString(),
        disconnected_at: null,
        bytes_sent: 0,
        bytes_received: 0
    };
    connections.push(conn);

    res.json({ message: 'Connection logged', connectionId: conn.id });
});

app.post('/api/vpn/disconnect', authenticateToken, (req, res) => {
    const { connectionId } = req.body;
    if (!connectionId) {
        return res.status(400).json({ error: 'connectionId is required.' });
    }

    const conn = connections.find(c => c.id === connectionId && c.user_id === req.user.userId);
    if (conn) {
        conn.disconnected_at = new Date().toISOString();
    }

    res.json({ message: 'Disconnection logged' });
});

// ============================================================
// STATS ROUTES
// ============================================================

app.get('/api/stats/usage', authenticateToken, (req, res) => {
    const userConns = connections.filter(c => c.user_id === req.user.userId);

    const totalSessions = userConns.length;
    const totalBytesSent = userConns.reduce((sum, c) => sum + c.bytes_sent, 0);
    const totalBytesReceived = userConns.reduce((sum, c) => sum + c.bytes_received, 0);
    const totalSeconds = userConns.reduce((sum, c) => {
        const end = c.disconnected_at ? new Date(c.disconnected_at) : new Date();
        return sum + (end - new Date(c.connected_at)) / 1000;
    }, 0);

    const avgSpeed = totalSeconds > 0 ? (totalBytesSent + totalBytesReceived) / totalSeconds : 0;

    res.json({
        totalData: totalBytesSent + totalBytesReceived,
        totalSessions,
        totalBytesSent,
        totalBytesReceived,
        timeProtected: Math.round(totalSeconds),
        averageSpeed: avgSpeed,
        dailyData: []
    });
});

app.get('/api/stats/security', authenticateToken, (req, res) => {
    const userConns = connections
        .filter(c => c.user_id === req.user.userId)
        .slice(-20)
        .reverse();

    res.json({
        auditLog: userConns.map(c => {
            const server = servers.find(s => s.id === c.server_id);
            const end = c.disconnected_at ? new Date(c.disconnected_at) : new Date();
            return {
                id: c.id,
                serverName: server ? server.name : null,
                serverCountry: server ? server.country : null,
                connectedAt: c.connected_at,
                disconnectedAt: c.disconnected_at,
                duration: (end - new Date(c.connected_at)) / 1000,
                bytesSent: c.bytes_sent,
                bytesReceived: c.bytes_received,
                encrypted: true
            };
        })
    });
});

// ============================================================
// PROFILE ROUTES
// ============================================================

app.get('/api/account/profile', authenticateToken, (req, res) => {
    const user = users.find(u => u.id === req.user.userId);
    if (!user) {
        return res.status(404).json({ error: 'User not found.' });
    }

    res.json({
        id: user.id,
        email: user.email,
        username: user.username,
        subscriptionStatus: user.subscription_status,
        createdAt: user.created_at
    });
});

// ============================================================
// MIDDLEWARE
// ============================================================

function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'No token provided.' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid or expired token.' });
        }
        req.user = user;
        next();
    });
}

// ============================================================
// HEALTH CHECK
// ============================================================

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ============================================================
// START SERVER
// ============================================================

app.listen(port, () => {
    console.log(`Tech VPN API running on port ${port} (no database required)`);
});
