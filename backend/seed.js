const dns = require('dns');
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (err) {
  // Fallback
}

require('dotenv').config();
const mongoose = require('mongoose');
const SOS = require('./src/models/SOS');
const User = require('./src/models/User');

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB.');

    // Clear existing SOS
    await SOS.deleteMany({});
    
    const statuses = ['active', 'resolved', 'false_alarm'];
    const locations = [
      { lat: 28.7041, lon: 77.1025 }, // Delhi
      { lat: 19.0760, lon: 72.8777 }, // Mumbai
      { lat: 12.9716, lon: 77.5946 }, // Bangalore
    ];
    
    const sosDocs = [];
    // Generate 150 SOS incidents over the last 30 days
    for(let i=0; i<150; i++) {
      const d = new Date();
      // Random day in the last 30 days
      d.setDate(d.getDate() - Math.floor(Math.random() * 30));
      
      sosDocs.push({
        user_phone: `99999${Math.floor(Math.random() * 90000) + 10000}`,
        location: locations[i % 3],
        status: statuses[Math.floor(Math.random() * 3)],
        message: 'Help needed! Seeded incident ' + i,
        createdAt: d
      });
    }
    
    await SOS.insertMany(sosDocs);
    console.log('✅ Successfully seeded 150 dummy SOS incidents for Analytics testing.');
    process.exit(0);
  } catch (error) {
    console.error('Error seeding data:', error);
    process.exit(1);
  }
}

seed();
