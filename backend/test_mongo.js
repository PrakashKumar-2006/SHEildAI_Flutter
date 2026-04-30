require('dotenv').config();
const mongoose = require('mongoose');
const userRepository = require('./src/repositories/UserRepository');
const sosRepository = require('./src/repositories/SOSRepository');
const logger = require('./src/utils/logger');
const crypto = require('crypto');

const testMongo = async () => {
  const traceId = 'TEST-' + crypto.randomInt(1000, 9999);
  try {
    const mongoUri = process.env.MONGO_URI;
    logger.info('Connecting to MongoDB for integration tests...', traceId);
    
    await mongoose.connect(mongoUri);
    logger.info('SUCCESS: Connected to MongoDB', traceId);

    const testPhone = `99999${crypto.randomInt(10000, 99999)}`;
    const testEmail = `test_${Date.now()}@example.com`;

    // 1. Test User Creation (Shadow User)
    logger.info(`Testing User Creation (Shadow)...`, traceId);
    const user = await userRepository.createUser({
      name: 'Test Persistent User',
      phone: testPhone,
      last_lat: 12.9716,
      last_lon: 77.5946
    }, traceId);
    
    if (user && user.phone === testPhone) {
      logger.info('SUCCESS: User created correctly', traceId);
    } else {
      throw new Error('User creation failed or data mismatch');
    }

    // 2. Test User Fetch
    logger.info(`Testing User Fetch...`, traceId);
    const fetchedUser = await userRepository.findByPhone(testPhone, traceId);
    if (fetchedUser && fetchedUser._id.toString() === user._id.toString()) {
      logger.info('SUCCESS: User fetched correctly', traceId);
    } else {
      throw new Error('User fetch failed');
    }

    // 3. Test Location Update
    logger.info(`Testing Location Update...`, traceId);
    const updatedUser = await userRepository.updateLastLocation(testPhone, 13.0, 78.0, traceId);
    if (updatedUser && updatedUser.last_lat === 13.0) {
      logger.info('SUCCESS: User location updated', traceId);
    } else {
      throw new Error('Location update failed');
    }

    // 4. Test SOS Creation
    logger.info(`Testing SOS Creation...`, traceId);
    const sos = await sosRepository.createSOS({
      user_phone: testPhone,
      location: {
        lat: 12.9716,
        lon: 77.5946
      },
      message: 'Integration Test SOS',
      status: 'active'
    }, traceId);
    
    if (sos && sos.user_phone === testPhone) {
      logger.info('SUCCESS: SOS created correctly', traceId);
    } else {
      throw new Error('SOS creation failed');
    }

    // 5. Test SOS Status Update
    logger.info(`Testing SOS Status Update...`, traceId);
    const updatedSos = await sosRepository.updateStatus(sos._id, 'resolved', traceId);
    if (updatedSos && updatedSos.status === 'resolved') {
      logger.info('SUCCESS: SOS status updated', traceId);
    } else {
      throw new Error('SOS update failed');
    }

    // 6. Test Contact Management
    logger.info(`Testing Contact Management...`, traceId);
    const contactRepository = require('./src/repositories/ContactRepository');
    
    // Add contact
    const contact = await contactRepository.addContact({
      user_phone: testPhone,
      name: 'Emergency Contact 1',
      phone: '1234567890',
      relationship: 'Family'
    }, traceId);
    logger.info('SUCCESS: Contact added', traceId);

    // Set primary
    const primaryContact = await contactRepository.setPrimary(testPhone, '1234567890', traceId);
    if (primaryContact && primaryContact.isPrimary) {
      logger.info('SUCCESS: Contact set as primary', traceId);
    }

    // Fetch contacts
    const contacts = await contactRepository.findByUser(testPhone, traceId);
    if (contacts.length > 0) {
      logger.info(`SUCCESS: Fetched ${contacts.length} contacts`, traceId);
    }

    // 7. Cleanup
    logger.info(`Cleaning up test data...`, traceId);
    await userRepository.deleteOne({ phone: testPhone }, traceId);
    await sosRepository.deleteOne({ _id: sos._id }, traceId);
    await contactRepository.deleteOne({ user_phone: testPhone }, traceId);
    logger.info('SUCCESS: Test data cleaned up', traceId);

    await mongoose.connection.close();
    logger.info('All MongoDB integration tests PASSED.', traceId);
    process.exit(0);
  } catch (error) {
    logger.error('FAILED: MongoDB integration tests failed', traceId, error);
    if (mongoose.connection) await mongoose.connection.close();
    process.exit(1);
  }
};

testMongo();
