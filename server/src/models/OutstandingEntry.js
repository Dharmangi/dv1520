const mongoose = require('mongoose');

const settlementSchema = new mongoose.Schema(
  {
    amount: { type: Number, required: true },
    date: { type: Date, required: true },
    note: { type: String, default: '' },
  },
  { timestamps: true }
);

const outstandingEntrySchema = new mongoose.Schema(
  {
    personId: { type: mongoose.Schema.Types.ObjectId, ref: 'Person', default: null },
    personName: { type: String, required: true },
    totalAmount: { type: Number, required: true },
    settledAmount: { type: Number, default: 0 },
    note: { type: String, default: '' },
    createdDate: { type: Date, required: true },  // date entry was created
    status: { type: String, enum: ['pending', 'settled'], default: 'pending' },
    settlements: [settlementSchema],
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

outstandingEntrySchema.virtual('pendingAmount').get(function () {
  return this.totalAmount - this.settledAmount;
});

module.exports = mongoose.model('OutstandingEntry', outstandingEntrySchema);
