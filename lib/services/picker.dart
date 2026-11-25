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

/// Multi-select via the system photo picker (no broad storage permission needed).
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
