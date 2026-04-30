const express = require('express');
const router = express.Router();
const contactController = require('../controllers/contactController');

// All routes here should ideally be protected by auth middleware
// For now, we follow the project's existing structure

router.get('/:userPhone', contactController.getContacts);
router.post('/:userPhone', contactController.addContact);
router.delete('/:userPhone/:contactPhone', contactController.removeContact);
router.patch('/:userPhone/:contactPhone/primary', contactController.setPrimary);

module.exports = router;
