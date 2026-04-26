import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/services/hive_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/mongo_service.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase from google-services.json
  try {
    // We wrap this in a try-catch because if google-services.json is missing,
    // this will throw an error at runtime.
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization skipped or failed: $e");
    debugPrint("Ensure google-services.json is present for Firebase features.");
  }
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found or failed to load. Using defaults: $e");
  }
  
  // Initialize Hive for local storage
  await HiveService().initialize();

  // Pre-warm SharedPreferences so StorageService synchronous reads work
  // immediately in AuthProvider's constructor (session restore on cold start).
  await StorageService().init();
  
  // Initialize SyncService for offline queue
  await SyncService().initialize();

  // Initialize MongoDB connection (blocking to ensure readiness)
  final mongoService = MongoService();
  try {
    await mongoService.connect();
    debugPrint("MongoDB initialized successfully on startup");
  } catch (e) {
    debugPrint("MongoDB initialization failed: $e");
  }
  
  runApp(const App());
}
