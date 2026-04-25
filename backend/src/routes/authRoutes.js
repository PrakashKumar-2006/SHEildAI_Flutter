const express = require('express');
const router = express.Router();
const { check, validationResult } = require('express-validator');
const { registerUser, loginUser, getUserProfile } = require('../controllers/authController');
const { protect } = require('../middleware/auth');

// Middleware to handle validation errors
const validateRequest = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

router.post('/register', [
  check('name', 'Name is required').not().isEmpty().trim().escape(),
  check('phone', 'Please include a valid phone number').isMobilePhone().withMessage('Invalid phone number format').trim().escape(),
  check('password', 'Please enter a password with 6 or more characters').isLength({ min: 6 })
], validateRequest, registerUser);

router.post('/login', [
  check('phone', 'Please include a valid phone number').isMobilePhone().withMessage('Invalid phone number format').trim().escape(),
  check('password', 'Password is required').exists()
], validateRequest, loginUser);

router.get('/profile', protect, getUserProfile);

module.exports = router;
