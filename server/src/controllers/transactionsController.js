const Transaction = require('../models/Transaction');
const DailySilak = require('../models/DailySilak');

exports.list = async (req, res) => {
  const { personId, categoryId, from, to, page = 1, limit = 50 } = req.query;
  const filter = { isDeleted: false };
  if (personId) filter.personId = personId;
  if (categoryId) filter.categoryId = categoryId;
  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = new Date(from);
    if (to) filter.date.$lte = new Date(to);
  }

  const transactions = await Transaction.find(filter)
    .sort({ date: -1 })
    .skip((page - 1) * limit)
    .limit(Number(limit))
    .populate('personId', 'name')
    .populate('categoryId', 'name type');

  res.json(transactions);
};

// GET /transactions/statement?personId=&from=&to=
// Combines Transaction records (havala-linked) with manual Daily Silak entries for a person.
exports.statement = async (req, res) => {
  const { personId, from, to } = req.query;
  if (!personId) return res.status(400).json({ error: 'personId is required' });

  const dateFilter = {};
  if (from) dateFilter.$gte = new Date(from);
  if (to) dateFilter.$lte = new Date(to);

  const txnFilter = { isDeleted: false, personId, status: 'confirmed' };
  if (from || to) txnFilter.date = dateFilter;

  const transactions = await Transaction.find(txnFilter).sort({ date: 1 });

  const pendingFilter = { isDeleted: false, personId, status: 'pending' };
  if (from || to) pendingFilter.date = dateFilter;
  const pendingTransactions = await Transaction.find(pendingFilter);
  const pendingAmount = pendingTransactions.reduce(
    (sum, t) => sum + (t.type === 'received' ? t.amount : -t.amount),
    0,
  );

  const silakFilter = { isDeleted: false, 'entries.personId': personId };
  if (from || to) silakFilter.date = dateFilter;
  const silakDocs = await DailySilak.find(silakFilter);

  const manualEntries = [];
  for (const silak of silakDocs) {
    for (const entry of silak.entries) {
      if (!entry.personId || String(entry.personId) !== String(personId)) continue;
      if (entry.havalaId) continue; // already represented via Transaction
      manualEntries.push({
        date: silak.date,
        type: entry.type,
        amount: entry.amount,
        paymentMode: 'cash',
        description: entry.note || '',
      });
    }
  }

  const combined = [
    ...transactions.map((t) => ({
      date: t.date,
      type: t.type,
      amount: t.amount,
      paymentMode: t.paymentMode,
      description: t.description || '',
    })),
    ...manualEntries,
  ].sort((a, b) => new Date(a.date) - new Date(b.date));

  res.json({ entries: combined, pendingAmount });
};

exports.create = async (req, res) => {
  try {
    const transaction = await Transaction.create(req.body);
    res.status(201).json(transaction);
  } catch (err) {
    if (err.code === 11000) {
      const existing = await Transaction.findOne({ clientUuid: req.body.clientUuid });
      return res.status(200).json(existing);
    }
    throw err;
  }
};

exports.update = async (req, res) => {
  const transaction = await Transaction.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!transaction) return res.status(404).json({ error: 'Not found' });
  res.json(transaction);
};

exports.remove = async (req, res) => {
  const transaction = await Transaction.findByIdAndUpdate(req.params.id, { isDeleted: true }, { new: true });
  if (!transaction) return res.status(404).json({ error: 'Not found' });
  res.json(transaction);
};
