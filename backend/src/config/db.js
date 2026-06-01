const mongoose = require('mongoose');
const dns = require('dns');
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (err) {
  // Fallback
}

const connectDB = async () => {
  try {
    let mongoUri = process.env.MONGO_URI;
    const dbName = process.env.MONGO_DB_NAME || 'sheild_ai_flutter';

    if (!mongoUri) {
      throw new Error('MONGO_URI is not defined in environment variables');
    }

    // Safely parse and URL-encode credentials if there are special characters (like unencoded '@' in password)
    let injected = mongoUri.trim();
    if (injected.startsWith('mongodb')) {
      const schemeIndex = injected.indexOf('://');
      if (schemeIndex > -1) {
        const scheme = injected.substring(0, schemeIndex + 3);
        const rest = injected.substring(schemeIndex + 3);

        const queryIndex = rest.indexOf('?');
        const mainPart = queryIndex > -1 ? rest.substring(0, queryIndex) : rest;
        const queryPart = queryIndex > -1 ? rest.substring(queryIndex) : '';

        const lastAt = mainPart.lastIndexOf('@');
        if (lastAt > -1) {
          const credsPart = mainPart.substring(0, lastAt);
          let hostAndDb = mainPart.substring(lastAt + 1);

          // Standardize DB name injection
          if (hostAndDb.endsWith('/')) {
            hostAndDb = `${hostAndDb}${dbName}`;
          } else if (!hostAndDb.includes('/')) {
            hostAndDb = `${hostAndDb}/${dbName}`;
          } else {
            const parts = hostAndDb.split('/');
            parts[parts.length - 1] = dbName;
            hostAndDb = parts.join('/');
          }

          // Encode username and password
          const colonIndex = credsPart.indexOf(':');
          if (colonIndex > -1) {
            const user = credsPart.substring(0, colonIndex);
            const pass = credsPart.substring(colonIndex + 1);
            const safeUser = encodeURIComponent(decodeURIComponent(user));
            const safePass = encodeURIComponent(decodeURIComponent(pass));
            injected = `${scheme}${safeUser}:${safePass}@${hostAndDb}${queryPart}`;
          } else {
            const safeUser = encodeURIComponent(decodeURIComponent(credsPart));
            injected = `${scheme}${safeUser}@${hostAndDb}${queryPart}`;
          }
        }
      }

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
