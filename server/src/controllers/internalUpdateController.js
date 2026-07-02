const appVersionService = require('../services/appVersionService');

// POST /internal/update-version — called by the release CI pipeline after a
// new GitHub Release is published, so the backend's /api/version reflects
// the new release with no manual step.
exports.postUpdateVersion = async (req, res) => {
  const { version, apkUrl, forceUpdate, releaseNotes } = req.body || {};

  if (!version || typeof version !== 'string') {
    return res.status(400).json({ error: 'version is required and must be a string' });
  }
  if (!apkUrl || typeof apkUrl !== 'string') {
    return res.status(400).json({ error: 'apkUrl is required and must be a string' });
  }
  if (forceUpdate !== undefined && typeof forceUpdate !== 'boolean') {
    return res.status(400).json({ error: 'forceUpdate must be a boolean' });
  }
  if (releaseNotes !== undefined && typeof releaseNotes !== 'string') {
    return res.status(400).json({ error: 'releaseNotes must be a string' });
  }

  const doc = await appVersionService.upsertLatestVersion({
    version,
    apkUrl,
    forceUpdate,
    releaseNotes,
  });

  res.json(doc);
};
