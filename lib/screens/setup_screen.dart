import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../services/picker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.images, required this.settings});
  final List<PickedImage> images;
  final BatchSettings settings;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final List<PickedImage> images = [...widget.images];
  late final BatchSettings s = widget.settings;
  late final TextEditingController _suffix =
      TextEditingController(text: s.suffix);

  static const _presets = [200, 500, 1024, 2048];
  // Presets available in the free version.
  static const _freePresets = {500, 1024, 2048};

  bool get _pro => AppState.instance.isPro;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onPro);
    // EXIF removal is a Pro feature, so it defaults to off for free users.
    if (!_pro) s.stripExif = false;
    if (!_pro && s.mode == CompressMode.target && s.targetKb == 200) {
      s.targetKb = 500;
    }
  }

  void _onPro() => setState(() {});

  @override
  void dispose() {
    AppState.instance.removeListener(_onPro);
    _suffix.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final more = await pickImages();
    if (more.isEmpty) return;
    setState(() {
      final paths = images.map((e) => e.path).toSet();
      images.addAll(more.where((e) => !paths.contains(e.path)));
    });
  }

  Future<void> _customKb() async {
    if (!_pro) {
      await showProDialog(context, 'Custom target sizes (e.g. 150KB) are a Pro feature.');
      return;
    }
    final c = TextEditingController();
    final kb = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Target size (KB)'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'KB', hintText: 'e.g. 300'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
              child: const Text('OK')),
        ],
      ),
    );
    if (kb != null && kb >= 10) setState(() => s.targetKb = kb);
  }

  Future<void> _convert() async {
    if (!_pro && images.length > AppState.freeBatchLimit) {
      await showProDialog(context,
          'The free version converts up to ${AppState.freeBatchLimit} photos at a time.');
      return;
    }
    s.suffix = _suffix.text.trim();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ResultScreen(images: [...images], settings: s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Batch setup')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '${images.length} selected · ${formatBytes(totalBytes(images))} total',
                      style: tabular.copyWith(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Add')),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _strip(images[i]),
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<CompressMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: CompressMode.target, label: Text('Target size')),
                    ButtonSegment(
                        value: CompressMode.manual, label: Text('Quality & size')),
                    ButtonSegment(
                        value: CompressMode.formatOnly, label: Text('Format only')),
                  ],
                  selected: {s.mode},
                  onSelectionChanged: (v) => setState(() => s.mode = v.first),
                ),
                const SizedBox(height: 16),
                if (s.mode == CompressMode.target) _targetOptions(scheme),
                if (s.mode == CompressMode.manual) _manualOptions(),
                if (s.mode == CompressMode.formatOnly)
                  const Text('Converts the file format only, with minimal quality loss (quality 95%).'),
                const SizedBox(height: 20),
                Text('Output format', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<OutFormat>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: OutFormat.jpg, label: Text('JPG (default)')),
                    ButtonSegment(value: OutFormat.webp, label: Text('WEBP')),
                    ButtonSegment(value: OutFormat.png, label: Text('PNG')),
                  ],
                  selected: {s.format},
                  onSelectionChanged: (v) => setState(() => s.format = v.first),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    title: const Text('Advanced options'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      SwitchListTile(
                        title: const Text('Remove private info (GPS · EXIF)'),
                        subtitle: _pro ? null : const Text('Pro feature'),
                        value: s.stripExif,
                        onChanged: (v) {
                          if (!_pro) {
                            showProDialog(context, 'Bulk GPS/EXIF removal is a Pro feature.');
                            return;
                          }
                          setState(() => s.stripExif = v);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: TextField(
                          controller: _suffix,
                          decoration: const InputDecoration(
                            labelText: 'File name suffix',
                            hintText: 'e.g. _resized (leave empty to keep the original name)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // No banner ad on this screen to prevent accidental taps.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: images.isEmpty ? null : _convert,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Convert ${images.length} photos',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      if (s.mode == CompressMode.target)
                        Text('Each photo compressed to under ${formatKb(s.targetKb)}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strip(PickedImage img) {
    return SizedBox(
      width: 72,
      child: Column(children: [
        Stack(children: [
          thumb(img.path, size: 72),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => setState(() => images.remove(img)),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 2),
        FormatBadge('${img.format} ${formatBytes(img.bytes)}'),
      ]),
    );
  }

  Widget _targetOptions(ColorScheme scheme) {
    final custom = !_presets.contains(s.targetKb);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final kb in _presets)
        ChoiceChip(
          label: Text('Under ${formatKb(kb)}'),
          avatar: (!_pro && !_freePresets.contains(kb))
              ? const Icon(Icons.lock_outline, size: 16)
              : null,
          selected: s.targetKb == kb,
          onSelected: (_) {
            if (!_pro && !_freePresets.contains(kb)) {
              showProDialog(context, 'The 200KB preset is a Pro feature.');
              return;
            }
            setState(() => s.targetKb = kb);
          },
        ),
      ChoiceChip(
        label: Text(custom ? 'Under ${formatKb(s.targetKb)}' : 'Custom'),
        avatar: _pro ? null : const Icon(Icons.lock_outline, size: 16),
        selected: custom,
        onSelected: (_) => _customKb(),
      ),
    ]);
  }

  Widget _manualOptions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quality ${s.quality}%', style: tabular),
      Slider(
        min: 10,
        max: 100,
        divisions: 18,
        value: s.quality.toDouble(),
        label: '${s.quality}%',
        onChanged: (v) => setState(() => s.quality = v.round()),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in ResizePreset.values)
          ChoiceChip(
            label: Text(r.label),
            selected: s.resize == r,
            onSelected: (_) => setState(() => s.resize = r),
          ),
      ]),
    ]);
  }
}
