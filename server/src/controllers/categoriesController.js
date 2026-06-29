const Category = require('../models/Category');

exports.list = async (req, res) => {
  const categories = await Category.find().sort({ name: 1 });
  res.json(categories);
};

exports.create = async (req, res) => {
  const category = await Category.create(req.body);
  res.status(201).json(category);
};

exports.update = async (req, res) => {
  const category = await Category.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!category) return res.status(404).json({ error: 'Not found' });
  res.json(category);
};

exports.remove = async (req, res) => {
  const category = await Category.findByIdAndDelete(req.params.id);
  if (!category) return res.status(404).json({ error: 'Not found' });
  res.json({ success: true });
};
