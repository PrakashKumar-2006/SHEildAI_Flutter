const express = require('express');
const router = express.Router();
const contactController = require('../controllers/contactController');
const { protect } = require('../middleware/auth');
const { contactLimiter } = require('../middleware/rateLimiter');

// All routes here must be protected by auth middleware
router.get('/:userPhone', protect, contactLimiter, contactController.getContacts);
router.post('/:userPhone', protect, contactLimiter, contactController.addContact);
router.delete('/:userPhone/:contactPhone', protect, contactLimiter, contactController.removeContact);
router.patch('/:userPhone/:contactPhone/primary', protect, contactLimiter, contactController.setPrimary);

module.exports = router;
