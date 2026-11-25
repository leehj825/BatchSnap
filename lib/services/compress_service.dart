import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import '../models.dart';

class CancelToken {
  bool cancelled = false;
}

class _SearchResult {
  _SearchResult(this.best, this.bestQuality, this.lowest);
  final Uint8List? best; // 목표 이하인 결과 중 최고 화질
  final int bestQuality;
  final Uint8List? lowest; // 가장 낮은 화질로 만든 결과 (목표 미달성 시 폴백)
}

class CompressService {
  /// 이 값 이하로 내려가면 화질 뭉개짐이 커지므로 해상도를 먼저 줄인다 (설계서 6.2).
  static const _minAcceptableQuality = 30;
  static const _qualityIterations = 6;
  static const _maxDownscales = 3;

  static CompressFormat _fmt(OutFormat f) => switch (f) {
        OutFormat.jpg => CompressFormat.jpeg,
        OutFormat.webp => CompressFormat.webp,
        OutFormat.png => CompressFormat.png,
      };

  /// 디코딩 없이 헤더만 읽어 원본 해상도를 얻는다.
  static Future<(int, int)?> _dimensions(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
      final desc = await ui.ImageDescriptor.encoded(buf);
      final r = (desc.width, desc.height);
      desc.dispose();
      buf.dispose();
      return r;
    } catch (_) {
      return null;
    }
  }

  /// 주의: minWidth/minHeight 기본값이 1920이라, 리사이즈를 원하지 않을 때도
  /// 큰 값을 명시해야 의도치 않은 다운스케일이 일어나지 않는다.
  static Future<Uint8List?> _encode(
    String path, {
    required int quality,
    required OutFormat format,
    required bool keepExif,
    int? width,
    int? height,
  }) {
    return FlutterImageCompress.compressWithFile(
      path,
      quality: quality,
      minWidth: width ?? 100000,
      minHeight: height ?? 100000,
      format: _fmt(format),
      keepExif: keepExif,
    );
  }

  /// 1단계: 현재 해상도에서 Quality 이진 탐색.
  static Future<_SearchResult> _qualitySearch(
    String path,
    int targetBytes,
    OutFormat format,
    bool keepExif,
    int? w,
    int? h,
  ) async {
    var lo = 20, hi = 95;
    Uint8List? best, lowest;
    var bestQ = 0;
    for (var i = 0; i < _qualityIterations && lo <= hi; i++) {
      final mid = (lo + hi) ~/ 2;
      final out = await _encode(path,
          quality: mid, format: format, keepExif: keepExif, width: w, height: h);
      if (out == null) break;
      if (lowest == null || out.length < lowest.length) lowest = out;
      if (out.length <= targetBytes) {
        best = out;
        bestQ = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return _SearchResult(best, bestQ, lowest);
  }

  /// 목표 용량 맞춤. (바이트, 목표 달성 여부)를 반환.
  static Future<(Uint8List, bool)> _compressToTarget(
    String path,
    int targetBytes,
    OutFormat format,
    bool keepExif,
  ) async {
    final dims = await _dimensions(path);
    int? w = dims?.$1, h = dims?.$2;
    Uint8List? fitFallback; // 목표 이하이지만 저화질인 결과
    Uint8List? lastAttempt;

    for (var step = 0; step <= _maxDownscales; step++) {
      if (format == OutFormat.png) {
        // PNG는 무손실이라 quality가 의미 없다. 해상도만 줄인다.
        final out = await _encode(path,
            quality: 100, format: format, keepExif: keepExif, width: w, height: h);
        if (out != null) {
          lastAttempt = out;
          if (out.length <= targetBytes) return (out, true);
        }
      } else {
        final r =
            await _qualitySearch(path, targetBytes, format, keepExif, w, h);
        if (r.lowest != null) lastAttempt = r.lowest;
        if (r.best != null) {
          if (r.bestQuality >= _minAcceptableQuality) return (r.best!, true);
          fitFallback = r.best;
        }
      }
      // 2단계: 가로·세로 0.75배 축소 후 재시도.
      w = ((w ?? 4032) * 0.75).round();
      h = ((h ?? 3024) * 0.75).round();
    }

    if (fitFallback != null) return (fitFallback, true);
    if (lastAttempt == null) {
      throw Exception('이미지를 압축하지 못했습니다: $path');
    }
    return (lastAttempt, false);
  }

  static Future<(int?, int?)> _manualSize(
      String path, ResizePreset preset) async {
    if (preset == ResizePreset.original) return (null, null);
    final dims = await _dimensions(path);
    if (dims == null) return (null, null);
    final (w, h) = dims;
    if (preset == ResizePreset.half) {
      return ((w / 2).round(), (h / 2).round());
    }
    final maxSide = switch (preset) {
      ResizePreset.side1920 => 1920,
      ResizePreset.side1280 => 1280,
      _ => 800,
    };
    final long = w > h ? w : h;
    if (long <= maxSide) return (null, null); // 확대하지 않음
    final s = maxSide / long;
    return ((w * s).round(), (h * s).round());
  }

  /// 이미지를 순차 처리한다 (OOM 방지: 한 번에 한 장, 결과는 즉시 디스크로).
  static Future<List<ConvertedItem>> run(
    List<PickedImage> images,
    BatchSettings s,
    Directory outDir, {
    void Function(int index, String name)? onProgress,
    CancelToken? cancel,
  }) async {
    await outDir.create(recursive: true);
    final results = <ConvertedItem>[];
    final used = <String>{};
    final keepExif = !s.stripExif;

    for (var i = 0; i < images.length; i++) {
      if (cancel?.cancelled ?? false) break;
      final img = images[i];
      onProgress?.call(i, img.name);

      Uint8List bytes;
      var met = true;
      switch (s.mode) {
        case CompressMode.target:
          final r = await _compressToTarget(
              img.path, s.targetKb * 1024, s.format, keepExif);
          bytes = r.$1;
          met = r.$2;
        case CompressMode.manual:
          final (w, h) = await _manualSize(img.path, s.resize);
          final out = await _encode(img.path,
              quality: s.quality,
              format: s.format,
              keepExif: keepExif,
              width: w,
              height: h);
          if (out == null) throw Exception('변환 실패: ${img.name}');
          bytes = out;
        case CompressMode.formatOnly:
          final out = await _encode(img.path,
              quality: 95, format: s.format, keepExif: keepExif);
          if (out == null) throw Exception('변환 실패: ${img.name}');
          bytes = out;
      }

      var base = '${img.name}${s.suffix}';
      var file = '$base.${s.format.ext}';
      for (var n = 2; used.contains(file.toLowerCase()); n++) {
        file = '${base}_$n.${s.format.ext}';
      }
      used.add(file.toLowerCase());

      final outPath = p.join(outDir.path, file);
      await File(outPath).writeAsBytes(bytes, flush: true);

      results.add(ConvertedItem(
        source: img,
        outPath: outPath,
        outBytes: bytes.length,
        outFormat: s.format,
        targetMet: met,
      ));
    }
    return results;
  }
}
