import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models.dart';
import '../services/ads_service.dart';
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

/// Anchored adaptive AdMob banner for the bottom of the home screen. Shows
/// nothing for Pro users or until an ad has loaded, and keeps at least 16dp of
/// space from the content above.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AdsService.ready, AppState.instance]),
      builder: (context, _) {
        if (AppState.instance.isPro || !AdsService.ready.value) {
          return const SizedBox.shrink();
        }
        return const _BannerLoader();
      },
    );
  }
}

class _BannerLoader extends StatefulWidget {
  const _BannerLoader();

  @override
  State<_BannerLoader> createState() => _BannerLoaderState();
}

class _BannerLoaderState extends State<_BannerLoader> {
  BannerAd? _ad;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (!mounted) {
            a.dispose();
            return;
          }
          setState(() => _ad = a as BannerAd);
        },
        onAdFailedToLoad: (a, _) => a.dispose(),
      ),
    );
    _pending = ad;
    ad.load();
  }

  BannerAd? _pending;

  @override
  void dispose() {
    _pending?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
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

/// Pro feature prompt. Offers a rewarded ad that unlocks Pro features for one
/// batch, plus a test unlock button until billing is integrated.
Future<void> showProDialog(BuildContext context, String reason) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ProDialog(reason: reason),
  );
}

class _ProDialog extends StatefulWidget {
  const _ProDialog({required this.reason});
  final String reason;

  @override
  State<_ProDialog> createState() => _ProDialogState();
}

class _ProDialogState extends State<_ProDialog> {
  bool _loadingAd = false;
  String? _message;

  Future<void> _watchAd() async {
    setState(() {
      _loadingAd = true;
      _message = null;
    });
    final earned = await AdsService.showRewarded();
    if (!mounted) return;
    if (earned) {
      AppState.instance.grantTempUnlock();
      Navigator.pop(context);
    } else {
      setState(() {
        _loadingAd = false;
        _message = 'The ad is not available right now. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pro feature'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.reason}\n\nA one-time purchase removes ads and unlocks '
              'unlimited batches, custom target sizes, EXIF/GPS removal, and ZIP sharing.'),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, style: const TextStyle(color: Colors.orange)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(
          onPressed: _loadingAd ? null : _watchAd,
          child: _loadingAd
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Watch ad: unlock for 1 batch'),
        ),
        FilledButton(
          onPressed: () async {
            // TODO: replace with the in_app_purchase flow.
            await AppState.instance.setPro(true);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Unlock Pro (test)'),
        ),
      ],
    );
  }
}

/// Total size of the selected photos.
int totalBytes(List<PickedImage> l) => l.fold(0, (a, b) => a + b.bytes);
