const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const requireApiKey = require('./middleware/auth');
const authRoutes = require('./routes/auth');
const versionRoutes = require('./routes/version');
const internalRoutes = require('./routes/internal');
const peopleRoutes = require('./routes/people');
const transactionsRoutes = require('./routes/transactions');
const dashboardRoutes = require('./routes/dashboard');
const categoriesRoutes = require('./routes/categories');
const capitalEntriesRoutes = require('./routes/capitalEntries');
const havalaRoutes = require('./routes/havala');
const dailySilakRoutes = require('./routes/dailySilak');
const outstandingRoutes = require('./routes/outstanding');

const app = express();

app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Public: the app must be able to check for updates before/without a valid API key
// (e.g. if the key ever rotates, older clients still need a path to discover the update).
app.use('/api/version', versionRoutes);

// Public (to this app's API key), but separately gated by its own bearer-token
// middleware — called only by the release CI pipeline to sync the latest
// version/apkUrl/releaseNotes after a GitHub Release is published.
app.use('/internal', internalRoutes);

app.use(requireApiKey);
app.use('/api/auth', authRoutes);
app.use('/api/people', peopleRoutes);
app.use('/api/transactions', transactionsRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/categories', categoriesRoutes);
app.use('/api/capital-entries', capitalEntriesRoutes);
app.use('/api/havala', havalaRoutes);
app.use('/api/daily-silak', dailySilakRoutes);
app.use('/api/outstanding', outstandingRoutes);

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
