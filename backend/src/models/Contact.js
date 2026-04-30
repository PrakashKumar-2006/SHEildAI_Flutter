const mongoose = require('mongoose');

const contactSchema = new mongoose.Schema({
  user_phone: {
    type: String,
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true
  },
  phone: {
    type: String,
    required: true
  },
  relationship: {
    type: String,
    default: 'Other'
  },
  isPrimary: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

// Ensure a user doesn't have the same contact multiple times
contactSchema.index({ user_phone: 1, phone: 1 }, { unique: true });

module.exports = mongoose.model('Contact', contactSchema);
