import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  // Anything that throws during startup is logged instead of killing the app.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await AppState.cleanCache(); // clean temp files from previous runs
      await AppState.instance.load();
    } catch (e, st) {
      debugPrint('Startup state load failed: $e\n$st');
    }
    runApp(const BatchSnapApp());
    // Ads start only after the first frame is on screen, so a slow or failing
    // ads SDK can never block or crash app launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 1), AdsService.init);
    });
  }, (e, st) => debugPrint('Uncaught error: $e\n$st'));
}

class BatchSnapApp extends StatelessWidget {
  const BatchSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BatchSnap',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
