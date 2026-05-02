const mongoose = require('mongoose');

// Create separate connection instances
const authConnection = mongoose.createConnection();
const dataConnection = mongoose.createConnection();

const connectDB = async () => {
  try {
    // Ultra-robust URI parser for Atlas (matches Flutter app exactly)
    const prepareUri = (uri) => {
      if (!uri) return uri;
      let injected = uri.trim();
      const dbName = (process.env.MONGO_DB_NAME || 'sheildai').trim();

      if (injected.startsWith('mongodb')) {
        const queryIndex = injected.indexOf('?');
        let basePart = queryIndex > -1 ? injected.substring(0, queryIndex) : injected;
        let queryPart = queryIndex > -1 ? injected.substring(queryIndex) : '';

        // Inject Database Name if missing
        if (!basePart.includes('.mongodb.net/')) {
          basePart = basePart.replace('.mongodb.net', `.mongodb.net/${dbName}`);
        } else if (basePart.endsWith('.mongodb.net/')) {
          basePart += dbName;
        }
        
        injected = basePart + queryPart;

        // Ensure authSource=admin is present for Atlas
        if (!injected.includes('authSource=')) {
          const sep = injected.includes('?') ? '&' : '?';
          injected = `${injected}${sep}authSource=admin`;
        }
      }
      return injected;
    };

    const dbName = (process.env.MONGO_DB_NAME || 'sheildai').trim();
    const authUri = prepareUri(process.env.MONGO_DB_AUTH_CONNECTION_STRING || process.env.MONGO_URI);
    const dataUri = prepareUri(process.env.MONGO_DB_DATA_CONNECTION_STRING || process.env.MONGO_URI);

    const mask = (uri) => uri ? uri.replace(/:([^@]+)@/, ':****@') : 'null';
    console.log(`[DB] Global DB Name: ${dbName}`);
    console.log(`[DB] AUTH URI: ${mask(authUri)}`);
    console.log(`[DB] DATA URI: ${mask(dataUri)}`);

    const options = {
      dbName: dbName,
      serverSelectionTimeoutMS: 10000,
    };

    // Connect AUTH
    try {
      await authConnection.openUri(authUri, options);
      console.log(`[DB] SUCCESS: AUTH Connected (${authConnection.host})`);
    } catch (err) {
      console.error(`[DB] FAILED: AUTH Connection Error: ${err.message}`);
    }

    // Connect DATA
    try {
      await dataConnection.openUri(dataUri, options);
      console.log(`[DB] SUCCESS: DATA Connected (${dataConnection.host})`);
    } catch (err) {
      console.error(`[DB] FAILED: DATA Connection Error: ${err.message}`);
    }
  } catch (error) {
    console.error(`[DB] Unexpected Error in connectDB: ${error.message}`);
  }
};

module.exports = {
  connectDB,
  authConnection,
  dataConnection
};
