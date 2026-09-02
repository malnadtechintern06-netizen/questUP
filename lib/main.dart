import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/mysql_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Connect to MySQL Database (asynchronously, with resilient offline fallback)
  try {
    MySqlDatabaseService.instance.connect().then((connected) {
      if (connected) {
        debugPrint('QuestUP connected to MySQL database.');
      } else {
        debugPrint('QuestUP operating with local fallback cache (MySQL offline).');
      }
    }).catchError((e) {
      debugPrint('MySQL initialization notice: $e');
    });
  } catch (e) {
    debugPrint('Database initialization notice: $e');
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
