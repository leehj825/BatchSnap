import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../services/picker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _start(BuildContext context, BatchSettings settings) async {
    final images = await pickImages();
    if (images.isEmpty || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SetupScreen(images: images, settings: settings)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        return Scaffold(
          appBar: AppBar(
            title: const Text('BatchSnap',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              ActionChip(
                avatar: const Icon(Icons.workspace_premium,
                    size: 18, color: Color(0xFFB45309)),
                label: Text(state.isPro ? 'PRO' : 'Get PRO'),
                backgroundColor: const Color(0xFFFEF3C7),
                onPressed: state.isPro
                    ? null
                    : () => showProDialog(context, 'Unlock all limits with Pro.'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'BatchSnap',
                  applicationVersion: '0.1.0',
                  children: const [
                    Text('100% offline · No interstitial ads · No sign-in'),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const StartupProblemsCard(),
                    DashedBorderBox(
                      onTap: () => _start(context, BatchSettings()),
                      child: const SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 44),
                            SizedBox(height: 8),
                            Text('+ Select multiple photos',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Gov / Web (under 500KB)'),
                          onPressed: () => _start(
                              context,
                              BatchSettings(
                                  mode: CompressMode.target, targetKb: 500)),
                        ),
                        ActionChip(
                          label: const Text('Convert format (all to JPG)'),
                          onPressed: () => _start(
                              context,
                              BatchSettings(
                                  mode: CompressMode.formatOnly,
                                  format: OutFormat.jpg)),
                        ),
                        ActionChip(
                          label: const Text('Halve file size (50%)'),
                          onPressed: () => _start(
                              context,
                              BatchSettings(
                                  mode: CompressMode.manual,
                                  quality: 70,
                                  resize: ResizePreset.half)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('Recent conversions',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (state.history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No conversions yet')),
                      )
                    else
                      for (final h in state.history) _HistoryCard(h),
                  ],
                ),
              ),
              const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 0),
                  child: AdBanner(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.h);
  final HistoryEntry h;

  @override
  Widget build(BuildContext context) {
    final pct = h.beforeBytes == 0
        ? 0
        : ((1 - h.afterBytes / h.beforeBytes) * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${h.count} photos processed',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(formatDate(h.date)),
        trailing: Text(
          '${formatBytes(h.beforeBytes)} → ${formatBytes(h.afterBytes)} · -$pct%',
          style: tabular.copyWith(
              color: AppColors.success, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
