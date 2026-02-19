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
      var openDates = await kv.get('open_dates');
      return res.json({ openDates: openDates || [] });
    } catch (err) {
      console.error('GET /api/dates error:', err);
      return res.status(500).json({ error: 'Server fout bij ophalen datums' });
    }
  }

  // ── Auth check for POST/DELETE ────────────────────────────────────────────
  var token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token || token !== process.env.ADMIN_TOKEN) {
    return res.status(401).json({ error: 'Ongeldig admin token' });
  }

  // ── POST: open a date ─────────────────────────────────────────────────────
  if (req.method === 'POST') {
    try {
      var date = (req.body || {}).date;
      if (!date) {
        return res.status(400).json({ error: 'Geef een datum op' });
      }
      var dates = (await kv.get('open_dates')) || [];
      if (!dates.includes(date)) {
        dates.push(date);
        await kv.set('open_dates', dates);
      }
      return res.json({ ok: true, openDates: dates });
    } catch (err) {
      console.error('POST /api/dates error:', err);
      return res.status(500).json({ error: 'Server fout bij openen datum' });
    }
  }

  // ── DELETE: close a date (remove from open) ───────────────────────────────
  if (req.method === 'DELETE') {
    try {
      var dateParam = req.query.date;
      if (dateParam === 'all') {
        // Verwijder alle open datums
        await kv.set('open_dates', []);
        return res.json({ ok: true, openDates: [] });
      }
      if (!dateParam) {
        return res.status(400).json({ error: 'Geef ?date=DD-MM-YYYY op' });
      }
      var currentDates = (await kv.get('open_dates')) || [];
      var filtered = currentDates.filter(function(d) { return d !== dateParam; });
      await kv.set('open_dates', filtered);
      return res.json({ ok: true, openDates: filtered });
    } catch (err) {
      console.error('DELETE /api/dates error:', err);
      return res.status(500).json({ error: 'Server fout bij sluiten datum' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
