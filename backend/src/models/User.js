const mongoose = require('mongoose');
const { authConnection } = require('../config/db');
const bcrypt = require('bcrypt');

const userSchema = new mongoose.Schema({
  phone: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  email: {
    type: String,
    unique: true,
    sparse: true // Allows multiple null values
  },
  password: {
    type: String,
    required: function() {
      // Password only required if they are setting it (full registration)
      return this.isNew && this.password;
    }
  },
  name: {
    type: String,
    required: true,
    default: 'User'
  },
  last_lat: {
    type: Number,
    default: null
  },
  last_lon: {
    type: Number,
    default: null
  },
  last_seen: {
    type: Date,
    default: Date.now
  },
  profile: {
    type: Object,
    default: {}
  }
}, { timestamps: true });

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password') || !this.password) return next();
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Compare password
userSchema.methods.matchPassword = async function(enteredPassword) {
  if (!this.password) return false;
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = authConnection.model('User', userSchema);
