const contactRepository = require('../repositories/ContactRepository');
const logger = require('../utils/logger');
const crypto = require('crypto');

const contactController = {
  getContacts: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { userPhone } = req.params;
      const contacts = await contactRepository.findByUser(userPhone, traceId);
      res.status(200).json(contacts);
    } catch (error) {
      logger.error('getContacts error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  addContact: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { userPhone } = req.params;
      const { name, phone, relationship, isPrimary } = req.body;

      if (!name || !phone) {
        return res.status(400).json({ error: 'Name and phone are required' });
      }

      const contact = await contactRepository.addContact({
        user_phone: userPhone,
        name,
        phone,
        relationship,
        isPrimary: isPrimary || false
      }, traceId);

      res.status(201).json({ success: true, contact });
    } catch (error) {
      if (error.originalError && error.originalError.code === 11000) {
        return res.status(400).json({ error: 'Contact already exists for this user' });
      }
      logger.error('addContact error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  removeContact: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { userPhone, contactPhone } = req.params;
      await contactRepository.removeContact(userPhone, contactPhone, traceId);
      res.status(200).json({ success: true, message: 'Contact removed' });
    } catch (error) {
      logger.error('removeContact error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  },

  setPrimary: async (req, res) => {
    const traceId = req.headers['x-trace-id'] || crypto.randomUUID();
    try {
      const { userPhone, contactPhone } = req.params;
      const updated = await contactRepository.setPrimary(userPhone, contactPhone, traceId);
      if (!updated) {
        return res.status(404).json({ error: 'Contact not found' });
      }
      res.status(200).json({ success: true, contact: updated });
    } catch (error) {
      logger.error('setPrimary error', traceId, error);
      res.status(500).json({ error: 'Internal server error', traceId });
    }
  }
};

module.exports = contactController;
