const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const connectDB = require('./config/db');

const authRoutes = require('./routes/authRoutes');
const sosRoutes = require('./routes/sosRoutes');

// Load env vars
dotenv.config();

// Connect to database
connectDB();

const app = express();

// Security Middleware
app.use(helmet());
app.use(cors()); // In production, configure this to only allow specific origins
app.use(express.json({ limit: '10kb' })); // Limit body size to prevent payload too large attacks

// Rate Limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per `window` (here, per 15 minutes)
  message: 'Too many requests from this IP, please try again after 15 minutes'
});
// Apply the rate limiting middleware to all requests
app.use(limiter);

// Prevent NoSQL injection by adding express-mongo-sanitize if we had it, but for now we rely on validation.

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/sos', sosRoutes);

// Root route
app.get('/', (req, res) => {
  res.send('SHEildAI Backend API is running...');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
});
