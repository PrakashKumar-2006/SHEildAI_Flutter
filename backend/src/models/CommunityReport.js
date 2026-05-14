const mongoose = require('mongoose');

const communityReportSchema = new mongoose.Schema({
  phone: String,
  latitude: Number,
  longitude: Number,
  incident_type: String,
  description: String,
  severity: Number,
  anonymous: Boolean,
  timestamp: String,
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number] }
  }
}, { timestamps: true, strict: false });

module.exports = mongoose.models.CommunityReport || mongoose.model('CommunityReport', communityReportSchema, 'community_reports');
