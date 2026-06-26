const userRepository = require('../repositories/UserRepository');
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');
const crypto = require('crypto');
const admin = require('firebase-admin');

const authController = {
  // Verifies Firebase ID Token and issues SHEild AI JWT
  getToken: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { idToken } = req.body;
      if (!idToken) {
        return res.status(400).json({ error: 'idToken is required' });
      }

      // Verify ID Token with Firebase Admin SDK
      let decodedToken;
      try {
        decodedToken = await admin.auth().verifyIdToken(idToken);
      } catch (err) {
        logger.error('Firebase ID Token verification failed', traceId, err);
        return res.status(401).json({ error: 'Unauthorized: Invalid or expired Firebase ID Token' });
      }

      const { uid: firebase_uid, email, phone_number } = decodedToken;
      const phone = phone_number || '';

      // Check if user exists in MongoDB using verified identifiers
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
      
      // Auto-create user if they don't exist yet
      if (!user) {
        logger.info(`Creating user from verified Firebase token for: ${email || phone || firebase_uid}`, traceId);
        user = await userRepository.createUser({
          firebase_uid,
          phone: phone || '',
          email: email || '',
          name: 'User',
          last_seen: new Date()
        }, traceId);
      } else {
        // If user exists but firebase_uid is not associated yet, associate it now
        if (!user.firebase_uid && firebase_uid) {
          user = await userRepository.updateOne(
            { _id: user._id },
            { $set: { firebase_uid } },
            { new: true },
            traceId
          );
        }
      }

      const token = jwt.sign(
        { 
          phone: user.phone || phone, 
          firebase_uid: user.firebase_uid || firebase_uid,
          email: user.email || email || '',
          userId: user._id 
        },
        process.env.JWT_SECRET,
        { expiresIn: '7d' }
      );

      logger.info(`Token generated for verified user: ${user.phone || user.email || user.firebase_uid}`, traceId);
      res.status(200).json({ token, userExists: true });
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

      // Ownership check: Authenticated user must match the target update ID
      if (phone && req.user.phone !== phone && req.user._id.toString() !== phone) {
        return res.status(403).json({ error: 'Forbidden: You cannot update another user\'s location' });
      }
      if (firebase_uid && req.user.firebase_uid !== firebase_uid) {
        return res.status(403).json({ error: 'Forbidden: You cannot update another user\'s location' });
      }

      let user = null;
      if (firebase_uid) {
        user = await userRepository.findByFirebaseUid(firebase_uid, traceId);
      }
      if (!user && phone && !phone.includes('@')) {
        user = await userRepository.findByPhone(phone, traceId);
      }
      
      if (!user) {
        logger.info(`Creating new shadow user for phone: ${phone || 'N/A'}`, traceId);
        user = await userRepository.createUser({
          phone: (phone && !phone.includes('@')) ? phone : '',
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

      // Ownership check: Authenticated user must match the target profile ID
      if (req.user.phone !== userId && req.user.email !== userId && req.user.firebase_uid !== userId && req.user._id.toString() !== userId) {
        return res.status(403).json({ error: 'Forbidden: You cannot view another user\'s profile' });
      }
      let user = null;
      if (!userId.includes('@')) {
        user = await userRepository.findByPhone(userId, traceId);
      } else {
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
