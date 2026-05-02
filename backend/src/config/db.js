const mongoose = require('mongoose');

// Create separate connection instances
const authConnection = mongoose.createConnection();
const dataConnection = mongoose.createConnection();

const connectDB = async () => {
  try {
    const authUri = process.env.MONGO_DB_AUTH_CONNECTION_STRING || process.env.MONGO_URI;
    const dataUri = process.env.MONGO_DB_DATA_CONNECTION_STRING || process.env.MONGO_URI;

    // Helper to add DB name and authSource=admin if missing (matches Flutter logic)
    const prepareUri = (uri) => {
      if (!uri) return uri;
      let injected = uri;
      const dbName = process.env.MONGO_DB_NAME || 'sheildai';

      if (injected.startsWith('mongodb+srv')) {
        // 1. Inject Database Name if missing (e.g. cluster.mongodb.net/sheildai?...)
        if (!injected.includes('.mongodb.net/') && !injected.includes('.mongodb.net?')) {
          injected = injected.replace('.mongodb.net', `.mongodb.net/${dbName}`);
        } else if (injected.includes('.mongodb.net/?')) {
          injected = injected.replace('.mongodb.net/?', `.mongodb.net/${dbName}?`);
        }

        // 2. Ensure authSource=admin is present
        if (!injected.includes('authSource=')) {
          const sep = injected.includes('?') ? '&' : '?';
          injected = `${injected}${sep}authSource=admin`;
        }
      }
      return injected;
    };

    await Promise.all([
      authConnection.openUri(prepareUri(authUri)),
      dataConnection.openUri(prepareUri(dataUri))
    ]);

    console.log(`MongoDB AUTH Connected: ${authConnection.host}`);
    console.log(`MongoDB DATA Connected: ${dataConnection.host}`);
  } catch (error) {
    console.error(`Database Connection Error: ${error.message}`);
    // Don't exit process here, let the app handle it or retry
  }
};

module.exports = {
  connectDB,
  authConnection,
  dataConnection
};
