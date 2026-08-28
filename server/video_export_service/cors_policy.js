const ALLOWED_ORIGINS = new Set([
  'https://tabattal.omar-afifi.com',
  'https://omar-afifi.com',
  'https://www.omar-afifi.com',
  'https://omarafifi-cse.github.io',
]);

function isAllowedOrigin(origin, { allowMissing = true } = {}) {
  if (!origin) return allowMissing;
  return ALLOWED_ORIGINS.has(origin);
}

module.exports = { ALLOWED_ORIGINS, isAllowedOrigin };
