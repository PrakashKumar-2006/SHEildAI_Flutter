const userRepository = require('../repositories/UserRepository');
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');
const crypto = require('crypto');

const authController = {
  // Simple token generation for demo/testing
  getToken: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { phone, firebase_uid, email } = req.body;
      if (!phone && !firebase_uid && !email) {
        return res.status(400).json({ error: 'Phone, firebase_uid, or email is required' });
      }

      // Check if user exists in MongoDB using any provided identifier
      let user = null;
      if (firebase_uid) {
        user = await userRepository.findByFirebaseUid(firebase_uid, traceId);
      }
      if (!user && phone) {
        user = await userRepository.findByPhone(phone, traceId);
      }
      if (!user && email) {
        user = await userRepository.findByEmail(email, traceId);
      }
      
      const token = jwt.sign(
        { 
          phone: user ? user.phone : (phone || ''), 
          firebase_uid: user ? user.firebase_uid : (firebase_uid || ''),
          email: user ? user.email : (email || ''),
          userId: user ? user._id : null 
        },
        process.env.JWT_SECRET || 'sheildai_secret',
        { expiresIn: '7d' }
      );

      logger.info(`Token generated for: ${phone || firebase_uid || email}`, traceId);
      res.status(200).json({ token, userExists: !!user });
    } catch (error) {
      logger.error('getToken error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  updateLocation: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { user_id, latitude, longitude, name, firebase_uid } = req.body;
      const phone = user_id; // Mapping user_id to phone for this flow
      
      if (!phone && !firebase_uid) {
        return res.status(400).json({ error: 'User ID (phone) or firebase_uid is required' });
      }

      let user = null;
      if (firebase_uid) {
        user = await userRepository.findByFirebaseUid(firebase_uid, traceId);
      }
      if (!user && phone) {
        user = await userRepository.findByPhone(phone, traceId);
        if (!user && phone.includes('@')) {
          user = await userRepository.findByEmail(phone, traceId);
        }
      }
      
      if (!user) {
        logger.info(`Creating new shadow user for phone: ${phone || 'N/A'}`, traceId);
        user = await userRepository.createUser({
          phone: phone || `shadow_${Date.now()}`,
          firebase_uid: firebase_uid,
          name: name || 'User',
          last_lat: latitude,
          last_lon: longitude,
          last_seen: new Date()
        }, traceId);
      } else {
        const identifierPhone = user.phone;
        await userRepository.updateLastLocation(identifierPhone, latitude, longitude, traceId);
      }

      const io = req.app.get('io');
      const lat = Number(latitude);
      const lon = Number(longitude);
      if (io && Number.isFinite(lat) && Number.isFinite(lon)) {
        io.emit('user_location_updated', {
          phone: user.phone,
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
      let user = await userRepository.findByPhone(userId, traceId);
      if (!user && userId.includes('@')) {
        user = await userRepository.findByEmail(userId, traceId);
      }
      if (!user && userId.length > 20) {
        user = await userRepository.findByFirebaseUid(userId, traceId);
      }
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.status(200).json(user);
    } catch (error) {
      logger.error('getProfile error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  }
};

module.exports = authController;
