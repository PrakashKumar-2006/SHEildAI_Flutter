const userRepository = require('../repositories/UserRepository');
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');
const crypto = require('crypto');

const authController = {
  // Simple token generation for demo/testing
  getToken: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { phone } = req.body;
      if (!phone) {
        return res.status(400).json({ error: 'Phone number is required' });
      }

      // Check if user exists in MongoDB
      const user = await userRepository.findByPhone(phone, traceId);
      
      const token = jwt.sign(
        { phone, userId: user ? user._id : null },
        process.env.JWT_SECRET || 'sheildai_secret',
        { expiresIn: '7d' }
      );

      logger.info(`Token generated for phone: ${phone}`, traceId);
      res.status(200).json({ token, userExists: !!user });
    } catch (error) {
      logger.error('getToken error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  updateLocation: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { user_id, latitude, longitude, name } = req.body;
      const phone = user_id; // Mapping user_id to phone for this flow
      
      if (!phone) {
        return res.status(400).json({ error: 'User ID (phone) is required' });
      }

      let user = await userRepository.findByPhone(phone, traceId);
      
      if (!user) {
        logger.info(`Creating new shadow user for phone: ${phone}`, traceId);
        user = await userRepository.createUser({
          phone: phone,
          name: name || 'User',
          last_lat: latitude,
          last_lon: longitude,
          last_seen: new Date()
        }, traceId);
      } else {
        await userRepository.updateLastLocation(phone, latitude, longitude, traceId);
      }

      const io = req.app.get('io');
      const lat = Number(latitude);
      const lon = Number(longitude);
      if (io && Number.isFinite(lat) && Number.isFinite(lon)) {
        io.emit('user_location_updated', {
          phone,
          name: name || user.name || 'User',
          lat,
          lon,
          lastSeen: new Date().toISOString()
        });
      }

      res.status(200).json({ success: true, message: 'Location updated' });
    } catch (error) {
      logger.error('updateLocation error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  getProfile: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { userId } = req.params;
      const user = await userRepository.findByPhone(userId, traceId);
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.status(200).json(user);
    } catch (error) {
      logger.error('getProfile error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  }
};

module.exports = authController;
