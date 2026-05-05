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

// Security Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10kb' }));

// Rate Limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests from this IP, please try again after 15 minutes'
});
app.use('/api', limiter);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/users', userRoutes);

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
    userLocations.set(socket.id, {
      phone: data.phone || phone,
      lat: data.lat,
      lon: data.lon,
      lastUpdate: Date.now()
    });
  });

  socket.on('sos_alert', (sosData) => {
    // sosData: { sosId, userId, name, latitude, longitude, message }
    console.log(`[Socket] SOS Alert from ${sosData.name} (${sosData.userId})`);
    
    // Broadcast to nearby users (5km)
    const radiusInKm = 5.0;
    
    userLocations.forEach((loc, socketId) => {
      if (socketId === socket.id) return; // Skip sender

      const distance = calculateDistance(
        sosData.latitude, 
        sosData.longitude, 
        loc.lat, 
        loc.lon
      );

      if (distance <= radiusInKm) {
        console.log(`[Socket] Sending Sentinel Alert to ${loc.phone} (Distance: ${distance.toFixed(2)}km)`);
        io.to(socketId).emit('sentinel_alert', {
          ...sosData,
          distance: distance
        });
      }
    });

    // Also broadcast to a general community feed for all
    socket.broadcast.emit('community_feed_update', {
      type: 'SOS',
      name: 'Someone', // Anonymous for feed
      latitude: sosData.latitude,
      longitude: sosData.longitude,
      message: 'Emergency SOS Triggered!',
      timestamp: new Date().toISOString()
    });
  });

  socket.on('community_report', (reportData) => {
    // reportData: { type, description, lat, lon, name }
    console.log(`[Socket] New Community Report: ${reportData.type}`);
    
    // Broadcast anonymously to all users
    const anonymousReport = {
      ...reportData,
      name: 'Anonymous Citizen',
      phone: undefined, // Hide phone
      timestamp: new Date().toISOString()
    };
    
    io.emit('new_community_report', anonymousReport);
  });

  socket.on('disconnect', () => {
    console.log(`[Socket] User disconnected: ${socket.id}`);
    userLocations.delete(socket.id);
  });
});

// Haversine formula for distance calculation
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the earth in km
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * 
    Math.sin(dLon/2) * Math.sin(dLon/2)
    ; 
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
  const d = R * c; 
  return d;
}

function deg2rad(deg) {
  return deg * (Math.PI/180);
}

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
});
