const Transaction = require('../models/Transaction');

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
