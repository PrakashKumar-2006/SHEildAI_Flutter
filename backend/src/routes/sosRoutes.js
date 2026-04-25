const express = require('express');
const router = express.Router();
const { createSOS, getSOSHistory, updateSOSStatus } = require('../controllers/sosController');
const { protect } = require('../middleware/auth');

router.post('/', protect, createSOS);
router.get('/history', protect, getSOSHistory);
router.put('/:id/status', protect, updateSOSStatus);

module.exports = router;
