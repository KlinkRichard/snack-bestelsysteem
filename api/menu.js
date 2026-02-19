const { kv } = require('@vercel/kv');

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // ── GET: public read ──────────────────────────────────────────────────────
  if (req.method === 'GET') {
    try {
      const [menu, opslag, opslagMode, updatedAt] = await Promise.all([
        kv.get('snack_menu'),
        kv.get('snack_opslag'),
        kv.get('snack_opslag_mode'),
        kv.get('snack_menu_updated_at'),
      ]);

      return res.json({
        menu: menu || null,
        opslag: opslag ?? 0,
        opslagMode: opslagMode || 'pct',
        updatedAt: updatedAt || null,
      });
    } catch (err) {
      console.error('GET /api/menu error:', err);
      return res.status(500).json({ error: 'Server fout bij ophalen menu' });
    }
  }

  // ── Auth check for POST/DELETE ────────────────────────────────────────────
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token || token !== process.env.ADMIN_TOKEN) {
    return res.status(401).json({ error: 'Ongeldig admin token' });
  }

  // ── POST: save menu data ──────────────────────────────────────────────────
  if (req.method === 'POST') {
    try {
      const { menu, opslag, opslagMode } = req.body || {};
      const promises = [];

      if (menu !== undefined) {
        promises.push(kv.set('snack_menu', menu));
      }
      if (opslag !== undefined) {
        promises.push(kv.set('snack_opslag', opslag));
      }
      if (opslagMode !== undefined) {
        promises.push(kv.set('snack_opslag_mode', opslagMode));
      }

      // Save timestamp whenever menu data changes
      const now = new Date().toISOString();
      promises.push(kv.set('snack_menu_updated_at', now));

      await Promise.all(promises);
      return res.json({ ok: true, updatedAt: now });
    } catch (err) {
      console.error('POST /api/menu error:', err);
      return res.status(500).json({ error: 'Server fout bij opslaan menu' });
    }
  }

  // ── DELETE: reset menu to defaults ────────────────────────────────────────
  if (req.method === 'DELETE') {
    try {
      await Promise.all([
        kv.del('snack_menu'),
        kv.del('snack_opslag'),
        kv.del('snack_opslag_mode'),
        kv.del('snack_menu_updated_at'),
      ]);
      return res.json({ ok: true });
    } catch (err) {
      console.error('DELETE /api/menu error:', err);
      return res.status(500).json({ error: 'Server fout bij resetten menu' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
