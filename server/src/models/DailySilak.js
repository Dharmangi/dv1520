const mongoose = require('mongoose');

const dailySilakEntrySchema = new mongoose.Schema(
  {
    personId: { type: mongoose.Schema.Types.ObjectId, ref: 'Person', default: null },
    personName: { type: String, required: true },
    amount: { type: Number, required: true },
    type: { type: String, enum: ['received', 'paid'], required: true },
    note: { type: String, default: '' },
    havalaId: { type: mongoose.Schema.Types.ObjectId, ref: 'Havala', default: null },
    isPending: { type: Boolean, default: false },
    isSettlement: { type: Boolean, default: false },
  },
  { _id: true }
);

const dailySilakSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    entries: [dailySilakEntrySchema],
    totalReceived: { type: Number, default: 0 },
    totalPaid: { type: Number, default: 0 },
    netBalance: { type: Number, default: 0 },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

// Compound index — one silak per date (not unique to avoid crash, handled in controller)
dailySilakSchema.index({ date: 1, isDeleted: 1 });

module.exports = mongoose.model('DailySilak', dailySilakSchema);
