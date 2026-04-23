import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/hive_service.dart';
import 'core/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await HiveService().initialize();
  
  // Initialize SyncService for offline queue
  await SyncService().initialize();
  
  runApp(const App());
}
