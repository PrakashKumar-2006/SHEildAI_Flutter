class DatabaseError extends Error {
  constructor(message, originalError = null, traceId = 'N/A') {
    super(message);
    this.name = 'DatabaseError';
    this.originalError = originalError;
    this.traceId = traceId;
    this.timestamp = new Date();
  }
}

module.exports = DatabaseError;
