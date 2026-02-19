const { kv } = require('@vercel/kv');

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get API key from KV store
    var apiKey = await kv.get('snack_api_key');
    if (!apiKey) {
      return res.status(500).json({ error: 'Geen API key geconfigureerd' });
    }

    var body = req.body || {};
    var messages = body.messages;
    var system = body.system || '';
    var tools = body.tools || [];
    var model = body.model || 'claude-haiku-4-5-20251001';
    var maxTokens = body.max_tokens || 1024;

    if (!messages || !Array.isArray(messages)) {
      return res.status(400).json({ error: 'messages is verplicht' });
    }

    // Forward to Anthropic API with streaming
    var anthropicBody = {
      model: model,
      max_tokens: maxTokens,
      stream: true,
      messages: messages,
    };
    if (system) anthropicBody.system = system;
    if (tools.length > 0) anthropicBody.tools = tools;

    var anthropicResp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(anthropicBody),
    });

    if (!anthropicResp.ok) {
      var errText = await anthropicResp.text();
      return res.status(anthropicResp.status).send(errText);
    }

    // Stream the response back to the client
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    var reader = anthropicResp.body.getReader();
    var decoder = new TextDecoder();

    while (true) {
      var result = await reader.read();
      if (result.done) break;
      var chunk = decoder.decode(result.value, { stream: true });
      res.write(chunk);
    }

    res.end();
  } catch (err) {
    console.error('POST /api/chat error:', err);
    if (!res.headersSent) {
      return res.status(500).json({ error: 'Server fout: ' + err.message });
    }
    res.end();
  }
};
