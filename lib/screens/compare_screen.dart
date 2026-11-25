import 'dart:io';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';

/// 비포/애프터 비교 뷰어: 슬라이더 왼쪽은 압축본, 오른쪽은 원본. 핀치로 확대 가능.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.item});
  final ConvertedItem item;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  double _split = 0.5;

  Widget _img(String path) => Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.image_not_supported_outlined)),
      );

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Scaffold(
      appBar: AppBar(title: const Text('화질 비교')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('변환 ${formatBytes(it.outBytes)}',
                  style: tabular.copyWith(color: AppColors.success)),
              Text('원본 ${formatBytes(it.source.bytes)}', style: tabular),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            maxScale: 8,
            child: LayoutBuilder(
              builder: (_, c) => Stack(children: [
                Positioned.fill(child: _img(it.source.path)),
                Positioned.fill(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _split,
                      child: SizedBox(
                        width: c.maxWidth,
                        height: c.maxHeight,
                        child: _img(it.outPath),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth * _split - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
              ]),
            ),
          ),
        ),
        Slider(
          value: _split,
          onChanged: (v) => setState(() => _split = v),
        ),
        const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('슬라이더로 변환본(왼쪽)과 원본(오른쪽) 비교'),
            )),
      ]),
    );
  }
}
