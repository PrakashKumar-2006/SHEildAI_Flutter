const BaseRepository = require('./BaseRepository');
const SOS = require('../models/SOS');

class SOSRepository extends BaseRepository {
  constructor() {
    super(SOS);
  }

  async findActiveSOSByUser(phone, traceId = 'N/A') {
    return await this.findOne({ user_phone: phone, status: 'active' }, {}, {}, traceId);
  }

  async getUserHistory(phone, traceId = 'N/A') {
    return await this.find(
      { user_phone: phone },
      {},
      { sort: { createdAt: -1 }, limit: 50 },
      traceId
    );
  }

  async updateStatus(sosId, status, traceId = 'N/A') {
    return await this.updateOne(
      { _id: sosId },
      { $set: { status } },
      { new: true },
      traceId
    );
  }

  async createSOS(sosData, traceId = 'N/A') {
    return await this.create(sosData, traceId);
  }
}

module.exports = new SOSRepository();
