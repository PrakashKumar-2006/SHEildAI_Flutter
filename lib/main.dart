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
  
  // Initialize SyncService for offline queue
  await SyncService().initialize();

  // Pre-connect to MongoDB to verify connectivity (non-blocking)
  final mongoService = MongoService();
  mongoService.connect().then((_) {
    debugPrint("MongoDB initialized successfully on startup");
  }).catchError((e) {
    debugPrint("MongoDB initialization failed: $e");
  });
  
  runApp(const App());
}
