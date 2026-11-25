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
  // 무료 버전에서 쓸 수 있는 프리셋 (설계서 5장).
  static const _freePresets = {500, 1024, 2048};

  bool get _pro => AppState.instance.isPro;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onPro);
    // 무료 사용자는 EXIF 삭제가 Pro 기능이므로 기본 off.
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
      await showProDialog(context, '사용자 지정 용량(예: 150KB)은 Pro 기능이에요.');
      return;
    }
    final c = TextEditingController();
    final kb = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('목표 용량 (KB)'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'KB', hintText: '예: 300'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
              child: const Text('확인')),
        ],
      ),
    );
    if (kb != null && kb >= 10) setState(() => s.targetKb = kb);
  }

  Future<void> _convert() async {
    if (!_pro && images.length > AppState.freeBatchLimit) {
      await showProDialog(context,
          '무료 버전은 한 번에 ${AppState.freeBatchLimit}장까지 변환할 수 있어요.');
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
      appBar: AppBar(title: const Text('일괄 설정')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '선택됨 ${images.length}장 · 총 ${formatBytes(totalBytes(images))}',
                      style: tabular.copyWith(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('추가')),
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
                        value: CompressMode.target, label: Text('목표 용량')),
                    ButtonSegment(
                        value: CompressMode.manual, label: Text('화질·크기')),
                    ButtonSegment(
                        value: CompressMode.formatOnly, label: Text('포맷만 변환')),
                  ],
                  selected: {s.mode},
                  onSelectionChanged: (v) => setState(() => s.mode = v.first),
                ),
                const SizedBox(height: 16),
                if (s.mode == CompressMode.target) _targetOptions(scheme),
                if (s.mode == CompressMode.manual) _manualOptions(),
                if (s.mode == CompressMode.formatOnly)
                  const Text('화질 손실을 최소화(품질 95%)하면서 확장자만 변환합니다.'),
                const SizedBox(height: 20),
                Text('출력 포맷', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<OutFormat>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: OutFormat.jpg, label: Text('JPG (기본)')),
                    ButtonSegment(value: OutFormat.webp, label: Text('WEBP')),
                    ButtonSegment(value: OutFormat.png, label: Text('PNG')),
                  ],
                  selected: {s.format},
                  onSelectionChanged: (v) => setState(() => s.format = v.first),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    title: const Text('고급 옵션'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      SwitchListTile(
                        title: const Text('개인정보(GPS·EXIF) 삭제'),
                        subtitle: _pro ? null : const Text('Pro 기능'),
                        value: s.stripExif,
                        onChanged: (v) {
                          if (!_pro) {
                            showProDialog(context, 'GPS·EXIF 일괄 삭제는 Pro 기능이에요.');
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
                            labelText: '파일명 접미사',
                            hintText: '예: _resized (비우면 원본 이름 유지)',
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
          // 오클릭 방지를 위해 이 화면에는 배너 광고를 두지 않는다.
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
                      Text('${images.length}장 일괄 변환하기',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      if (s.mode == CompressMode.target)
                        Text('예상: 장당 ${formatKb(s.targetKb)} 이하로 압축',
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
          label: Text('${formatKb(kb)} 이하'),
          avatar: (!_pro && !_freePresets.contains(kb))
              ? const Icon(Icons.lock_outline, size: 16)
              : null,
          selected: s.targetKb == kb,
          onSelected: (_) {
            if (!_pro && !_freePresets.contains(kb)) {
              showProDialog(context, '200KB 프리셋은 Pro 기능이에요.');
              return;
            }
            setState(() => s.targetKb = kb);
          },
        ),
      ChoiceChip(
        label: Text(custom ? '${formatKb(s.targetKb)} 이하' : '직접 입력'),
        avatar: _pro ? null : const Icon(Icons.lock_outline, size: 16),
        selected: custom,
        onSelected: (_) => _customKb(),
      ),
    ]);
  }

  Widget _manualOptions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('품질 ${s.quality}%', style: tabular),
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
