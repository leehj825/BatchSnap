import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../services/compress_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'compare_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.images, required this.settings});
  final List<PickedImage> images;
  final BatchSettings settings;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _cancel = CancelToken();
  List<ConvertedItem> _items = [];
  bool _done = false;
  int _index = 0;
  String _current = '';
  String? _error;
  bool _savedToGallery = false;
  late Directory _outDir;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final root = await AppState.workDir();
      _outDir = Directory(
          '${root.path}/${DateTime.now().millisecondsSinceEpoch}');
      final items = await CompressService.run(
        widget.images,
        widget.settings,
        _outDir,
        cancel: _cancel,
        onProgress: (i, name) {
          if (mounted) setState(() => (_index, _current) = (i, name));
        },
      );
      if (!mounted) return;
      if (items.isEmpty) {
        Navigator.pop(context); // 첫 장 처리 전에 취소됨
        return;
      }
      setState(() {
        _items = items;
        _done = true;
      });
      await _saveToGallery();
      final before = items.fold<int>(0, (a, b) => a + b.source.bytes);
      final after = items.fold<int>(0, (a, b) => a + b.outBytes);
      await AppState.instance.addHistory(HistoryEntry(
        date: DateTime.now(),
        count: items.length,
        beforeBytes: before,
        afterBytes: after,
      ));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _saveToGallery() async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) return;
      }
      for (final it in _items) {
        await Gal.putImage(it.outPath, album: 'BatchSnap');
      }
      if (mounted) setState(() => _savedToGallery = true);
    } catch (_) {
      // 저장 실패해도 공유는 가능하므로 조용히 넘어간다.
    }
  }

  Future<void> _shareAll() async {
    await Share.shareXFiles([for (final i in _items) XFile(i.outPath)]);
  }

  Future<void> _shareZip() async {
    if (!AppState.instance.isPro) {
      await showProDialog(context, 'ZIP으로 묶어 공유는 Pro 기능이에요.');
      return;
    }
    final zipPath = '${_outDir.path}/BatchSnap.zip';
    final enc = ZipFileEncoder()..create(zipPath);
    for (final i in _items) {
      await enc.addFile(File(i.outPath));
    }
    enc.close();
    await Share.shareXFiles([XFile(zipPath)]);
  }

  @override
  void dispose() {
    _cancel.cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('변환 실패')),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24), child: Text(_error!))),
      );
    }
    return PopScope(
      canPop: _done,
      child: Scaffold(
        appBar: AppBar(
            title: Text(_done ? '변환 완료' : '변환 중...'),
            automaticallyImplyLeading: _done),
        body: _done ? _result() : _progress(),
      ),
    );
  }

  Widget _progress() {
    final total = widget.images.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_index + 1} / $total 처리 중...',
              style: tabular.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _index / total, minHeight: 8),
          const SizedBox(height: 12),
          Text(_current, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              _cancel.cancelled = true; // 현재 장 처리 후 중단
            },
            child: const Text('취소'),
          ),
        ]),
      ),
    );
  }

  Widget _result() {
    final before = _items.fold<int>(0, (a, b) => a + b.source.bytes);
    final after = _items.fold<int>(0, (a, b) => a + b.outBytes);
    final saved = before - after;
    final pct = before == 0 ? 0.0 : saved / before * 100;
    final missed = _items.where((i) => !i.targetMet).length;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('${formatBytes(before)} → ${formatBytes(after)}',
                    style: tabular.copyWith(fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  saved > 0
                      ? '${formatBytes(saved)} 절약 (-${pct.toStringAsFixed(1)}%)'
                      : '용량이 줄지 않았어요',
                  style: tabular.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success),
                ),
                const SizedBox(height: 10),
                if (_savedToGallery)
                  const Chip(
                    avatar: Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                    label: Text('갤러리(/Pictures/BatchSnap)에 자동 저장됨'),
                  ),
                if (missed > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('$missed장은 목표 용량에 도달하지 못했어요 (최대한 압축됨)',
                        style: const TextStyle(color: Colors.orange)),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          for (final it in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: thumb(it.outPath, size: 52),
              title: Text('${it.source.name}.${it.outFormat.ext}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${it.source.format} ${formatBytes(it.source.bytes)} → '
                '${it.outFormat.label} ${formatBytes(it.outBytes)} '
                '(${it.reduction >= 0 ? '-' : '+'}${it.reduction.abs().round()}%)',
                style: tabular,
              ),
              trailing: it.targetMet
                  ? null
                  : const Icon(Icons.warning_amber, color: Colors.orange),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CompareScreen(item: it)),
              ),
            ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _shareAll,
                icon: const Icon(Icons.share),
                label: const Text('전체 공유하기'),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: _shareZip,
                    child: const Text('ZIP으로 묶어 공유 (Pro)')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                    child: const Text('홈으로')),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}
