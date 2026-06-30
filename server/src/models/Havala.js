const mongoose = require('mongoose');

const havalaSplitSchema = new mongoose.Schema(
  {
    personId: { type: mongoose.Schema.Types.ObjectId, ref: 'Person', required: true },
    amount: { type: Number, required: true },
    date: { type: Date, required: true },
    transactionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Transaction', required: true },
  },
  { _id: false }
);

const havalaSchema = new mongoose.Schema(
  {
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Person', required: true },
    totalAmount: { type: Number, required: true },
    paidAmount: { type: Number, required: true, default: 0 },
    ownerTransactionIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Transaction' }],
    pendingTransactionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Transaction', default: null },
    date: { type: Date, required: true },
    splits: [havalaSplitSchema],
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Havala', havalaSchema);
