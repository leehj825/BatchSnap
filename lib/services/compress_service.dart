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
  final Uint8List? best; // Highest-quality result that fits the target
  final int bestQuality;
  final Uint8List? lowest; // Smallest result produced (fallback when the target is not reached)
}

class CompressService {
  /// Below this quality artifacts become obvious, so downscale resolution first.
  static const _minAcceptableQuality = 30;
  static const _qualityIterations = 6;
  static const _maxDownscales = 3;

  static CompressFormat _fmt(OutFormat f) => switch (f) {
        OutFormat.jpg => CompressFormat.jpeg,
        OutFormat.webp => CompressFormat.webp,
        OutFormat.png => CompressFormat.png,
      };

  /// Reads only the header to get the source resolution (no full decode).
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

  /// Note: minWidth/minHeight default to 1920, so a large value must be passed
  /// explicitly when no resize is wanted, or images get downscaled unintentionally.
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

  /// Stage 1: binary search on quality at the current resolution.
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

  /// Fit to target size. Returns (bytes, whether the target was met).
  static Future<(Uint8List, bool)> _compressToTarget(
    String path,
    int targetBytes,
    OutFormat format,
    bool keepExif,
  ) async {
    final dims = await _dimensions(path);
    int? w = dims?.$1, h = dims?.$2;
    Uint8List? fitFallback; // Fits the target but at low quality
    Uint8List? lastAttempt;

    for (var step = 0; step <= _maxDownscales; step++) {
      if (format == OutFormat.png) {
        // PNG is lossless so quality is meaningless; only downscale.
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
      // Stage 2: shrink width and height by 0.75x and retry.
      w = ((w ?? 4032) * 0.75).round();
      h = ((h ?? 3024) * 0.75).round();
    }

    if (fitFallback != null) return (fitFallback, true);
    if (lastAttempt == null) {
      throw Exception('Failed to compress image: $path');
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
    if (long <= maxSide) return (null, null); // never upscale
    final s = maxSide / long;
    return ((w * s).round(), (h * s).round());
  }

  /// Processes images sequentially (OOM safety: one at a time, written to disk immediately).
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
          if (out == null) throw Exception('Conversion failed: ${img.name}');
          bytes = out;
        case CompressMode.formatOnly:
          final out = await _encode(img.path,
              quality: 95, format: s.format, keepExif: keepExif);
          if (out == null) throw Exception('Conversion failed: ${img.name}');
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
