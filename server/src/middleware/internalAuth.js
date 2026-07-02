// Guards internal CI-only endpoints (e.g. the release pipeline's version sync).
// Uses a distinct secret from the app's x-api-key so it can be rotated
// independently and is never shipped inside the mobile app.
function requireInternalToken(req, res, next) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : null;
  if (!token || token !== process.env.INTERNAL_UPDATE_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

module.exports = requireInternalToken;
