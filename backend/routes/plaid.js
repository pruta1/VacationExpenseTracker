const express = require('express');
const router  = express.Router();
const { PlaidApi, PlaidEnvironments, Configuration } = require('plaid');
const db = require('../db');

// ── Plaid client ───────────────────────────────────────────────────────────────
const plaidClient = new PlaidApi(
  new Configuration({
    basePath: PlaidEnvironments[process.env.PLAID_ENV || 'sandbox'],
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
        'PLAID-SECRET':    process.env.PLAID_SECRET,
      },
    },
  })
);

// ── APNs helper ────────────────────────────────────────────────────────────────
function buildAPNsProvider() {
  const { APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID } = process.env;
  if (!APNS_KEY_PATH || !APNS_KEY_ID || !APNS_TEAM_ID) return null;
  try {
    const apn = require('apn');
    return new apn.Provider({
      token: { key: APNS_KEY_PATH, keyId: APNS_KEY_ID, teamId: APNS_TEAM_ID },
      production: process.env.APNS_PRODUCTION === 'true',
    });
  } catch { return null; }
}

async function sendSilentPushToAll(payload = {}) {
  const provider = buildAPNsProvider();
  if (!provider) { console.log('APNs not configured — skipping silent push'); return; }
  const apn    = require('apn');
  const tokens = await db.allDeviceTokens();
  if (!tokens.length) return;

  const note = new apn.Notification();
  note.contentAvailable = true;
  note.priority  = 5;
  note.payload   = { type: 'plaid_sync', ...payload };
  note.topic     = process.env.APNS_BUNDLE_ID;

  try { await provider.send(note, tokens); } catch (err) { console.error('APNs error:', err); }
  finally { provider.shutdown(); }
}

// ── POST /plaid/create-link-token ──────────────────────────────────────────────
router.post('/create-link-token', async (req, res) => {
  try {
    const webhookUrl = process.env.WEBHOOK_URL && process.env.WEBHOOK_URL.startsWith('http')
      ? process.env.WEBHOOK_URL
      : undefined;

    const response = await plaidClient.linkTokenCreate({
      user: { client_user_id: 'vacation-tracker-user' },
      client_name: 'VacationCostTracker',
      products: ['transactions'],
      country_codes: ['US', 'GB', 'DE', 'FR', 'ES', 'IT', 'NL', 'AT', 'BE'],
      language: 'en',
      webhook: webhookUrl,
    });
    res.json({ link_token: response.data.link_token });
  } catch (err) {
    console.error('create-link-token:', JSON.stringify(err.response?.data) || err.message);
    res.status(500).json({ error: 'Failed to create link token' });
  }
});

// ── POST /plaid/exchange-token ─────────────────────────────────────────────────
router.post('/exchange-token', async (req, res) => {
  const { public_token, institution_name } = req.body;
  if (!public_token) return res.status(400).json({ error: 'public_token required' });
  try {
    const response = await plaidClient.itemPublicTokenExchange({ public_token });
    const { access_token, item_id } = response.data;
    await db.upsertPlaidItem({ access_token, item_id, institution_name });
    res.json({ success: true, item_id, institution_name: institution_name || 'Bank' });
  } catch (err) {
    console.error('exchange-token:', JSON.stringify(err.response?.data) || err.message);
    res.status(500).json({ error: 'Failed to exchange token' });
  }
});

// ── GET /plaid/items ───────────────────────────────────────────────────────────
router.get('/items', async (req, res) => {
  const items = (await db.allPlaidItems()).map(({ access_token, cursor, ...safe }) => safe);
  res.json(items);
});

// ── DELETE /plaid/items/:itemId ────────────────────────────────────────────────
router.delete('/items/:itemId', async (req, res) => {
  const item = await db.getPlaidItem(req.params.itemId);
  if (!item) return res.status(404).json({ error: 'Not found' });
  try { await plaidClient.itemRemove({ access_token: item.access_token }); } catch {}
  await db.deletePlaidItem(req.params.itemId);
  res.json({ success: true });
});

// ── GET /plaid/sync ────────────────────────────────────────────────────────────
router.get('/sync', async (req, res) => {
  const items = await db.allPlaidItems();
  const allTransactions = [];

  for (const item of items) {
    let cursor  = item.cursor || undefined;
    let hasMore = true;

    while (hasMore) {
      try {
        const response = await plaidClient.transactionsSync({
          access_token: item.access_token,
          cursor,
          options: { include_personal_finance_category: true },
        });
        const data = response.data;
        for (const tx of data.added) {
          allTransactions.push({ ...tx, institution_name: item.institution_name });
        }
        cursor  = data.next_cursor;
        hasMore = data.has_more;
        await db.updateCursor(item.item_id, cursor);
      } catch (err) {
        console.error(`Sync error for ${item.item_id}:`, JSON.stringify(err.response?.data) || err.message);
        break;
      }
    }
  }

  const testTxs = await db.popTestTransactions();
  allTransactions.push(...testTxs);

  console.log(`Synced ${allTransactions.length} new transaction(s)`);
  res.json({ transactions: allTransactions });
});

// ── POST /plaid/webhook ────────────────────────────────────────────────────────
router.post('/webhook', async (req, res) => {
  res.sendStatus(200);
  const { webhook_type, webhook_code } = req.body;
  console.log(`Plaid webhook: ${webhook_type}/${webhook_code}`);
  const syncCodes = ['SYNC_UPDATES_AVAILABLE', 'INITIAL_UPDATE', 'HISTORICAL_UPDATE', 'DEFAULT_UPDATE'];
  if (webhook_type === 'TRANSACTIONS' && syncCodes.includes(webhook_code)) {
    await sendSilentPushToAll({ webhook_code });
  }
});

module.exports = router;
