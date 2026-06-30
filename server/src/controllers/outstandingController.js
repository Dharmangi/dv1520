const OutstandingEntry = require('../models/OutstandingEntry');
const Havala = require('../models/Havala');
const Transaction = require('../models/Transaction');

// GET /outstanding?date=YYYY-MM-DD — pending entries + havala pending + today's havala credits
exports.list = async (req, res) => {
  const { date } = req.query;

  const entries = await OutstandingEntry.find({ isDeleted: false, status: 'pending' }).sort({ createdDate: 1 });

  // Havala pending amounts grouped by owner (all time pending)
  const havalas = await Havala.find({ isDeleted: false })
    .populate('ownerId', 'name')
    .select('ownerId totalAmount paidAmount date ownerTransactionIds pendingTransactionId');

  const havalaPending = {};
  for (const h of havalas) {
    const pending = h.totalAmount - h.paidAmount;
    if (pending <= 0) continue;
    const ownerId = h.ownerId?._id?.toString();
    const ownerName = h.ownerId?.name || 'Unknown';
    if (!havalaPending[ownerId]) {
      havalaPending[ownerId] = { personId: ownerId, personName: ownerName, totalPending: 0, havalaCount: 0 };
    }
    havalaPending[ownerId].totalPending += pending;
    havalaPending[ownerId].havalaCount += 1;
  }

  // Today's havala credits — payments received today (settlements + full payments)
  let havalaCredits = [];
  if (date) {
    const datePart = String(date).slice(0, 10);
    const start = new Date(`${datePart}T00:00:00.000Z`);
    const end = new Date(`${datePart}T23:59:59.999Z`);

    // Get all confirmed havala transactions for today (received type, not pending)
    const todayTxns = await Transaction.find({
      isDeleted: { $ne: true },
      type: 'received',
      status: { $ne: 'pending' },
      description: { $in: ['Havala', 'Havala (partial)', 'Havala settlement', 'Havala settlement (partial)'] },
      date: { $gte: start, $lte: end },
    }).populate('personId', 'name');

    // Group by person
    const creditMap = {};
    for (const txn of todayTxns) {
      const pid = txn.personId?._id?.toString() || 'unknown';
      const name = txn.personId?.name || 'Unknown';
      if (!creditMap[pid]) creditMap[pid] = { personId: pid, personName: name, totalAmount: 0, type: 'havala_credit' };
      creditMap[pid].totalAmount += txn.amount;
    }
    havalaCredits = Object.values(creditMap);
  }

  res.json({
    outstandingEntries: entries,
    havalaPending: Object.values(havalaPending),
    havalaCredits,
  });
};

// POST /outstanding — create new outstanding (debit) entry
exports.create = async (req, res) => {
  const { personId, personName, totalAmount, note, createdDate } = req.body;
  if (!personName || !totalAmount) {
    return res.status(400).json({ error: 'personName and totalAmount are required' });
  }

  const entry = await OutstandingEntry.create({
    personId: personId || null,
    personName,
    totalAmount,
    note: note || '',
    createdDate: createdDate ? new Date(createdDate) : new Date(),
  });

  res.status(201).json(entry);
};

// POST /outstanding/:id/settle — mark full or partial settlement
exports.settle = async (req, res) => {
  const { amount, date, note } = req.body;
  const entry = await OutstandingEntry.findOne({ _id: req.params.id, isDeleted: false });
  if (!entry) return res.status(404).json({ error: 'Not found' });

  const pending = entry.totalAmount - entry.settledAmount;
  if (!amount || amount <= 0 || amount > pending) {
    return res.status(400).json({ error: `Settlement amount must be between 1 and ${pending}` });
  }

  entry.settlements.push({ amount, date: date ? new Date(date) : new Date(), note: note || '' });
  entry.settledAmount += amount;
  if (entry.settledAmount >= entry.totalAmount) {
    entry.status = 'settled';
  }
  await entry.save();

  res.json(entry);
};

// DELETE /outstanding/:id — soft delete
exports.remove = async (req, res) => {
  const entry = await OutstandingEntry.findOne({ _id: req.params.id, isDeleted: false });
  if (!entry) return res.status(404).json({ error: 'Not found' });
  entry.isDeleted = true;
  await entry.save();
  res.json({ success: true });
};

// GET /outstanding/history — settled entries
exports.history = async (req, res) => {
  const entries = await OutstandingEntry.find({ isDeleted: false, status: 'settled' }).sort({ updatedAt: -1 }).limit(50);
  res.json(entries);
};
