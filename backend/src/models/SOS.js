const mongoose = require('mongoose');

const sosSchema = new mongoose.Schema({
  user_phone: {
    type: String,
    required: true,
  },
  location: {
    lat: { type: Number, required: true },
    lon: { type: Number, required: true },
  },
  status: {
    type: String,
    enum: ['active', 'resolved', 'false_alarm'],
    default: 'active'
  },
  audio_url: {
    type: String, // If recording is uploaded
    default: null
  }
}, { timestamps: true });

module.exports = mongoose.model('SOS', sosSchema);
