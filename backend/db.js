// Persistent store backed by Upstash Redis (if configured) or in-memory only.
// Set UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN in your env to enable persistence.

const REDIS_URL   = process.env.UPSTASH_REDIS_REST_URL;
const REDIS_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;
const DB_KEY      = 'vacation_tracker_db';

let store       = { device_tokens: [], plaid_items: [], test_transactions: [] };
let initialized = false;

// ── Redis helpers ──────────────────────────────────────────────────────────────

async function redisGet(key) {
  if (!REDIS_URL) return null;
  try {
    const r = await fetch(`${REDIS_URL}/get/${key}`, {
      headers: { Authorization: `Bearer ${REDIS_TOKEN}` },
    });
    const { result } = await r.json();
    return result;
  } catch (err) {
    console.error('Redis GET error:', err.message);
    return null;
  }
}

async function redisSet(key, value) {
  if (!REDIS_URL) return;
  try {
    await fetch(`${REDIS_URL}/set/${key}`, {
      method:  'POST',
      headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
      body:    JSON.stringify(value),
    });
  } catch (err) {
    console.error('Redis SET error:', err.message);
  }
}

// ── Init & persist ─────────────────────────────────────────────────────────────

async function init() {
  if (initialized) return;
  initialized = true;
  const json = await redisGet(DB_KEY);
  if (json) {
    try { store = JSON.parse(json); } catch {}
  }
  store.device_tokens     = store.device_tokens     || [];
  store.plaid_items       = store.plaid_items       || [];
  store.test_transactions = store.test_transactions || [];
  if (!REDIS_URL) console.warn('⚠️  Upstash Redis not configured — data will not persist across restarts');
}

async function persist() {
  await redisSet(DB_KEY, JSON.stringify(store));
}

// ── device_tokens ──────────────────────────────────────────────────────────────

async function upsertDeviceToken(token) {
  await init();
  if (!store.device_tokens.includes(token)) {
    store.device_tokens.push(token);
    await persist();
  }
}

async function allDeviceTokens() {
  await init();
  return store.device_tokens;
}

// ── plaid_items ────────────────────────────────────────────────────────────────

async function upsertPlaidItem({ access_token, item_id, institution_name }) {
  await init();
  const idx   = store.plaid_items.findIndex(i => i.item_id === item_id);
  const entry = {
    access_token,
    item_id,
    institution_name: institution_name || 'Bank',
    cursor:     idx >= 0 ? store.plaid_items[idx].cursor     : null,
    created_at: idx >= 0 ? store.plaid_items[idx].created_at : new Date().toISOString(),
  };
  if (idx >= 0) store.plaid_items[idx] = entry;
  else store.plaid_items.push(entry);
  await persist();
  return entry;
}

async function allPlaidItems() {
  await init();
  return store.plaid_items;
}

async function getPlaidItem(item_id) {
  await init();
  return store.plaid_items.find(i => i.item_id === item_id) || null;
}

async function updateCursor(item_id, cursor) {
  await init();
  const item = store.plaid_items.find(i => i.item_id === item_id);
  if (item) { item.cursor = cursor; await persist(); }
}

async function deletePlaidItem(item_id) {
  await init();
  store.plaid_items = store.plaid_items.filter(i => i.item_id !== item_id);
  await persist();
}

// ── test_transactions ──────────────────────────────────────────────────────────

async function addTestTransaction(tx) {
  await init();
  store.test_transactions.push(tx);
  await persist();
}

async function popTestTransactions() {
  await init();
  const txs = store.test_transactions || [];
  store.test_transactions = [];
  await persist();
  return txs;
}

module.exports = {
  upsertDeviceToken,
  allDeviceTokens,
  upsertPlaidItem,
  allPlaidItems,
  getPlaidItem,
  updateCursor,
  deletePlaidItem,
  addTestTransaction,
  popTestTransactions,
};
