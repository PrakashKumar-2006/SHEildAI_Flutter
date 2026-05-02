const mongoose = require('mongoose');

// Create separate connection instances
const authConnection = mongoose.createConnection();
const dataConnection = mongoose.createConnection();

const connectDB = async () => {
  try {
    // Aggressive URI parser to fix Atlas connection strings (matches Flutter logic)
    const prepareUri = (uri) => {
      if (!uri) return uri;
      let injected = uri.trim();
      const dbName = (process.env.MONGO_DB_NAME || 'sheildai').trim();

      if (injected.startsWith('mongodb+srv')) {
        const queryIndex = injected.indexOf('?');
        let basePart = queryIndex > -1 ? injected.substring(0, queryIndex) : injected;
        let queryPart = queryIndex > -1 ? injected.substring(queryIndex) : '';

        // If basePart doesn't end with /dbName, add it
        if (!basePart.includes('.mongodb.net/')) {
          basePart = basePart.replace('.mongodb.net', `.mongodb.net/${dbName}`);
        } else {
          // Check if it ends in just /
          if (basePart.endsWith('.mongodb.net/')) {
            basePart += dbName;
          }
        }
        
        injected = basePart + queryPart;

        // Ensure authSource=admin is present
        if (!injected.includes('authSource=')) {
          const sep = injected.includes('?') ? '&' : '?';
          injected = `${injected}${sep}authSource=admin`;
        }
      }
      return injected;
    };

    const authUri = prepareUri(process.env.MONGO_DB_AUTH_CONNECTION_STRING || process.env.MONGO_URI);
    const dataUri = prepareUri(process.env.MONGO_DB_DATA_CONNECTION_STRING || process.env.MONGO_URI);
    const dbName = process.env.MONGO_DB_NAME || 'sheildai';

    const mask = (uri) => uri ? uri.replace(/:([^@]+)@/, ':****@') : 'null';
    console.log(`[DB] Attempting AUTH connection to: ${mask(authUri)}`);
    console.log(`[DB] Attempting DATA connection to: ${mask(dataUri)}`);

    const options = {
      dbName: dbName,
      serverSelectionTimeoutMS: 5000,
    };

    await Promise.all([
      authConnection.openUri(authUri, options).then(() => console.log(`MongoDB AUTH Connected: ${authConnection.host}`)),
      dataConnection.openUri(dataUri, options).then(() => console.log(`MongoDB DATA Connected: ${dataConnection.host}`))
    ]);
  } catch (error) {
    console.error(`[DB] Connection Critical Error: ${error.message}`);
  }
};

module.exports = {
  connectDB,
  authConnection,
  dataConnection
};
