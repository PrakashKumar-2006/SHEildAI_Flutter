const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const dotenv = require('dotenv');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { connectDB } = require('./config/db');

const authRoutes = require('./routes/authRoutes');
const sosRoutes = require('./routes/sosRoutes');
const contactRoutes = require('./routes/contactRoutes');
const userRoutes = require('./routes/userRoutes');
const adminRoutes = require('./routes/adminRoutes');
const userRepository = require('./repositories/UserRepository');

// Load env vars from the root .env, overriding stale dashboard variables
dotenv.config({ path: path.join(__dirname, '../../.env'), override: true });

// Startup Configuration Validation
const fs = require('fs');
if (!process.env.MONGO_URI) {
  console.error('==================================================');
  console.error('           FATAL CONFIGURATION ERROR              ');
  console.error('==================================================');
  console.error('MONGO_URI is not configured');
  console.error('Server startup aborted.');
  console.error('==================================================');
  process.exit(1);
}

if (!process.env.JWT_SECRET) {
  console.error('==================================================');
  console.error('           FATAL CONFIGURATION ERROR              ');
  console.error('==================================================');
  console.error('JWT_SECRET is not configured');
  console.error('Server startup aborted.');
  console.error('==================================================');
  process.exit(1);
}

if (process.env.JWT_SECRET.length < 32) {
  console.error('==================================================');
  console.error('           FATAL CONFIGURATION ERROR              ');
  console.error('==================================================');
  console.error('JWT_SECRET must be at least 32 characters');
  console.error('Server startup aborted.');
  console.error('==================================================');
  process.exit(1);
}

let hasFirebaseConfig = false;
if (process.env.FIREBASE_CONFIG) {
  hasFirebaseConfig = true;
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  if (fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
    hasFirebaseConfig = true;
  }
}

if (!hasFirebaseConfig) {
  console.error('==================================================');
  console.error('           FATAL CONFIGURATION ERROR              ');
  console.error('==================================================');
  console.error('Firebase credentials not configured');
  console.error('Server startup aborted.');
  console.error('==================================================');
  process.exit(1);
}

// Connect to database
connectDB();

// Initialize Firebase Admin SDK
const admin = require('firebase-admin');
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'sheild-flutter'
  });
}

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Attach socket.io instance to the app so controllers can use it
app.set('io', io);

// Security Middleware
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:5173', '*'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-trace-id'],
}));
app.use(express.json({ limit: '10kb' }));

// Rate Limiting (Increased for admin dashboard polling)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5000,
  max: 5000,
  message: 'Too many requests from this IP, please try again after 15 minutes'
});
// app.use('/api', limiter); // Disabled for development/dashboard polling

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/users', userRoutes);
app.use('/api/admin', adminRoutes);

// Root route
app.get('/', (req, res) => {
  res.send('SHEildAI Backend API with Real-time Sockets is running...');
});

// --- Real-time Socket Logic ---
const userLocations = new Map(); // socketId -> { phone, lat, lon }

