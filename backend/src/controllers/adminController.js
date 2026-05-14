const User = require('../models/User');
const SOS = require('../models/SOS');
const Contact = require('../models/Contact');
const CommunityReport = require('../models/CommunityReport');
const fs = require('fs');
const path = require('path');

const adminController = {
  // ─── Dashboard Stats ────────────────────────────────────────────────────────
  getStats: async (req, res) => {
    try {
      const [totalUsers, totalSOS, activeSOS, resolvedSOS, falseAlarmSOS, totalContacts] = await Promise.all([
        User.countDocuments(),
        SOS.countDocuments(),
        SOS.countDocuments({ status: 'active' }),
        SOS.countDocuments({ status: 'resolved' }),
        SOS.countDocuments({ status: 'false_alarm' }),
        Contact.countDocuments(),
      ]);

      // Users registered in the last 30 days
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const newUsersThisMonth = await User.countDocuments({ createdAt: { $gte: thirtyDaysAgo } });

      // SOS in last 24h
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const sosLast24h = await SOS.countDocuments({ createdAt: { $gte: oneDayAgo } });

      res.json({
        totalUsers,
        totalSOS,
        activeSOS,
        resolvedSOS,
        falseAlarmSOS,
        totalContacts,
        newUsersThisMonth,
        sosLast24h,
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── Users ──────────────────────────────────────────────────────────────────
  getAllUsers: async (req, res) => {
    try {
      const { page = 1, limit = 20, search = '' } = req.query;
      const query = search
        ? { $or: [{ phone: { $regex: search, $options: 'i' } }, { name: { $regex: search, $options: 'i' } }, { email: { $regex: search, $options: 'i' } }] }
        : {};
      const users = await User.find(query)
        .select('-password')
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(Number(limit));
      const total = await User.countDocuments(query);
      res.json({ users, total, page: Number(page), totalPages: Math.ceil(total / limit) });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  getUserById: async (req, res) => {
    try {
      const user = await User.findById(req.params.id).select('-password');
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json(user);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  updateUser: async (req, res) => {
    try {
      const { name, email, phone } = req.body;
      const user = await User.findByIdAndUpdate(
        req.params.id,
        { name, email, phone },
        { new: true, runValidators: true }
      ).select('-password');
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json({ success: true, user });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  deleteUser: async (req, res) => {
    try {
      const user = await User.findByIdAndDelete(req.params.id);
      if (!user) return res.status(404).json({ error: 'User not found' });
      // Also delete their contacts and SOS records
      await Contact.deleteMany({ user_phone: user.phone });
      await SOS.deleteMany({ user_phone: user.phone });
      res.json({ success: true, message: 'User and related data deleted' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── SOS Incidents ──────────────────────────────────────────────────────────
  getAllSOS: async (req, res) => {
    try {
      const { page = 1, limit = 20, status = '', search = '' } = req.query;
      const query = {};
      if (status) query.status = status;
      if (search) query.user_phone = { $regex: search, $options: 'i' };

      const sosList = await SOS.find(query)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(Number(limit));
      const total = await SOS.countDocuments(query);
      res.json({ sos: sosList, total, page: Number(page), totalPages: Math.ceil(total / limit) });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  getSOSById: async (req, res) => {
    try {
      const sos = await SOS.findById(req.params.id);
      if (!sos) return res.status(404).json({ error: 'SOS record not found' });
      res.json(sos);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  updateSOS: async (req, res) => {
    try {
      const { status, message } = req.body;
      const valid = ['active', 'resolved', 'false_alarm'];
      if (status && !valid.includes(status)) {
        return res.status(400).json({ error: 'Invalid status value' });
      }
      const sos = await SOS.findByIdAndUpdate(
        req.params.id,
        { ...(status && { status }), ...(message && { message }) },
        { new: true }
      );
      if (!sos) return res.status(404).json({ error: 'SOS record not found' });
      res.json({ success: true, sos });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  deleteSOS: async (req, res) => {
    try {
      const sos = await SOS.findByIdAndDelete(req.params.id);
      if (!sos) return res.status(404).json({ error: 'SOS record not found' });
      res.json({ success: true, message: 'SOS record deleted' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── Contacts ───────────────────────────────────────────────────────────────
  getAllContacts: async (req, res) => {
    try {
      const { page = 1, limit = 20, search = '' } = req.query;
      const query = search
        ? { $or: [{ user_phone: { $regex: search, $options: 'i' } }, { name: { $regex: search, $options: 'i' } }] }
        : {};
      const contacts = await Contact.find(query)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(Number(limit));
      const total = await Contact.countDocuments(query);
      res.json({ contacts, total, page: Number(page), totalPages: Math.ceil(total / limit) });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  deleteContact: async (req, res) => {
    try {
      const contact = await Contact.findByIdAndDelete(req.params.id);
      if (!contact) return res.status(404).json({ error: 'Contact not found' });
      res.json({ success: true, message: 'Contact deleted' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── Analytics ──────────────────────────────────────────────────────────────
  incidentsByDay: async (req, res) => {
    try {
      const days = parseInt(req.query.days) || 30;
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

      const data = await SOS.aggregate([
        { $match: { createdAt: { $gte: since } } },
        {
          $group: {
            _id: {
              year: { $year: '$createdAt' },
              month: { $month: '$createdAt' },
              day: { $dayOfMonth: '$createdAt' },
            },
            count: { $sum: 1 },
          },
        },
        { $sort: { '_id.year': 1, '_id.month': 1, '_id.day': 1 } },
      ]);

      const formatted = data.map((d) => ({
        date: `${d._id.year}-${String(d._id.month).padStart(2, '0')}-${String(d._id.day).padStart(2, '0')}`,
        count: d.count,
      }));

      res.json(formatted);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  incidentsByStatus: async (req, res) => {
    try {
      const data = await SOS.aggregate([
        { $group: { _id: '$status', count: { $sum: 1 } } },
      ]);
      res.json(data.map((d) => ({ status: d._id, count: d.count })));
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  getHeatmapData: async (req, res) => {
    try {
      // Return all SOS location points for heatmap
      const sosList = await SOS.find(
        { 'location.lat': { $ne: null }, 'location.lon': { $ne: null } },
        { 'location.lat': 1, 'location.lon': 1, status: 1, createdAt: 1, message: 1, user_phone: 1 }
      ).sort({ createdAt: -1 }).limit(500);

      const points = sosList.map((s) => ({
        lat: s.location.lat,
        lon: s.location.lon,
        status: s.status,
        createdAt: s.createdAt,
        message: s.message,
        user_phone: s.user_phone,
        id: s._id,
      }));

      res.json(points);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  getTopZones: async (req, res) => {
    try {
      // Grid-based clustering: round to 2 decimal places (~1.1km grid)
      const data = await SOS.aggregate([
        { $match: { 'location.lat': { $ne: null }, 'location.lon': { $ne: null } } },
        {
          $group: {
            _id: {
              lat: { $round: [{ $toDouble: '$location.lat' }, 2] },
              lon: { $round: [{ $toDouble: '$location.lon' }, 2] },
            },
            count: { $sum: 1 },
            activeCount: { $sum: { $cond: [{ $eq: ['$status', 'active'] }, 1, 0] } },
            lastIncident: { $max: '$createdAt' },
          },
        },
        { $sort: { count: -1 } },
        { $limit: 20 },
      ]);

      res.json(
        data.map((d) => ({
          lat: d._id.lat,
          lon: d._id.lon,
          count: d.count,
          activeCount: d.activeCount,
          lastIncident: d.lastIncident,
          riskLevel: d.count >= 5 ? 'high' : d.count >= 3 ? 'medium' : 'low',
        }))
      );
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  getResponseTimeAnalytics: async (req, res) => {
    try {
      const data = await SOS.aggregate([
        { $match: { status: 'resolved' } },
        {
          $project: {
            createdAt: 1,
            updatedAt: 1,
            responseTimeMs: { $subtract: ['$updatedAt', '$createdAt'] },
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' },
            day: { $dayOfMonth: '$createdAt' }
          }
        },
        {
          $group: {
            _id: { year: '$year', month: '$month', day: '$day' },
            avgResponseTimeMs: { $avg: '$responseTimeMs' },
            count: { $sum: 1 }
          }
        },
        { $sort: { '_id.year': 1, '_id.month': 1, '_id.day': 1 } },
        { $limit: 30 }
      ]);
      
      const formatted = data.map(d => ({
        date: `${d._id.year}-${String(d._id.month).padStart(2, '0')}-${String(d._id.day).padStart(2, '0')}`,
        avgResponseTimeMinutes: Math.round(d.avgResponseTimeMs / (1000 * 60)),
        count: d.count
      }));
      
      res.json(formatted);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── Broadcast ──────────────────────────────────────────────────────────────
  sendBroadcast: async (req, res) => {
    try {
      const { title, message, severity } = req.body;
      const io = req.app.get('io');
      if (io) {
        io.emit('admin_broadcast', {
          title: title || 'Global Alert',
          message,
          severity: severity || 'high',
          timestamp: new Date().toISOString()
        });
        res.json({ success: true, message: 'Broadcast sent successfully' });
      } else {
        res.status(500).json({ error: 'Socket.io not initialized on server' });
      }
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── Community Reports ──────────────────────────────────────────────────────
  getAllCommunityReports: async (req, res) => {
    try {
      const { page = 1, limit = 50 } = req.query;
      const reports = await CommunityReport.find()
        .sort({ timestamp: -1, createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(Number(limit));
      const total = await CommunityReport.countDocuments();
      res.json({ reports, total, page: Number(page), totalPages: Math.ceil(total / limit) });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },

  // ─── Risk Zones (mirrors Flutter ZoneService logic) ────────────────────────
  getRiskZones: (req, res) => {
    try {
      // Read the asset file — path from backend/src/controllers → ../../../assets/risk_data.json
      const riskDataPath = path.join(__dirname, '..', '..', '..', 'assets', 'risk_data.json');
      const riskData = JSON.parse(fs.readFileSync(riskDataPath, 'utf8'));

      const currentHour = new Date().getHours();
      const hourMultipliers = riskData.hour_multipliers || {};
      const multiplier = parseFloat(hourMultipliers[String(currentHour)] ?? 0);

      const zones = riskData.zones.map((z, idx) => {
        const rawScore = z.base_score + multiplier;
        const riskScore = Math.min(100, Math.max(0, rawScore));

        let zoneType, zoneColor, zoneLabel;
        if (riskScore <= 25) {
          zoneType = 'safe';      zoneColor = '#43A047'; zoneLabel = 'Safe Zone';
        } else if (riskScore <= 50) {
          zoneType = 'moderate';  zoneColor = '#F39C12'; zoneLabel = 'Moderate Zone';
        } else if (riskScore <= 75) {
          zoneType = 'high';      zoneColor = '#E74C3C'; zoneLabel = 'High Risk Zone';
        } else {
          zoneType = 'critical';  zoneColor = '#8B0000'; zoneLabel = 'Critical Zone';
        }

        return {
          id: `zone_${idx}`,
          name: z.name,
          lat: z.lat,
          lon: z.lon,
          radius: 0.5,          // 500m — matches Flutter default
          baseScore: z.base_score,
          riskScore: Math.round(riskScore),
          zoneType,
          zoneColor,
          zoneLabel,
        };
      });

      res.json({ zones, currentHour, multiplier });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },
};

module.exports = adminController;
