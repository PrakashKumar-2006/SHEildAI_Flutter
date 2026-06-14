const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { protect, adminOnly } = require('../middleware/auth');
const { adminLimiter } = require('../middleware/rateLimiter');

// Protect all admin routes with authentication and admin authorization (RBAC)
router.use(protect, adminOnly, adminLimiter);

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
router.get('/analytics/response-time', adminController.getResponseTimeAnalytics);

// ─── Broadcast & Community ───────────────────────────────────────────────────
router.post('/broadcast', adminController.sendBroadcast);
router.get('/community-reports', adminController.getAllCommunityReports);
router.get('/live-locations', adminController.getLiveLocations);

// ─── Risk Zones (from risk_data.json — same as Flutter app) ─────────────────
router.get('/risk-zones', adminController.getRiskZones);

module.exports = router;
