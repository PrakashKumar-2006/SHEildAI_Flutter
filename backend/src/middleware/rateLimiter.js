const rateLimit = require('express-rate-limit');

// Custom key generator that limits by authenticated user ID if logged in, otherwise falls back to client IP.
const keyGenerator = (req) => {
  return req.user ? req.user._id.toString() : req.ip;
};

// 1. Authentication Limiter (Auth token retrieval, login/register stubs)
const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes window
  max: 5,                  // Max 5 attempts
  message: { error: 'Too many authentication attempts. Please try again after 5 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// 2. Location Synchronization Limiter
const locationLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes window
  max: 20,                  // Max 20 sync requests (allows 2 per minute)
  keyGenerator: keyGenerator,
  message: { error: 'Too many location updates. Please wait a moment.' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: { default: false }
});

// 3. Profiles Lookup Limiter
const profileLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes window
  max: 30,                  // Max 30 requests (prevents rapid profile scraping)
  keyGenerator: keyGenerator,
  message: { error: 'Too many profile requests. Please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: { default: false }
});

// 4. Contacts CRUD Limiter
const contactLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes window
  max: 30,                  // Max 30 operations
  keyGenerator: keyGenerator,
  message: { error: 'Too many contact requests. Please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: { default: false }
});

// 5. Admin Dashboard APIs Limiter
const adminLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes window
  max: 120,                 // Generous limit to support admin polling
  keyGenerator: keyGenerator,
  message: { error: 'Too many admin dashboard requests. Access temporarily restricted.' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: { default: false }
});

// 6. SOS Alerting Limiter (Critical Emergency Route)
const sosLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes window
  max: 20,                 // High limit to ensure a real human in panic never gets blocked by retries
  keyGenerator: keyGenerator,
  message: { error: 'Too many SOS requests. Please contact emergency services directly if you are in immediate danger.' },
  standardHeaders: true,
  legacyHeaders: false,
  validate: { default: false },
  handler: (req, res, next, options) => {
    console.warn(`[WARNING] SOS rate limit exceeded by user/IP: ${keyGenerator(req)}`);
    res.status(options.statusCode).json(options.message);
  }
});

module.exports = {
  authLimiter,
  locationLimiter,
  profileLimiter,
  contactLimiter,
  adminLimiter,
  sosLimiter
};
