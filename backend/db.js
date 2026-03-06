const fs   = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'vacation_tracker.json');

// Load or initialise the JSON store
function load() {
  if (fs.existsSync(DB_PATH)) {
    try { return JSON.parse(fs.readFileSync(DB_PATH, 'utf8')); } catch {}
  }
  return { device_tokens: [], plaid_items: [] };
}

function save(data) {
  fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2));
}

// ── device_tokens ──────────────────────────────────────────────────────────────

function upsertDeviceToken(token) {
  const data = load();
  if (!data.device_tokens.includes(token)) {
    data.device_tokens.push(token);
    save(data);
  }
}

function allDeviceTokens() {
  return load().device_tokens;
}

// ── plaid_items ────────────────────────────────────────────────────────────────

function upsertPlaidItem({ access_token, item_id, institution_name }) {
  const data = load();
  const idx  = data.plaid_items.findIndex(i => i.item_id === item_id);
  const entry = {
    access_token,
    item_id,
    institution_name: institution_name || 'Bank',
    cursor: idx >= 0 ? data.plaid_items[idx].cursor : null,
    created_at: idx >= 0 ? data.plaid_items[idx].created_at : new Date().toISOString(),
  };
  if (idx >= 0) data.plaid_items[idx] = entry;
  else data.plaid_items.push(entry);
  save(data);
  return entry;
}

function allPlaidItems() {
  return load().plaid_items;
}

function getPlaidItem(item_id) {
  return load().plaid_items.find(i => i.item_id === item_id) || null;
}

function updateCursor(item_id, cursor) {
  const data = load();
  const item = data.plaid_items.find(i => i.item_id === item_id);
  if (item) { item.cursor = cursor; save(data); }
}

function deletePlaidItem(item_id) {
  const data = load();
  data.plaid_items = data.plaid_items.filter(i => i.item_id !== item_id);
  save(data);
}

// ── test_transactions (sandbox injection) ──────────────────────────────────────

function addTestTransaction(tx) {
  const data = load();
  if (!data.test_transactions) data.test_transactions = [];
  data.test_transactions.push(tx);
  save(data);
}

function popTestTransactions() {
  const data = load();
  const txs = data.test_transactions || [];
  data.test_transactions = [];
  save(data);
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
