const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const dotenv = require('dotenv');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { connectDB } = require('./config/db');

const authRoutes = require('./routes/authRoutes');
const sosRoutes = require('./routes/sosRoutes');
const contactRoutes = require('./routes/contactRoutes');
const userRoutes = require('./routes/userRoutes');
const adminRoutes = require('./routes/adminRoutes');

// Load env vars
dotenv.config();

// Connect to database
connectDB();

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

io.on('connection', (socket) => {
  const phone = socket.handshake.query.phone;
  console.log(`[Socket] User connected: ${phone} (${socket.id})`);

  socket.on('update_location', (data) => {
    // data: { lat, lon, phone }
    if (data.lat && data.lon) {
      userLocations.set(socket.id, {
        phone: data.phone || phone || 'Unknown',
        lat: parseFloat(data.lat),
        lon: parseFloat(data.lon),
        lastUpdate: Date.now()
      });
      // console.log(`[Socket] Location updated for ${data.phone || phone}`);
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
