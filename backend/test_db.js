const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const connectAndTest = async () => {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected Successfully!');

    const db = mongoose.connection.db;
    
    // Get all collections
    const collections = await db.listCollections().toArray();
    console.log('\n--- Database Collections ---');
    if (collections.length === 0) {
      console.log('No collections found. Database is empty.');
    } else {
      for (const col of collections) {
        const count = await db.collection(col.name).countDocuments();
        console.log(`- ${col.name}: ${count} documents`);
      }
    }
    
    console.log('\n--- Testing Database Operations ---');
    // Try to create a test user
    const testCollection = db.collection('test_logs');
    await testCollection.insertOne({ message: 'Database connection test', timestamp: new Date() });
    console.log('Successfully inserted a test log!');
    
    // Read the test log
    const log = await testCollection.findOne({ message: 'Database connection test' });
    console.log('Successfully read test log:', log.message);
    
    // Clean up test log
    await testCollection.deleteOne({ _id: log._id });
    console.log('Successfully deleted test log!');

  } catch (error) {
    console.error('Error during testing:', error);
  } finally {
    mongoose.connection.close();
    console.log('\nDatabase connection closed.');
  }
};

connectAndTest();
