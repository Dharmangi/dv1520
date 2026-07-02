const AppVersion = require('../models/AppVersion');

const SINGLETON_ID = 'latest';

function envFallback() {
  const version = process.env.APP_LATEST_VERSION;
  if (!version) return null;

  const repo = process.env.GITHUB_REPO || 'Dharmangi/dv1520';
  return {
    version,
    apkUrl:
      process.env.APP_APK_URL ||
      `https://github.com/${repo}/releases/download/v${version}/app-release.apk`,
    forceUpdate: process.env.APP_FORCE_UPDATE === 'true',
    releaseNotes: process.env.APP_RELEASE_NOTES || '',
  };
}

// Reads the synced version from MongoDB; falls back to env vars (seed/dev default)
// if no release has been synced yet via POST /internal/update-version.
exports.getLatestVersion = async () => {
  const doc = await AppVersion.findById(SINGLETON_ID).lean();
  if (doc) {
    return {
      version: doc.version,
      apkUrl: doc.apkUrl,
      forceUpdate: doc.forceUpdate,
      releaseNotes: doc.releaseNotes,
    };
  }
  return envFallback();
};

exports.upsertLatestVersion = async ({ version, apkUrl, forceUpdate, releaseNotes }) => {
  const doc = await AppVersion.findByIdAndUpdate(
    SINGLETON_ID,
    {
      version,
      apkUrl,
      forceUpdate: forceUpdate ?? false,
      releaseNotes: releaseNotes ?? '',
    },
    { upsert: true, new: true }
  );
  return doc;
};
