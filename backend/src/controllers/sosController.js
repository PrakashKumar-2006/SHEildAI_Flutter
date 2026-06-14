const sosRepository = require('../repositories/SOSRepository');
const logger = require('../utils/logger');
const crypto = require('crypto');

const sosController = {
  triggerSOS: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { user_id, latitude, longitude, message } = req.body;
      const phone = user_id; // Mapping user_id to phone

      if (!phone) {
        return res.status(400).json({ error: 'User ID (phone) is required' });
      }

      // Ownership check: Authenticated user must own this phone session
      if (req.user.phone !== phone && req.user.email !== phone && req.user._id.toString() !== phone) {
        return res.status(403).json({ error: 'Forbidden: You cannot trigger SOS for another user' });
      }

      const sosData = {
        user_phone: phone,
        location: {
          lat: latitude,
          lon: longitude
        },
        message: message || 'SOS triggered',
        status: 'active'
      };

      const sos = await sosRepository.createSOS(sosData, traceId);

      // Emit real-time event
      const io = req.app.get('io');
      if (io) {
        io.emit('new_sos_alert', {
          _id: sos._id,
          user_phone: phone,
          location: sosData.location,
          status: 'active'
        });
      }

      logger.info(`SOS triggered and persisted for phone: ${phone}`, traceId);
      res.status(200).json({ 
        success: true, 
        message: 'SOS triggered and persisted', 
        sosId: sos._id 
      });
    } catch (error) {
      logger.error('triggerSOS error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  updateStatus: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { sosId } = req.params;
      const { status } = req.body;

      if (!sosId || !status) {
        return res.status(400).json({ error: 'SOS ID and status are required' });
      }

      // Ownership check: Authenticated user must own the SOS record
      const mongoose = require('mongoose');
      if (!mongoose.Types.ObjectId.isValid(sosId)) {
        return res.status(400).json({ error: 'Invalid SOS ID format' });
      }

      const sosRecord = await sosRepository.findOne({ _id: sosId }, {}, {}, traceId);
      if (!sosRecord) {
        return res.status(404).json({ error: 'SOS record not found' });
      }

      if (sosRecord.user_phone !== req.user.phone && sosRecord.user_phone !== req.user.email) {
        return res.status(403).json({ error: 'Forbidden: You do not own this SOS record' });
      }

      const updated = await sosRepository.updateStatus(sosId, status, traceId);

      if (!updated) {
        return res.status(404).json({ error: 'SOS record not found' });
      }

      // Emit real-time event
      const io = req.app.get('io');
      if (io) {
        io.emit('sos_status_updated', {
          _id: sosId,
          status: status
        });
      }

      logger.info(`SOS status updated to ${status} for ID: ${sosId}`, traceId);
      res.status(200).json({ success: true, message: `SOS status updated to ${status}` });
    } catch (error) {
      logger.error('updateStatus error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  }
};

module.exports = sosController;
