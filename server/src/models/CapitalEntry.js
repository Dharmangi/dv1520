const mongoose = require('mongoose');

const capitalEntrySchema = new mongoose.Schema(
  {
    clientUuid: { type: String, required: true, unique: true },
    amount: { type: Number, required: true }, // smallest currency unit (paise), can be negative
    note: String,
    date: { type: Date, required: true },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true }
);

capitalEntrySchema.index({ date: 1 });

module.exports = mongoose.model('CapitalEntry', capitalEntrySchema);
