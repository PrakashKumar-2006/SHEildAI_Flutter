const mongoose = require('mongoose');
const DatabaseError = require('../middleware/DatabaseError');
const logger = require('../utils/logger');

class BaseRepository {
  constructor(model) {
    this.model = model;
  }

  /**
   * Wrapper for database operations with retry logic and error handling
   */
  async execute(operation, traceId = 'N/A', options = { retries: 3, delay: 500 }) {
    let lastError;
    for (let i = 0; i < options.retries; i++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        // Retry only on transient errors (e.g., connection issues)
        if (this.isTransientError(error)) {
          logger.warn(`Transient error detected, retrying (${i + 1}/${options.retries})...`, traceId, { error: error.message });
          await new Promise(resolve => setTimeout(resolve, options.delay * (i + 1)));
          continue;
        }
        break;
      }
    }
    
    logger.error(`Database operation failed for ${this.model.modelName}`, traceId, lastError);
    throw new DatabaseError(`Failed to execute operation on ${this.model.modelName}`, lastError, traceId);
  }

  isTransientError(error) {
    const transientErrors = ['MongoNetworkError', 'MongoTimeoutError', 'MongoServerSelectionError'];
    return transientErrors.includes(error.name) || (error.message && error.message.includes('connection'));
  }

  async findOne(query, projection = {}, options = {}, traceId = 'N/A') {
    return await this.execute(async () => {
      return await this.model.findOne(query, projection, options).lean();
    }, traceId);
  }

  async find(query, projection = {}, options = {}, traceId = 'N/A') {
    return await this.execute(async () => {
      return await this.model.find(query, projection, options).lean();
    }, traceId);
  }

  async create(data, traceId = 'N/A') {
    return await this.execute(async () => {
      const entity = new this.model(data);
      const saved = await entity.save();
      logger.info(`Created ${this.model.modelName} document: ${saved._id}`, traceId);
      return saved;
    }, traceId);
  }

  async updateOne(query, update, options = { new: true }, traceId = 'N/A') {
    return await this.execute(async () => {
      const updated = await this.model.findOneAndUpdate(query, update, options).lean();
      if (updated) {
        logger.info(`Updated ${this.model.modelName} document`, traceId);
      } else {
        logger.warn(`No ${this.model.modelName} document found to update`, traceId, { query });
      }
      return updated;
    }, traceId);
  }

  async deleteOne(query, traceId = 'N/A') {
    return await this.execute(async () => {
      const result = await this.model.deleteOne(query);
      logger.info(`Deleted ${this.model.modelName} document. Count: ${result.deletedCount}`, traceId);
      return result;
    }, traceId);
  }

  async exists(query, traceId = 'N/A') {
    return await this.execute(async () => {
      return await this.model.exists(query);
    }, traceId);
  }

  /**
   * Helper for multi-document operations that require a transaction
   */
  async withTransaction(work, traceId = 'N/A') {
    const session = await mongoose.startSession();
    session.startTransaction();
    try {
      const result = await work(session);
      await session.commitTransaction();
      return result;
    } catch (error) {
      await session.abortTransaction();
      logger.error('Transaction aborted due to error', traceId, error);
      throw new DatabaseError('Transaction failed', error, traceId);
    } finally {
      session.endSession();
    }
  }
}

module.exports = BaseRepository;
