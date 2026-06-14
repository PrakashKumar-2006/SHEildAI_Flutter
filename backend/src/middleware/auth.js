const jwt = require('jsonwebtoken');
const User = require('../models/User');

const ADMIN_EMAILS = ['admin@sheildai.io'];

const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      token = req.headers.authorization.split(' ')[1];

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const userId = decoded.userId || decoded.id;

      if (!userId) {
        // Fallback for valid token carrying whitelisted email without a userId
        if (decoded.email && ADMIN_EMAILS.includes(decoded.email)) {
          req.user = {
            email: decoded.email,
            phone: decoded.phone || '',
            name: 'Admin User',
            role: 'admin'
          };
          return next();
        }
        return res.status(401).json({ message: 'Not authorized, invalid token payload' });
      }

      req.user = await User.findById(userId).select('-password');
      if (!req.user) {
        // Fallback if user document was deleted or not yet created but token contains whitelisted email
        if (decoded.email && ADMIN_EMAILS.includes(decoded.email)) {
          req.user = {
            email: decoded.email,
            phone: decoded.phone || '',
            name: 'Admin User',
            role: 'admin'
          };
          return next();
        }
        return res.status(401).json({ message: 'Not authorized, user not found' });
      }

      return next();
    } catch (error) {
      console.error('JWT Verification Error:', error.message);
      return res.status(401).json({ message: 'Not authorized, token failed' });
    }
  }

  if (!token) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }
};

const adminOnly = (req, res, next) => {
  if (req.user && (req.user.role === 'admin' || ADMIN_EMAILS.includes(req.user.email))) {
    return next();
  }

  return res.status(403).json({ message: 'Forbidden: Admin access required' });
};

module.exports = { protect, adminOnly };
