import 'package:flutter/foundation.dart';

/// Collects startup / runtime problems so the app can show them on screen
/// instead of silently failing or crashing.
class Diagnostics {
  Diagnostics._();

  static final problems = ValueNotifier<List<String>>([]);

  static void record(String where, Object error, [StackTrace? stack]) {
    debugPrint('[$where] $error${stack == null ? '' : '\n$stack'}');
    final first = stack?.toString().split('\n').take(3).join('\n');
    final line = '[$where] $error${first == null ? '' : '\n$first'}';
    problems.value = [...problems.value, line];
  }

  static void clear() => problems.value = [];
}
