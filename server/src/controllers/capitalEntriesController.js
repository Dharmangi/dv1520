const CapitalEntry = require('../models/CapitalEntry');

exports.list = async (req, res) => {
  const entries = await CapitalEntry.find({ isDeleted: false }).sort({ date: -1 });
  res.json(entries);
};

exports.create = async (req, res) => {
  try {
    const entry = await CapitalEntry.create(req.body);
    res.status(201).json(entry);
  } catch (err) {
    if (err.code === 11000) {
      const existing = await CapitalEntry.findOne({ clientUuid: req.body.clientUuid });
      return res.status(200).json(existing);
    }
    throw err;
  }
};

exports.update = async (req, res) => {
  const entry = await CapitalEntry.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!entry) return res.status(404).json({ error: 'Not found' });
  res.json(entry);
};

exports.remove = async (req, res) => {
  const entry = await CapitalEntry.findByIdAndUpdate(req.params.id, { isDeleted: true }, { new: true });
  if (!entry) return res.status(404).json({ error: 'Not found' });
  res.json(entry);
};
