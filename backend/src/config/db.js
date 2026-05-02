const mongoose = require('mongoose');

// Create separate connection instances
const authConnection = mongoose.createConnection();
const dataConnection = mongoose.createConnection();

const connectDB = async () => {
  try {
    const authUri = process.env.MONGO_DB_AUTH_CONNECTION_STRING || process.env.MONGO_URI;
    const dataUri = process.env.MONGO_DB_DATA_CONNECTION_STRING || process.env.MONGO_URI;

    // Helper to add authSource=admin if missing (same as Flutter app logic)
    const prepareUri = (uri) => {
      if (uri && uri.startsWith('mongodb+srv') && !uri.includes('authSource=')) {
        const sep = uri.includes('?') ? '&' : '?';
        return `${uri}${sep}authSource=admin`;
      }
      return uri;
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
