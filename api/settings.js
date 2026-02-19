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
      const keyParam = req.query.key;

      if (keyParam === 'qr') {
        const qr = await kv.get('payment_qr');
        return res.json({ qr: qr || null });
      }

      if (keyParam === 'apiKey') {
        const apiKey = await kv.get('snack_api_key');
        return res.json({ apiKey: apiKey || '' });
      }

      if (keyParam === 'adminToken') {
        const savedToken = await kv.get('admin_token_saved');
        return res.json({ adminToken: savedToken || '' });
      }

      if (keyParam === 'sso') {
        const [ssoEnabled, ssoClientId, ssoTenantId, ssoAllowedDomain, ssoAdminEmails] = await Promise.all([
          kv.get('sso_enabled'),
          kv.get('sso_client_id'),
          kv.get('sso_tenant_id'),
          kv.get('sso_allowed_domain'),
          kv.get('sso_admin_emails'),
        ]);
        return res.json({
          ssoEnabled: !!ssoEnabled,
          ssoClientId: ssoClientId || '',
          ssoTenantId: ssoTenantId || '',
          ssoAllowedDomain: ssoAllowedDomain || '',
          ssoAdminEmails: ssoAdminEmails || '',
        });
      }

      // Default: return both (apiKey only as boolean for public)
      const [qr, apiKey] = await Promise.all([
        kv.get('payment_qr'),
        kv.get('snack_api_key'),
      ]);

      // If admin token is provided, return full apiKey for admin display
      const token = (req.headers.authorization || '').replace('Bearer ', '');
      const isAdmin = token && token === process.env.ADMIN_TOKEN;

      return res.json({
        qr: qr || null,
        hasApiKey: !!apiKey,
        ...(isAdmin ? { apiKey: apiKey || '' } : {}),
      });
    } catch (err) {
      console.error('GET /api/settings error:', err);
      return res.status(500).json({ error: 'Server fout bij ophalen instellingen' });
    }
  }

  // ── Auth check for POST/DELETE ────────────────────────────────────────────
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token || token !== process.env.ADMIN_TOKEN) {
    return res.status(401).json({ error: 'Ongeldig admin token' });
  }

  // ── POST: save settings ───────────────────────────────────────────────────
  if (req.method === 'POST') {
    try {
      const { qr, apiKey, adminToken, ssoEnabled, ssoClientId, ssoTenantId, ssoAllowedDomain } = req.body || {};
      const promises = [];

      if (adminToken !== undefined) {
        promises.push(kv.set('admin_token_saved', adminToken));
      }

      if (qr !== undefined) {
        promises.push(kv.set('payment_qr', qr));
      }
      if (apiKey !== undefined) {
        promises.push(kv.set('snack_api_key', apiKey));
      }
      if (ssoEnabled !== undefined) {
        promises.push(kv.set('sso_enabled', ssoEnabled));
      }
      if (ssoClientId !== undefined) {
        promises.push(kv.set('sso_client_id', ssoClientId));
      }
      if (ssoTenantId !== undefined) {
        promises.push(kv.set('sso_tenant_id', ssoTenantId));
      }
      if (ssoAllowedDomain !== undefined) {
        promises.push(kv.set('sso_allowed_domain', ssoAllowedDomain));
      }
      if (req.body.ssoAdminEmails !== undefined) {
        promises.push(kv.set('sso_admin_emails', req.body.ssoAdminEmails));
      }

      await Promise.all(promises);
      return res.json({ ok: true });
    } catch (err) {
      console.error('POST /api/settings error:', err);
      return res.status(500).json({ error: 'Server fout bij opslaan' });
    }
  }

  // ── DELETE: remove a setting ──────────────────────────────────────────────
  if (req.method === 'DELETE') {
    try {
      const keyParam = req.query.key;

      if (keyParam === 'qr') {
        await kv.del('payment_qr');
        return res.json({ ok: true });
      }
      if (keyParam === 'apiKey') {
        await kv.del('snack_api_key');
        return res.json({ ok: true });
      }

      if (keyParam === 'sso') {
        await Promise.all([
          kv.del('sso_enabled'),
          kv.del('sso_client_id'),
          kv.del('sso_tenant_id'),
          kv.del('sso_allowed_domain'),
          kv.del('sso_admin_emails'),
        ]);
        return res.json({ ok: true });
      }

      return res.status(400).json({ error: 'Geef ?key=qr, ?key=apiKey of ?key=sso op' });
    } catch (err) {
      console.error('DELETE /api/settings error:', err);
      return res.status(500).json({ error: 'Server fout bij verwijderen' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
