export const config = {
  matcher: '/:path*',
};

export default function middleware(req) {
  const basicAuth = req.headers.get('authorization');

  if (basicAuth) {
    const [scheme, encoded] = basicAuth.split(' ');
    if (scheme === 'Basic' && encoded) {
      const decoded = atob(encoded);
      const colonIndex = decoded.indexOf(':');
      const password = decoded.slice(colonIndex + 1);

      const expected = process.env.SITE_PASSWORD;
      if (expected && password === expected) {
        return new Response(null, {
          headers: { 'x-middleware-next': '1' },
        });
      }
    }
  }

  return new Response('Toegang geweigerd', {
    status: 401,
    headers: {
      'WWW-Authenticate': 'Basic realm="Snack Bestelsysteem"',
    },
  });
}
