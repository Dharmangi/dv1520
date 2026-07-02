const appVersionService = require('../services/appVersionService');

exports.getVersion = async (req, res) => {
  const info = await appVersionService.getLatestVersion();

  if (!info) {
    return res.status(500).json({ error: 'No app version configured on the server' });
  }

  res.json(info);
};
