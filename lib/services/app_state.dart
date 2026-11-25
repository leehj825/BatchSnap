import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Pro 상태와 변환 기록. 의존성 최소화를 위해 ChangeNotifier 싱글톤으로 구현.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  static const freeBatchLimit = 10;
  static const _proKey = 'is_pro';
  static const _historyKey = 'history';
  static const _maxHistory = 30;

  bool isPro = false;
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

  /// TODO: in_app_purchase 연동 시 구매 검증 결과로만 호출할 것.
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

  /// 임시 변환 결과/ZIP 폴더. 앱 시작 시 이전 잔여물을 정리한다.
  static Future<Directory> workDir() async {
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}/batchsnap_out');
  }

  static Future<void> cleanCache() async {
    try {
      final d = await workDir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
