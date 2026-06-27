const authController = require('./src/controllers/authController');
const userRepository = require('./src/repositories/UserRepository');

async function runMockTest() {
  console.log('--- Runtime Verification ---');
  let createdUsers = [];
  userRepository.create = async (data) => {
    createdUsers.push(data);
    return { _id: 'mongo_id', ...data };
  };

  userRepository.findByFirebaseUid = async () => null;
  userRepository.findByPhone = async () => null;
  userRepository.findByEmail = async () => null;

  console.log('\n1. Test Create user with shadow_ phone');
  await userRepository.createUser({
    firebase_uid: 'uid1',
    phone: 'shadow_123',
    email: '',
    name: 'Test 1'
  });
  console.log('User 1 created data:', createdUsers[createdUsers.length - 1]);

  console.log('\n2. Test Create user with email in phone');
  await userRepository.createUser({
    firebase_uid: 'uid2',
    phone: 'test@example.com',
    email: 'test@example.com',
    name: 'Test 2'
  });
  console.log('User 2 created data:', createdUsers[createdUsers.length - 1]);
}

runMockTest().catch(console.error);
