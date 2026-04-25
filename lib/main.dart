import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/services/hive_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/mongo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase from google-services.json
  await Firebase.initializeApp();
  
  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");
  
  // Initialize Hive for local storage
  await HiveService().initialize();
  
  // Initialize SyncService for offline queue
  await SyncService().initialize();

  // Pre-connect to MongoDB to verify connectivity
  try {
    final mongoService = MongoService();
    await mongoService.connect();
    debugPrint("MongoDB initialized successfully on startup");
  } catch (e) {
    debugPrint("MongoDB initialization failed: $e");
  }
  
  runApp(const App());
}
