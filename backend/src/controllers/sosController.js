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

      const updated = await sosRepository.updateStatus(sosId, status, traceId);

      if (!updated) {
        return res.status(404).json({ error: 'SOS record not found' });
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
