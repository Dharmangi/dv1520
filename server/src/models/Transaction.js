const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    clientUuid: { type: String, required: true, unique: true },
    personId: { type: mongoose.Schema.Types.ObjectId, ref: 'Person', required: true },
    type: { type: String, enum: ['received', 'paid'], required: true },
    amount: { type: Number, required: true }, // smallest currency unit (paise)
    categoryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Category' },
    paymentMode: { type: String, enum: ['cash', 'bank', 'upi', 'other'], default: 'cash' },
    description: String,
    receivedVia: String,
    receiptImageUrl: String,
    date: { type: Date, required: true },
    status: { type: String, enum: ['pending', 'confirmed'], default: 'confirmed' },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

transactionSchema.index({ personId: 1 });
transactionSchema.index({ date: 1 });

module.exports = mongoose.model('Transaction', transactionSchema);
