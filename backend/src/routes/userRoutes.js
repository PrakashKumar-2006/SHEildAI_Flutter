const express = require('express');
const router = express.Router();
const { updateLocation, getProfile } = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const { locationLimiter, profileLimiter } = require('../middleware/rateLimiter');

// Location sync heartbeat
router.post('/location', protect, locationLimiter, updateLocation);

// User profile lookup
router.get('/profile/:userId', protect, profileLimiter, getProfile);

module.exports = router;
