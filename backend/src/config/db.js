const mongoose = require('mongoose');
const dns = require('dns');
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (err) {
  // Fallback
}

const connectDB = async () => {
  try {
    const mongoUri = process.env.MONGO_URI;
    const dbName = process.env.MONGO_DB_NAME || 'sheild_ai_flutter';

    if (!mongoUri) {
      throw new Error('MONGO_URI is not defined in environment variables');
    }

    // Prepare URI with DB name and authSource=admin
    let injected = mongoUri.trim();
    if (injected.startsWith('mongodb')) {
      const queryIndex = injected.indexOf('?');
      let basePart = queryIndex > -1 ? injected.substring(0, queryIndex) : injected;
      let queryPart = queryIndex > -1 ? injected.substring(queryIndex) : '';

      // Inject Database Name if missing
      if (!basePart.includes('.mongodb.net/')) {
        basePart = basePart.replace('.mongodb.net', `.mongodb.net/${dbName}`);
      } else {
        // Handle cases where it might end in / or have a different DB name
        const lastSlash = basePart.lastIndexOf('/');
        const hostPart = basePart.substring(0, lastSlash);
        basePart = `${hostPart}/${dbName}`;
      }
      
      injected = basePart + queryPart;

      if (!injected.includes('authSource=')) {
        const sep = injected.includes('?') ? '&' : '?';
        injected = `${injected}${sep}authSource=admin`;
      }
    }

    const mask = (uri) => uri ? uri.replace(/:([^@]+)@/, ':****@') : 'null';
    console.log(`[DB] Attempting unified connection to: ${mask(injected)}`);

    const options = {
      dbName: dbName,
      serverSelectionTimeoutMS: 10000,
    };

    await mongoose.connect(injected, options);
    console.log(`[DB] SUCCESS: Unified MongoDB Connected to ${mongoose.connection.host}`);
    
    // Explicitly set the database for the connection
    console.log(`[DB] Active Database: ${mongoose.connection.name}`);

  } catch (error) {
    console.error(`[DB] Connection Critical Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = {
  connectDB
};
