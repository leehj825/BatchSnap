String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

String formatKb(int kb) => kb >= 1024 && kb % 1024 == 0
    ? '${kb ~/ 1024} MB'
    : '$kb KB';

String formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
