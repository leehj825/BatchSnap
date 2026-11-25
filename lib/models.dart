enum CompressMode { target, manual, formatOnly }

enum OutFormat { jpg, webp, png }

enum ResizePreset { original, side1920, side1280, side800, half }

extension OutFormatX on OutFormat {
  String get ext => switch (this) {
        OutFormat.jpg => 'jpg',
        OutFormat.webp => 'webp',
        OutFormat.png => 'png',
      };
  String get label => ext.toUpperCase();
}

extension ResizePresetX on ResizePreset {
  String get label => switch (this) {
        ResizePreset.original => '원본 유지',
        ResizePreset.side1920 => '긴 변 1920px',
        ResizePreset.side1280 => '1280px',
        ResizePreset.side800 => '800px',
        ResizePreset.half => '50% 축소',
      };
}

class PickedImage {
  PickedImage({
    required this.path,
    required this.name,
    required this.bytes,
    required this.format,
  });

  final String path;
  final String name; // 확장자 제외 파일명
  final int bytes;
  final String format; // HEIC / JPG / PNG / WEBP ...
}

class BatchSettings {
  BatchSettings({
    this.mode = CompressMode.target,
    this.targetKb = 500,
    this.quality = 80,
    this.resize = ResizePreset.original,
    this.format = OutFormat.jpg,
    this.stripExif = true,
    this.suffix = '',
  });

  CompressMode mode;
  int targetKb;
  int quality; // 10..100
  ResizePreset resize;
  OutFormat format;
  bool stripExif;
  String suffix;
}

class ConvertedItem {
  ConvertedItem({
    required this.source,
    required this.outPath,
    required this.outBytes,
    required this.outFormat,
    required this.targetMet,
  });

  final PickedImage source;
  final String outPath;
  final int outBytes;
  final OutFormat outFormat;

  /// 목표 용량 모드에서 목표를 달성했는지 (다른 모드에서는 항상 true).
  final bool targetMet;

  double get reduction =>
      source.bytes == 0 ? 0 : (1 - outBytes / source.bytes) * 100;
}

class HistoryEntry {
  HistoryEntry({
    required this.date,
    required this.count,
    required this.beforeBytes,
    required this.afterBytes,
  });

  final DateTime date;
  final int count;
  final int beforeBytes;
  final int afterBytes;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'count': count,
        'before': beforeBytes,
        'after': afterBytes,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        date: DateTime.parse(j['date'] as String),
        count: j['count'] as int,
        beforeBytes: j['before'] as int,
        afterBytes: j['after'] as int,
      );
}
