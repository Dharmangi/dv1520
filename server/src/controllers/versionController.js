const REPO = process.env.GITHUB_REPO || 'Dharmangi/dv1520';

exports.getVersion = async (req, res) => {
  const version = process.env.APP_LATEST_VERSION;

  if (!version) {
    return res.status(500).json({ error: 'APP_LATEST_VERSION is not configured on the server' });
  }

  res.json({
    version,
    apkUrl:
      process.env.APP_APK_URL ||
      `https://github.com/${REPO}/releases/download/v${version}/app-release.apk`,
    forceUpdate: process.env.APP_FORCE_UPDATE === 'true',
    releaseNotes: process.env.APP_RELEASE_NOTES || '',
  });
};
