import 'package:flutter/material.dart';
import 'config/app_constants.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class QuestUpApp extends StatelessWidget {
  const QuestUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
