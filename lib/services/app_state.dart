import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'diagnostics.dart';

/// Pro status and conversion history. A ChangeNotifier singleton to keep dependencies minimal.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  static const freeBatchLimit = 10;
  static const _proKey = 'is_pro';
  static const _historyKey = 'history';
  static const _maxHistory = 30;

  bool isPro = false;

  /// Granted by watching a rewarded ad; lasts for one batch only.
  bool tempUnlocked = false;

  /// Pro features are available (purchased, or unlocked by a rewarded ad).
  bool get hasProAccess => isPro || tempUnlocked;

  void grantTempUnlock() {
    tempUnlocked = true;
    notifyListeners();
  }

  void clearTempUnlock() {
    if (!tempUnlocked) return;
    tempUnlocked = false;
    notifyListeners();
  }
  List<HistoryEntry> history = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPro = prefs.getBool(_proKey) ?? false;
    final raw = prefs.getStringList(_historyKey) ?? [];
    history = [
      for (final s in raw)
        HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>)
    ];
    notifyListeners();
  }

  /// TODO: once in_app_purchase is wired up, call this only after purchase verification.
  Future<void> setPro(bool value) async {
    isPro = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, value);
    notifyListeners();
  }

  Future<void> addHistory(HistoryEntry e) async {
    history = [e, ...history].take(_maxHistory).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _historyKey, [for (final h in history) jsonEncode(h.toJson())]);
    notifyListeners();
  }

  /// Temp folder for conversion output / ZIPs. Leftovers are cleaned on app start.
  static Future<Directory> workDir() async {
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}/batchsnap_out');
  }

  static Future<void> cleanCache() async {
    try {
      final d = await workDir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (e, st) {
      Diagnostics.record('Cache cleanup', e, st);
    }
  }
}
