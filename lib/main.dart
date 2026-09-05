import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/mysql_database_service.dart';
import 'core/services/notification_service.dart';
import 'features/sync/data/services/data_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native push & status-bar notification service
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[MAIN] NotificationService initialization notice: $e');
  }

  // Catch Flutter framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };

  // Catch platform & asynchronous errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught Asynchronous Error: $error');
    return true; // prevent app crash
  };

  // Connect to MySQL Database & Synchronize Local Data
  try {
    MySqlDatabaseService.instance.connect().then((connected) {
      if (connected) {
        debugPrint('[MySQL] QuestUP connected to MySQL database.');
        // Run automatic data migration & synchronization in background
        DataSyncService.instance.synchronizeLocalDataToMySql();
      } else {
        debugPrint('[MySQL] QuestUP operating with local cache (MySQL connection failed or offline).');
      }
    }).catchError((e) {
      debugPrint('[MySQL] MySQL initialization notice: $e');
    });
  } catch (e) {
    debugPrint('[MySQL] Database initialization notice: $e');
  }

  // Set system UI overlay style matching QuestUP dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: QuestUpApp(),
    ),
  );
}
