require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const db         = require('./db');
const plaidRoutes = require('./routes/plaid');

const app = express();

// ── CORS: only allow requests from the app (no browser origin for native iOS) ─
app.use(cors({ origin: false }));
app.use(express.json());

// ── API secret check ───────────────────────────────────────────────────────────
const APP_SECRET = process.env.APP_SECRET;
app.use((req, res, next) => {
  // Allow Plaid webhook without secret (Plaid sends its own verification)
  if (req.path === '/plaid/webhook') return next();
  if (!APP_SECRET) return next(); // secret not configured, allow all (dev only)
  if (req.headers['x-app-secret'] !== APP_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

app.use('/plaid', plaidRoutes);

app.post('/device-token', (req, res) => {
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'token required' });
  db.upsertDeviceToken(token);
  res.json({ success: true });
});

app.get('/health', (_, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`VacationTracker backend running on http://localhost:${PORT}`);
  if (!process.env.PLAID_CLIENT_ID) {
    console.warn('⚠️  PLAID_CLIENT_ID not set');
  }
});
