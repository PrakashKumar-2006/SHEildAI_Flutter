const express = require('express');
const router = express.Router();
const { getToken, updateLocation, getProfile } = require('../controllers/authController');

// Token generation for API access
router.post('/token', getToken);

// Legacy routes (kept for compatibility or future implementation)
router.post('/register', (req, res) => res.status(501).json({ error: 'Not implemented' }));
router.post('/login', (req, res) => res.status(501).json({ error: 'Not implemented' }));

module.exports = router;
