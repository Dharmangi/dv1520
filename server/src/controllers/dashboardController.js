const Transaction = require('../models/Transaction');
const CapitalEntry = require('../models/CapitalEntry');

async function capitalTotal() {
  const result = await CapitalEntry.aggregate([
    { $match: { isDeleted: false } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  return result[0]?.total ?? 0;
}

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function startOfMonth() {
  const d = new Date();
  d.setDate(1);
  d.setHours(0, 0, 0, 0);
  return d;
}

async function sumByType(matchExtra) {
  const result = await Transaction.aggregate([
    { $match: { isDeleted: false, status: { $ne: 'pending' }, ...matchExtra } },
    { $group: { _id: '$type', total: { $sum: '$amount' } } },
  ]);
  const totals = { received: 0, paid: 0 };
  result.forEach((r) => (totals[r._id] = r.total));
  return totals;
}

exports.summary = async (req, res) => {
  const [overall, today, month, capital] = await Promise.all([
    sumByType({}),
    sumByType({ date: { $gte: startOfToday() } }),
    sumByType({ date: { $gte: startOfMonth() } }),
    capitalTotal(),
  ]);

  const netBalance = overall.received - overall.paid + capital;

  res.json({
    currentBalance: netBalance,
    myBalance: capital,
    todayIncome: today.received,
    todayExpense: today.paid,
    monthlyIncome: month.received,
    monthlyExpense: month.paid,
    netBalance,
  });
};

function dateRangeMatch(from, to) {
  const match = {};
  if (from || to) {
    match.date = {};
    if (from) match.date.$gte = new Date(from);
    if (to) match.date.$lte = new Date(to);
  }
  return match;
}

exports.rangeSummary = async (req, res) => {
  const { from, to } = req.query;
  const totals = await sumByType(dateRangeMatch(from, to));
  res.json({
    received: totals.received,
    paid: totals.paid,
    net: totals.received - totals.paid,
  });
};

exports.byPerson = async (req, res) => {
  const { from, to } = req.query;
  const result = await Transaction.aggregate([
    { $match: { isDeleted: false, status: { $ne: 'pending' }, ...dateRangeMatch(from, to) } },
    {
      $group: {
        _id: '$personId',
        received: { $sum: { $cond: [{ $eq: ['$type', 'received'] }, '$amount', 0] } },
        paid: { $sum: { $cond: [{ $eq: ['$type', 'paid'] }, '$amount', 0] } },
      },
    },
    {
      $lookup: {
        from: 'people',
        localField: '_id',
        foreignField: '_id',
        as: 'person',
      },
    },
    { $unwind: '$person' },
    {
      $project: {
        personId: '$_id',
        personName: '$person.name',
        received: 1,
        paid: 1,
        net: { $subtract: ['$received', '$paid'] },
      },
    },
    { $sort: { net: -1 } },
  ]);

  res.json(result);
};

exports.byCategory = async (req, res) => {
  const { from, to } = req.query;
  const result = await Transaction.aggregate([
    { $match: { isDeleted: false, status: { $ne: 'pending' }, categoryId: { $ne: null }, ...dateRangeMatch(from, to) } },
    {
      $group: {
        _id: '$categoryId',
        total: { $sum: '$amount' },
      },
    },
    {
      $lookup: {
        from: 'categories',
        localField: '_id',
        foreignField: '_id',
        as: 'category',
      },
    },
    { $unwind: '$category' },
    {
      $project: {
        categoryId: '$_id',
        categoryName: '$category.name',
        categoryType: '$category.type',
        total: 1,
      },
    },
    { $sort: { total: -1 } },
  ]);

  res.json(result);
};

exports.timeSeries = async (req, res) => {
  const { from, to } = req.query;
  const result = await Transaction.aggregate([
    { $match: { isDeleted: false, status: { $ne: 'pending' }, ...dateRangeMatch(from, to) } },
    {
      $group: {
        _id: { date: { $dateToString: { format: '%Y-%m-%d', date: '$date' } }, type: '$type' },
        total: { $sum: '$amount' },
      },
    },
    { $sort: { '_id.date': 1 } },
  ]);

  const byDate = {};
  result.forEach((r) => {
    const date = r._id.date;
    if (!byDate[date]) byDate[date] = { date, received: 0, paid: 0 };
    byDate[date][r._id.type] = r.total;
  });

  res.json(Object.values(byDate));
};
