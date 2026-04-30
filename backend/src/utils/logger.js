const logger = {
  info: (message, traceId = 'N/A', data = {}) => {
    console.log(`[${new Date().toISOString()}][INFO][${traceId}] ${message}`, Object.keys(data).length ? data : '');
  },
  error: (message, traceId = 'N/A', error = null) => {
    console.error(`[${new Date().toISOString()}][ERROR][${traceId}] ${message}`, error || '');
  },
  warn: (message, traceId = 'N/A', data = {}) => {
    console.warn(`[${new Date().toISOString()}][WARN][${traceId}] ${message}`, data);
  },
  debug: (message, traceId = 'N/A', data = {}) => {
    if (process.env.NODE_ENV === 'development') {
      console.log(`[${new Date().toISOString()}][DEBUG][${traceId}] ${message}`, data);
    }
  }
};

module.exports = logger;
