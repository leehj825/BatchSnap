import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.cleanCache(); // clean temp files from previous runs
  await AppState.instance.load();
  runApp(const BatchSnapApp());
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
