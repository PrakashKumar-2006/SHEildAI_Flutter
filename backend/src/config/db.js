const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const mongoUri = process.env.MONGO_URI || process.env.MONGO_DB_AUTH_CONNECTION_STRING;
    const dbName = process.env.MONGO_DB_NAME || 'sheildai';

    if (!mongoUri) {
      throw new Error('MONGO_URI is not defined in environment variables');
    }

    // Prepare URI with DB name and authSource=admin
    let injected = mongoUri.trim();
    if (injected.startsWith('mongodb')) {
      const queryIndex = injected.indexOf('?');
      let basePart = queryIndex > -1 ? injected.substring(0, queryIndex) : injected;
      let queryPart = queryIndex > -1 ? injected.substring(queryIndex) : '';

      if (!basePart.includes('.mongodb.net/')) {
        basePart = basePart.replace('.mongodb.net', `.mongodb.net/${dbName}`);
      } else if (basePart.endsWith('.mongodb.net/')) {
        basePart += dbName;
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
    
    // Set up global connection reference for models to use
    module.exports.authConnection = mongoose.connection;
    module.exports.dataConnection = mongoose.connection;

  } catch (error) {
    console.error(`[DB] Connection Critical Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = {
  connectDB,
  // These will be initialized after connectDB runs
  authConnection: null,
  dataConnection: null
};