function normalizeLiveLocation(data = {}, fallbackPhone) {
  const lat = Number(data.lat ?? data.latitude);
  const lon = Number(data.lon ?? data.lng ?? data.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const phone = data.phone || data.user_id || fallbackPhone || 'Unknown';
  return {
    phone,
    name: data.name || 'User',
    lat,
    lon,
    lastUpdate: Date.now(),
  };
}

io.on('connection', (socket) => {
  const phone = socket.handshake.query.phone;
  console.log(`[Socket] User connected: ${phone} (${socket.id})`);

  socket.on('update_location', async (data) => {
    // data: { lat, lon, phone }
    const location = normalizeLiveLocation(data, phone);
    if (!location) return;

    userLocations.set(socket.id, location);

    io.emit('user_location_updated', {
      phone: location.phone,
      name: location.name,
      lat: location.lat,
      lon: location.lon,
      lastSeen: new Date(location.lastUpdate).toISOString(),
      socketId: socket.id
    });

    if (location.phone && location.phone !== 'Unknown') {
      try {
        const existing = await userRepository.findByPhone(location.phone);
        if (existing) {
          await userRepository.updateLastLocation(location.phone, location.lat, location.lon);
        } else {
          await userRepository.createUser({
            phone: location.phone,
            name: location.name,
            last_lat: location.lat,
            last_lon: location.lon,
            last_seen: new Date(location.lastUpdate)
          });
        }
      } catch (err) {
        console.error('[Socket] Failed to persist live location:', err.message);
      }
    }
  });

  socket.on('sos_alert', (sosData) => {
    // sosData: { sosId, userId, name, latitude, longitude, message }
    console.log(`[Socket] SOS ALERT RECEIVED from ${sosData.name} (${sosData.userId}) at [${sosData.latitude}, ${sosData.longitude}]`);
    
    // Broadcast to nearby users (5km)
    const radiusInKm = 5.0;
    let nearbyCount = 0;
    
    userLocations.forEach((loc, socketId) => {
      if (socketId === socket.id) return; // Skip sender
      if (!loc.lat || !loc.lon) return; // Skip if no location

      const distance = calculateDistance(
        sosData.latitude, 
        sosData.longitude, 
        loc.lat, 
        loc.lon
      );

      if (!isNaN(distance) && distance <= radiusInKm) {
        nearbyCount++;
        console.log(`[Socket] Sending Sentinel Alert to ${loc.phone} (Distance: ${distance.toFixed(2)}km)`);
        io.to(socketId).emit('sentinel_alert', {
          ...sosData,
          distance: distance
        });
      }
    });

    console.log(`[Socket] SOS Alert processed. Sent to ${nearbyCount} nearby users out of ${userLocations.size} total active users.`);

    // Also broadcast to a general community feed for all
    socket.broadcast.emit('community_feed_update', {
      type: 'SOS',
      name: 'Someone', // Anonymous for feed
      latitude: sosData.latitude,
      longitude: sosData.longitude,
      message: 'Emergency SOS Triggered Nearby!',
      timestamp: new Date().toISOString()
    });
  });

  socket.on('community_report', (reportData) => {
    // reportData: { type, description, lat, lon, name }
    console.log(`[Socket] New Community Report: ${reportData.incidentType || reportData.type} at [${reportData.latitude || reportData.lat}, ${reportData.longitude || reportData.lon}]`);
    
    // Broadcast anonymously to all users
    const anonymousReport = {
      ...reportData,
      name: 'Anonymous Citizen',
      phone: undefined, // Hide phone
      timestamp: new Date().toISOString()
    };
    
    // Emit both for backward/forward compatibility
    io.emit('new_community_report', anonymousReport);
    io.emit('community_report_broadcast', anonymousReport);
  });

  socket.on('disconnect', () => {
    console.log(`[Socket] User disconnected: ${socket.id}`);
    userLocations.delete(socket.id);
  });
});

// Haversine formula for distance calculation
function calculateDistance(lat1, lon1, lat2, lon2) {
  try {
    const R = 6371; // Radius of the earth in km
    const pLat1 = parseFloat(lat1);
    const pLon1 = parseFloat(lon1);
    const pLat2 = parseFloat(lat2);
    const pLon2 = parseFloat(lon2);

    if (isNaN(pLat1) || isNaN(pLon1) || isNaN(pLat2) || isNaN(pLon2)) return NaN;

    const dLat = deg2rad(pLat2 - pLat1);
    const dLon = deg2rad(pLon2 - pLon1);
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(deg2rad(pLat1)) * Math.cos(deg2rad(pLat2)) * 
      Math.sin(dLon/2) * Math.sin(dLon/2)
      ; 
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
    const d = R * c; 
    return d;
  } catch (e) {
    return NaN;
  }
}

function deg2rad(deg) {
  return deg * (Math.PI/180);
}

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
});
