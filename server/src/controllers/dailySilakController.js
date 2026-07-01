const DailySilak = require('../models/DailySilak');
const Person = require('../models/Person');

function calcTotals(entries) {
  const totalReceived = entries.filter((e) => e.type === 'received').reduce((s, e) => s + e.amount, 0);
  const totalPaid = entries.filter((e) => e.type === 'paid').reduce((s, e) => s + e.amount, 0);
  return { totalReceived, totalPaid, netBalance: totalReceived - totalPaid };
}

function dayRange(dateStr) {
  // Always treat as date-only (YYYY-MM-DD) to avoid timezone shift bugs
  const datePart = String(dateStr).slice(0, 10);
  const start = new Date(`${datePart}T00:00:00.000Z`);
  const end = new Date(`${datePart}T23:59:59.999Z`);
  return { start, end };
}

// GET /daily-silak/by-date?date=YYYY-MM-DD
exports.getByDate = async (req, res) => {
  const { date } = req.query;
  if (!date) return res.status(400).json({ error: 'date query param required (YYYY-MM-DD)' });

  const { start, end } = dayRange(date);
  let silak = await DailySilak.findOne({ date: { $gte: start, $lte: end }, isDeleted: false });

  if (silak) {
    // Migrate old entries missing type field
    let needsSave = false;
    silak.entries.forEach((e) => { if (!e.type) { e.type = 'received'; needsSave = true; } });
    if (needsSave) {
      const totals = calcTotals(silak.entries);
      silak.totalReceived = totals.totalReceived;
      silak.totalPaid = totals.totalPaid;
      silak.netBalance = totals.netBalance;
      await silak.save();
    }
    return res.json(silak);
  }

  if (!silak) {
    silak = await DailySilak.create({ date: start, entries: [], totalReceived: 0, totalPaid: 0, netBalance: 0 });
  }

  res.json(silak);
};

// GET /daily-silak — list all dates
exports.list = async (req, res) => {
  const records = await DailySilak.find({ isDeleted: false })
    .select('date totalReceived totalPaid netBalance entries')
    .sort({ date: -1 });
  res.json(records);
};

// POST /daily-silak/entry — add entry
exports.addEntry = async (req, res) => {
  const { date, personId, personName, amount, type, note } = req.body;
  if (!date || !personName || !amount || !type) {
    return res.status(400).json({ error: 'date, personName, amount and type are required' });
  }
  if (!['received', 'paid'].includes(type)) {
    return res.status(400).json({ error: 'type must be received or paid' });
  }

  const { start, end } = dayRange(date);
  let silak = await DailySilak.findOne({ date: { $gte: start, $lte: end }, isDeleted: false });
  if (!silak) {
    silak = await DailySilak.create({ date: start, entries: [], totalReceived: 0, totalPaid: 0, netBalance: 0 });
  }

  // Fix old entries that are missing type field before saving
  silak.entries.forEach((e) => { if (!e.type) e.type = 'received'; });

  silak.entries.push({ personId: personId || null, personName, amount, type, note: note || '' });
  const totals = calcTotals(silak.entries);
  silak.totalReceived = totals.totalReceived;
  silak.totalPaid = totals.totalPaid;
  silak.netBalance = totals.netBalance;
  await silak.save();

  res.status(201).json(silak);
};

// PUT /daily-silak/:id/entry/:entryId — edit entry
exports.editEntry = async (req, res) => {
  const { id, entryId } = req.params;
  const { personId, personName, amount, type, note } = req.body;

  const silak = await DailySilak.findOne({ _id: id, isDeleted: false });
  if (!silak) return res.status(404).json({ error: 'Not found' });

  let entry = silak.entries.id(entryId);
  if (!entry) return res.status(404).json({ error: 'Entry not found' });

  // Fix old entries missing type before saving
  silak.entries.forEach((e) => { if (!e.type) e.type = 'received'; });

  if (personName) entry.personName = personName;
  if (personId !== undefined) entry.personId = personId;
  if (amount) entry.amount = amount;
  if (type) entry.type = type;
  if (note !== undefined) entry.note = note;

  const totals = calcTotals(silak.entries);
  silak.totalReceived = totals.totalReceived;
  silak.totalPaid = totals.totalPaid;
  silak.netBalance = totals.netBalance;
  await silak.save();

  res.json(silak);
};

// DELETE /daily-silak/:id/entry/:entryId — remove entry
exports.removeEntry = async (req, res) => {
  const { id, entryId } = req.params;
  const silak = await DailySilak.findOne({ _id: id, isDeleted: false });
  if (!silak) return res.status(404).json({ error: 'Not found' });

  // Support both _id lookup and index-based fallback
  let entry = silak.entries.id(entryId);
  if (!entry) {
    // Try by index for backwards compatibility
    const idx = parseInt(entryId, 10);
    if (!isNaN(idx) && idx >= 0 && idx < silak.entries.length) {
      entry = silak.entries[idx];
    }
  }
  if (!entry) return res.status(404).json({ error: 'Entry not found' });
  if (entry.havalaId) return res.status(400).json({ error: 'Cannot delete Havala-linked entry.' });

  // Fix old entries missing type before saving
  silak.entries.forEach((e) => { if (!e.type) e.type = 'received'; });

  entry.deleteOne();
  const totals = calcTotals(silak.entries);
  silak.totalReceived = totals.totalReceived;
  silak.totalPaid = totals.totalPaid;
  silak.netBalance = totals.netBalance;
  await silak.save();

  res.json(silak);
};

// POST /daily-silak/:date/sync — strip stale Havala-derived entries, keep manual ones
exports.sync = async (req, res) => {
  const { date } = req.params;
  const { start, end } = dayRange(date);

  let silak = await DailySilak.findOne({ date: { $gte: start, $lte: end }, isDeleted: false });
  if (!silak) {
    silak = await DailySilak.create({ date: start, entries: [], totalReceived: 0, totalPaid: 0, netBalance: 0 });
  } else {
    silak.entries = silak.entries.filter((e) => !e.havalaId);
    const totals = calcTotals(silak.entries);
    silak.totalReceived = totals.totalReceived;
    silak.totalPaid = totals.totalPaid;
    silak.netBalance = totals.netBalance;
  }

  await silak.save();
  res.json(silak);
};

// GET /daily-silak/people — get all people for quick selection
exports.getPeople = async (req, res) => {
  const people = await Person.find({ isDeleted: false }).select('name place isOwner').sort({ name: 1 });
  res.json(people);
};
