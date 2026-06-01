const mongoose = require('mongoose');

const communityReportSchema = new mongoose.Schema({
  reporter_phone: {
    type: String,
    index: true
  },
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

communityReportSchema.index({ location: '2dsphere' });

module.exports = mongoose.models.CommunityReport || mongoose.model('CommunityReport', communityReportSchema, 'community_reports');
