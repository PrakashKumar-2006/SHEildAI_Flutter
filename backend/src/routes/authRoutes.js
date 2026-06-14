const express = require('express');
const router = express.Router();
const { getToken, updateLocation, getProfile } = require('../controllers/authController');
const { authLimiter } = require('../middleware/rateLimiter');

// Token generation for API access
router.post('/token', authLimiter, getToken);

// Legacy routes (kept for compatibility or future implementation)
router.post('/register', authLimiter, (req, res) => res.status(501).json({ error: 'Not implemented' }));
router.post('/login', authLimiter, (req, res) => res.status(501).json({ error: 'Not implemented' }));

module.exports = router;
