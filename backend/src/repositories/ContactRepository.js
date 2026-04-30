const BaseRepository = require('./BaseRepository');
const Contact = require('../models/Contact');

class ContactRepository extends BaseRepository {
  constructor() {
    super(Contact);
  }

  async findByUser(userPhone, traceId = 'N/A') {
    return await this.find({ user_phone: userPhone }, {}, { sort: { isPrimary: -1, name: 1 } }, traceId);
  }

  async addContact(contactData, traceId = 'N/A') {
    return await this.create(contactData, traceId);
  }

  async removeContact(userPhone, contactPhone, traceId = 'N/A') {
    return await this.deleteOne({ user_phone: userPhone, phone: contactPhone }, traceId);
  }

  async setPrimary(userPhone, contactPhone, traceId = 'N/A') {
    return await this.withTransaction(async (session) => {
      // 1. Unset existing primary
      await this.model.updateMany(
        { user_phone: userPhone },
        { $set: { isPrimary: false } }
      ).session(session);

      // 2. Set new primary
      const updated = await this.model.findOneAndUpdate(
        { user_phone: userPhone, phone: contactPhone },
        { $set: { isPrimary: true } },
        { new: true }
      ).session(session);

      return updated;
    }, traceId);
  }
}

module.exports = new ContactRepository();
