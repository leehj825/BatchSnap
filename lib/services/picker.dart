import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models.dart';

final _picker = ImagePicker();

String _formatOf(String path) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'JPG',
    'heic' || 'heif' => 'HEIC',
    'png' => 'PNG',
    'webp' => 'WEBP',
    '' => 'IMG',
    _ => ext.toUpperCase(),
  };
}

/// 시스템 포토 피커로 다중 선택 (전체 저장소 권한 불필요).
Future<List<PickedImage>> pickImages() async {
  final files = await _picker.pickMultiImage();
  final out = <PickedImage>[];
  for (final f in files) {
    out.add(PickedImage(
      path: f.path,
      name: p.basenameWithoutExtension(f.name.isNotEmpty ? f.name : f.path),
      bytes: await File(f.path).length(),
      format: _formatOf(f.name.isNotEmpty ? f.name : f.path),
    ));
  }
  return out;
}
