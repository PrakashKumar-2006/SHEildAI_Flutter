const mongoose = require('mongoose');
const userRepository = require('./src/repositories/UserRepository');
const sosRepository = require('./src/repositories/SOSRepository');
const authController = require('./src/controllers/authController');

async function runTest() {
  await mongoose.connect('mongodb://127.0.0.1:27017/sheild_ai_test', {
    useNewUrlParser: true,
    useUnifiedTopology: true
  });
  
  // Clear collections
  await mongoose.connection.db.dropDatabase();

  console.log('--- Test 1: Create user with invalid phone (should sanitize) ---');
  let user1 = await userRepository.createUser({
    firebase_uid: 'uid123',
    phone: 'shadow_12345',
    email: 'test@example.com',
    name: 'Test User'
  });
  console.log('User created:', user1);

  console.log('\n--- Test 2: Create user with email in phone (should sanitize) ---');
  let user2 = await userRepository.createUser({
    firebase_uid: 'uid456',
    phone: 'user@example.com',
    email: 'user@example.com',
    name: 'User 2'
  });
  console.log('User 2 created:', user2);
  
  console.log('\n--- Test 3: Location update for valid phone ---');
  let user3 = await userRepository.createUser({
    firebase_uid: 'uid789',
    phone: '+1234567890',
    email: '',
    name: 'Real Phone User'
  });
  const req = {
    headers: {},
    body: { user_id: '+1234567890', latitude: 10, longitude: 20 },
    user: { phone: '+1234567890' },
    app: { get: () => null }
  };
  const res = {
    status: (code) => { console.log('Status:', code); return res; },
    json: (data) => { console.log('Response:', data); return res; }
  };
  await authController.updateLocation(req, res);

  console.log('\n--- Checking DB users collection ---');
  const allUsers = await mongoose.connection.db.collection('users').find().toArray();
  console.log(JSON.stringify(allUsers, null, 2));

  console.log('\n--- Disconnecting ---');
  await mongoose.disconnect();
}

runTest().catch(console.error);
