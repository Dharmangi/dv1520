const mongoose = require('mongoose');

// Singleton document — always read/written via the fixed _id "latest".
const appVersionSchema = new mongoose.Schema(
  {
    _id: { type: String, default: 'latest' },
    version: { type: String, required: true },
    buildNumber: { type: Number, required: true, default: 1 },
    apkUrl: { type: String, required: true },
    forceUpdate: { type: Boolean, default: false },
    releaseNotes: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('AppVersion', appVersionSchema);
