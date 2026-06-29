const Person = require('../models/Person');
const Transaction = require('../models/Transaction');

exports.list = async (req, res) => {
  const people = await Person.find({ isDeleted: false }).sort({ name: 1 }).populate('ownerId', 'name');
  res.json(people);
};

exports.ledger = async (req, res) => {
  const owner = await Person.findOne({ _id: req.params.id, isDeleted: false });
  if (!owner) return res.status(404).json({ error: 'Not found' });

  const customers = await Person.find({ ownerId: owner._id, isDeleted: false });
  const personIds = [owner._id, ...customers.map((c) => c._id)];

  const transactions = await Transaction.find({ personId: { $in: personIds }, isDeleted: false })
    .sort({ date: -1 })
    .populate('personId', 'name')
    .populate('categoryId', 'name type');

  res.json({ owner, customers, transactions });
};

exports.create = async (req, res) => {
  const person = await Person.create(req.body);
  res.status(201).json(person);
};

exports.update = async (req, res) => {
  const person = await Person.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!person) return res.status(404).json({ error: 'Not found' });
  res.json(person);
};

exports.remove = async (req, res) => {
  const person = await Person.findByIdAndUpdate(req.params.id, { isDeleted: true }, { new: true });
  if (!person) return res.status(404).json({ error: 'Not found' });
  await Transaction.updateMany({ personId: req.params.id }, { isDeleted: true });
  res.json(person);
};
