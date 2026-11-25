import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/app_state.dart';
import '../theme.dart';

/// Dashed rounded border box (home hero area).
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashPainter(color),
        child: child,
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(20)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d, d + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Ad slot at the bottom of the home screen. To be replaced with a real AdMob
/// adaptive banner. Keeps at least 16dp of space from the content above.
class AdBannerPlaceholder extends StatelessWidget {
  const AdBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppState.instance.isPro) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Text('AdMob banner ad area'),
      ),
    );
  }
}

class FormatBadge extends StatelessWidget {
  const FormatBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: tabular.copyWith(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

Widget thumb(String path, {double size = 64}) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );

/// Pro feature prompt. Offers a test unlock button until billing is integrated.
Future<void> showProDialog(BuildContext context, String reason) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pro feature'),
      content: Text('$reason\n\nA one-time purchase removes ads and unlocks unlimited batches, '
          'custom target sizes, EXIF/GPS removal, and ZIP sharing.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton(
          onPressed: () async {
            // TODO: replace with the in_app_purchase flow.
            await AppState.instance.setPro(true);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Unlock Pro (test)'),
        ),
      ],
    ),
  );
}

/// Total size of the selected photos.
int totalBytes(List<PickedImage> l) => l.fold(0, (a, b) => a + b.bytes);
