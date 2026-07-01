const { randomUUID } = require('crypto');
const Havala = require('../models/Havala');
const Transaction = require('../models/Transaction');

exports.list = async (req, res) => {
  const havalas = await Havala.find({ isDeleted: false })
    .sort({ date: -1 })
    .populate('ownerId', 'name mobile')
    .populate('splits.personId', 'name place');
  res.json(havalas);
};

async function buildHavalaRecords({ ownerId, totalAmount, paidAmount, splits, dateInput }) {
  const datePart = String(dateInput).slice(0, 10);
  const date = new Date(`${datePart}T00:00:00.000Z`);

  const splitsTotal = splits.reduce((sum, s) => sum + s.amount, 0);
  if (splitsTotal !== totalAmount) {
    throw new Error('Split amounts must add up to the total amount');
  }
  if (paidAmount > totalAmount) {
    throw new Error('Paid amount cannot exceed total amount');
  }

  const ownerTransactionIds = [];
  if (paidAmount > 0) {
    const ownerTxn = await Transaction.create({
      clientUuid: randomUUID(),
      personId: ownerId,
      type: 'received',
      amount: paidAmount,
      paymentMode: 'cash',
      description: paidAmount < totalAmount ? 'Havala (partial)' : 'Havala',
      date,
    });
    ownerTransactionIds.push(ownerTxn._id);
  }

  let pendingTransactionId = null;
  const pendingAmount = totalAmount - paidAmount;
  if (pendingAmount > 0) {
    const pendingTxn = await Transaction.create({
      clientUuid: randomUUID(),
      personId: ownerId,
      type: 'received',
      amount: pendingAmount,
      paymentMode: 'cash',
      description: 'Havala (pending)',
      status: 'pending',
      date,
    });
    pendingTransactionId = pendingTxn._id;
  }

  const splitRecords = [];
  for (const split of splits) {
    const splitDatePart = split.date ? String(split.date).slice(0, 10) : datePart;
    const splitDate = new Date(`${splitDatePart}T00:00:00.000Z`);
    const txn = await Transaction.create({
      clientUuid: randomUUID(),
      personId: split.personId,
      type: 'paid',
      amount: split.amount,
      paymentMode: 'cash',
      description: 'Havala payout',
      date: splitDate,
    });
    splitRecords.push({ personId: split.personId, amount: split.amount, date: splitDate, transactionId: txn._id });
  }

  return { ownerId, totalAmount, paidAmount, ownerTransactionIds, pendingTransactionId, date, splits: splitRecords };
}

exports.create = async (req, res) => {
  const { ownerId, totalAmount, paidAmount, splits } = req.body;

  let records;
  try {
    records = await buildHavalaRecords({ ownerId, totalAmount, paidAmount, splits, dateInput: req.body.date });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const havala = await Havala.create(records);

  const populated = await Havala.findById(havala._id)
    .populate('ownerId', 'name mobile')
    .populate('splits.personId', 'name place');

  res.status(201).json(populated);
};

exports.update = async (req, res) => {
  const existing = await Havala.findOne({ _id: req.params.id, isDeleted: false });
  if (!existing) return res.status(404).json({ error: 'Not found' });

  const { ownerId, totalAmount, paidAmount, splits } = req.body;

  let records;
  try {
    records = await buildHavalaRecords({ ownerId, totalAmount, paidAmount, splits, dateInput: req.body.date });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  // Soft-delete old transactions tied to this havala
  const oldTransactionIds = [...existing.splits.map((s) => s.transactionId), ...existing.ownerTransactionIds];
  if (existing.pendingTransactionId) oldTransactionIds.push(existing.pendingTransactionId);
  await Transaction.updateMany({ _id: { $in: oldTransactionIds } }, { isDeleted: true });

  existing.ownerId = records.ownerId;
  existing.totalAmount = records.totalAmount;
  existing.paidAmount = records.paidAmount;
  existing.ownerTransactionIds = records.ownerTransactionIds;
  existing.pendingTransactionId = records.pendingTransactionId;
  existing.date = records.date;
  existing.splits = records.splits;
  await existing.save();

  const populated = await Havala.findById(existing._id)
    .populate('ownerId', 'name mobile')
    .populate('splits.personId', 'name place');

  res.json(populated);
};

exports.settle = async (req, res) => {
  const { amount, date, receivedVia } = req.body;
  const havala = await Havala.findOne({ _id: req.params.id, isDeleted: false }).populate('ownerId', 'name');
  if (!havala) return res.status(404).json({ error: 'Not found' });

  const pending = havala.totalAmount - havala.paidAmount;
  if (amount <= 0 || amount > pending) {
    return res.status(400).json({ error: `Settlement amount must be between 1 and ${pending}` });
  }

  // Normalise to UTC midnight to avoid IST timezone shift
  const datePart = String(date).slice(0, 10);
  const normalisedDate = new Date(`${datePart}T00:00:00.000Z`);

  const settleTxn = await Transaction.create({
    clientUuid: randomUUID(),
    personId: havala.ownerId._id,
    type: 'received',
    amount,
    paymentMode: 'cash',
    description: amount < pending ? 'Havala settlement (partial)' : 'Havala settlement',
    receivedVia: receivedVia || undefined,
    date: normalisedDate,
  });

  havala.paidAmount += amount;
  havala.ownerTransactionIds.push(settleTxn._id);

  const remainingPending = havala.totalAmount - havala.paidAmount;
  if (havala.pendingTransactionId) {
    if (remainingPending > 0) {
      await Transaction.findByIdAndUpdate(havala.pendingTransactionId, { amount: remainingPending });
    } else {
      await Transaction.findByIdAndUpdate(havala.pendingTransactionId, { isDeleted: true });
      havala.pendingTransactionId = null;
    }
  }

  await havala.save();

  const populated = await Havala.findById(havala._id)
    .populate('ownerId', 'name mobile')
    .populate('splits.personId', 'name place');

  res.json(populated);
};

exports.remove = async (req, res) => {
  const havala = await Havala.findOne({ _id: req.params.id, isDeleted: false });
  if (!havala) return res.status(404).json({ error: 'Not found' });

  const transactionIds = [...havala.splits.map((s) => s.transactionId), ...havala.ownerTransactionIds];
  if (havala.pendingTransactionId) transactionIds.push(havala.pendingTransactionId);
  await Transaction.updateMany({ _id: { $in: transactionIds } }, { isDeleted: true });

  havala.isDeleted = true;
  await havala.save();

  res.json({ success: true });
};
