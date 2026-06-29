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

exports.create = async (req, res) => {
  const { ownerId, totalAmount, paidAmount, date, splits } = req.body;

  const splitsTotal = splits.reduce((sum, s) => sum + s.amount, 0);
  if (splitsTotal !== totalAmount) {
    return res.status(400).json({ error: 'Split amounts must add up to the total amount' });
  }
  if (paidAmount > totalAmount) {
    return res.status(400).json({ error: 'Paid amount cannot exceed total amount' });
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
    const txn = await Transaction.create({
      clientUuid: randomUUID(),
      personId: split.personId,
      type: 'paid',
      amount: split.amount,
      paymentMode: 'cash',
      description: 'Havala payout',
      date,
    });
    splitRecords.push({ personId: split.personId, amount: split.amount, transactionId: txn._id });
  }

  const havala = await Havala.create({
    ownerId,
    totalAmount,
    paidAmount,
    ownerTransactionIds,
    pendingTransactionId,
    date,
    splits: splitRecords,
  });

  const populated = await Havala.findById(havala._id)
    .populate('ownerId', 'name mobile')
    .populate('splits.personId', 'name place');

  res.status(201).json(populated);
};

exports.settle = async (req, res) => {
  const { amount, date } = req.body;
  const havala = await Havala.findOne({ _id: req.params.id, isDeleted: false });
  if (!havala) return res.status(404).json({ error: 'Not found' });

  const pending = havala.totalAmount - havala.paidAmount;
  if (amount <= 0 || amount > pending) {
    return res.status(400).json({ error: `Settlement amount must be between 1 and ${pending}` });
  }

  const settleTxn = await Transaction.create({
    clientUuid: randomUUID(),
    personId: havala.ownerId,
    type: 'received',
    amount,
    paymentMode: 'cash',
    description: amount < pending ? 'Havala settlement (partial)' : 'Havala settlement',
    date,
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
