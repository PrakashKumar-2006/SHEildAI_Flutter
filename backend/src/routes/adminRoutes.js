const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');

// ─── Dashboard Stats ─────────────────────────────────────────────────────────
router.get('/stats', adminController.getStats);

// ─── Users CRUD ──────────────────────────────────────────────────────────────
router.get('/users', adminController.getAllUsers);
router.get('/users/:id', adminController.getUserById);
router.put('/users/:id', adminController.updateUser);
router.delete('/users/:id', adminController.deleteUser);

// ─── SOS Incidents CRUD ──────────────────────────────────────────────────────
router.get('/sos', adminController.getAllSOS);
router.get('/sos/:id', adminController.getSOSById);
router.put('/sos/:id', adminController.updateSOS);
router.delete('/sos/:id', adminController.deleteSOS);

// ─── Contacts CRUD ───────────────────────────────────────────────────────────
router.get('/contacts', adminController.getAllContacts);
router.delete('/contacts/:id', adminController.deleteContact);

// ─── Analytics & Trends ──────────────────────────────────────────────────────
router.get('/analytics/incidents-by-day', adminController.incidentsByDay);
router.get('/analytics/incidents-by-status', adminController.incidentsByStatus);
router.get('/analytics/heatmap', adminController.getHeatmapData);
router.get('/analytics/top-zones', adminController.getTopZones);

// ─── Risk Zones (from risk_data.json — same as Flutter app) ─────────────────
router.get('/risk-zones', adminController.getRiskZones);

module.exports = router;
