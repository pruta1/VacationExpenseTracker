require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const db         = require('./db');
const plaidRoutes = require('./routes/plaid');

const app = express();
app.use(cors());
app.use(express.json());

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
