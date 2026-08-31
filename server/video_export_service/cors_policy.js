const ALLOWED_ORIGINS = new Set([
  'https://tabattal.omar-afifi.com',
  'https://omar-afifi.com',
  'https://www.omar-afifi.com',
  'https://omarafifi-cse.github.io',
]);

function isAllowedOrigin(origin, { allowMissing = false, isRunningLocally = false } = {}) {
  if (!origin) return allowMissing;
  if (ALLOWED_ORIGINS.has(origin)) return true;

  try {
    const url = new URL(origin);
    const hostname = url.hostname;

    // 🔒 Localhost is ONLY permitted when running the backend locally
    if (isRunningLocally && (hostname === 'localhost' || hostname === '127.0.0.1')) {
      return true;
    }

    // 🔒 Production domains must be HTTPS and strictly belong to omar-afifi.com or official GitHub Pages
    if (url.protocol === 'https:') {
      if (hostname === 'omar-afifi.com' || hostname.endsWith('.omar-afifi.com')) {
        return true;
      }
      if (hostname === 'omarafifi-cse.github.io') {
        return true;
      }
    }
  } catch (_) {}

  return false;
}

module.exports = { ALLOWED_ORIGINS, isAllowedOrigin };
