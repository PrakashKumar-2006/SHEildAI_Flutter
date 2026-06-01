const BaseRepository = require('./BaseRepository');
const User = require('../models/User');

class UserRepository extends BaseRepository {
  constructor() {
    super(User);
  }

  async findByEmail(email, traceId = 'N/A') {
    return await this.findOne({ email }, {}, {}, traceId);
  }

  async findByFirebaseUid(firebaseUid, traceId = 'N/A') {
    return await this.findOne({ firebase_uid: firebaseUid }, {}, {}, traceId);
  }

  async findByPhone(phone, traceId = 'N/A') {
    return await this.findOne({ phone }, {}, {}, traceId);
  }

  async updateLastLocation(phone, lat, lon, traceId = 'N/A') {
    return await this.updateOne(
      { phone },
      { 
        $set: { 
          last_lat: lat, 
          last_lon: lon, 
          last_seen: new Date() 
        } 
      },
      { new: true },
      traceId
    );
  }

  async createUser(userData, traceId = 'N/A') {
    return await this.create(userData, traceId);
  }
}

module.exports = new UserRepository();
