const mongoose = require('mongoose');
const { dataConnection } = require('../config/db');

const sosSchema = new mongoose.Schema({
  user_phone: {
    type: String,
    required: true,
    index: true
  },
  location: {
    lat: { type: Number, required: true },
    lon: { type: Number, required: true },
  },
  message: {
    type: String,
    default: 'SOS Triggered'
  },
  status: {
    type: String,
    enum: ['active', 'resolved', 'false_alarm'],
    default: 'active',
    index: true
  },
  audio_url: {
    type: String,
    default: null
  }
}, { timestamps: true });

module.exports = dataConnection.model('SOS', sosSchema);
