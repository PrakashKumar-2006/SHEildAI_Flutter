const express = require('express');
const router = express.Router();
const { updateLocation, getProfile } = require('../controllers/authController');

// Location sync heartbeat
router.post('/location', updateLocation);

// User profile lookup
router.get('/profile/:userId', getProfile);

module.exports = router;
