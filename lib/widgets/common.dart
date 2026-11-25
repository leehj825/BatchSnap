import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/app_state.dart';
import '../theme.dart';

/// 점선 라운드 테두리 카드 (홈 히어로 영역).
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

/// 홈 화면 하단 광고 자리. 실제 AdMob 적응형 배너로 교체 예정.
/// 상단 콘텐츠와 최소 16dp 여백을 보장한다.
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
        child: const Text('AdMob 배너 광고 영역'),
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

/// 유료 기능 안내. 결제 연동 전까지는 테스트용 잠금 해제 버튼을 제공한다.
Future<void> showProDialog(BuildContext context, String reason) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pro 기능'),
      content: Text('$reason\n\n일회성 결제로 광고 제거, 무제한 일괄 변환, '
          '사용자 지정 용량, EXIF/GPS 삭제, ZIP 공유를 모두 사용할 수 있어요.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        FilledButton(
          onPressed: () async {
            // TODO: in_app_purchase 구매 플로우로 교체.
            await AppState.instance.setPro(true);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Pro 잠금 해제 (테스트)'),
        ),
      ],
    ),
  );
}

/// 선택된 사진 총 용량.
int totalBytes(List<PickedImage> l) => l.fold(0, (a, b) => a + b.bytes);
