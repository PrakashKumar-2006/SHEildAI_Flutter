const express = require('express');
const router = express.Router();
const { triggerSOS, updateStatus } = require('../controllers/sosController');
const { protect } = require('../middleware/auth');
const { sosLimiter } = require('../middleware/rateLimiter');

router.post('/trigger', protect, sosLimiter, triggerSOS);
router.put('/:sosId/status', protect, sosLimiter, updateStatus);

module.exports = router;
