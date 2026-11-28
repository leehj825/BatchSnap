import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/app_state.dart';
import 'services/diagnostics.dart';
import 'theme.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError =
        (d) => Diagnostics.record('Flutter', d.exception, d.stack);
    PlatformDispatcher.instance.onError = (e, st) {
      Diagnostics.record('Platform', e, st);
      return true;
    };
    // The UI opens immediately; every startup step runs afterwards and a
    // failure is shown on the home screen instead of blocking or crashing.
    runApp(const BatchSnapApp());
    _bootstrap();
  }, (e, st) => Diagnostics.record('Uncaught', e, st));
}

Future<void> _bootstrap() async {
  try {
    await AppState.cleanCache(); // clean temp files from previous runs
  } catch (e, st) {
    Diagnostics.record('Cache cleanup', e, st);
  }
  try {
    await AppState.instance.load();
  } catch (e, st) {
    Diagnostics.record('Loading saved data', e, st);
  }
  // Ads start only after the UI is up, so a failing ads SDK can't block launch.
  await Future<void>.delayed(const Duration(seconds: 1));
  await AdsService.init();
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
