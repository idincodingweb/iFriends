import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../theme/app_theme.dart';

enum CropAspect { square, portrait, cover }

extension CropAspectX on CropAspect {
  double get ratio {
    switch (this) {
      case CropAspect.square:
        return 1.0;
      case CropAspect.portrait:
        return 3 / 4;
      case CropAspect.cover:
        return 16 / 9;
    }
  }

  String get label {
    switch (this) {
      case CropAspect.square:
        return '1:1';
      case CropAspect.portrait:
        return '3:4';
      case CropAspect.cover:
        return '16:9';
    }
  }
}

/// In-app cropper (pure Dart). Pan + pinch-zoom inside a fixed-aspect
/// viewport. Returns a cropped JPEG [File] on confirm, or null on cancel.
class ImageCropScreen extends StatefulWidget {
  final File file;
  final List<CropAspect> aspects;
  final String title;

  const ImageCropScreen({
    super.key,
    required this.file,
    this.aspects = const [CropAspect.square, CropAspect.portrait],
    this.title = 'Crop',
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _ctrl = TransformationController();
  late CropAspect _aspect = widget.aspects.first;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Size _viewport(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxW = mq.size.width - 24;
    // Reserve space: topbar ~52, aspect bar ~52, confirm ~76, paddings.
    final reserved =
        mq.padding.top + mq.padding.bottom + 52 + (widget.aspects.length > 1 ? 52 : 0) + 76 + 24;
    final maxH = mq.size.height - reserved;
    double vw = maxW;
    double vh = vw / _aspect.ratio;
    if (vh > maxH) {
      vh = maxH;
      vw = vh * _aspect.ratio;
    }
    return Size(vw, vh);
  }

  Future<void> _confirm() async {
    final vp = _viewport(context);
    final vw = vp.width;
    final vh = vp.height;
    setState(() => _busy = true);
    try {
      final bytes = await widget.file.readAsBytes();
      final src = img.decodeImage(bytes);
      if (src == null) throw 'Gagal decode gambar';

      final W = src.width.toDouble();
      final H = src.height.toDouble();

      // BoxFit.cover into (vw,vh): scale = max(vw/W, vh/H).
      final coverScale = math.max(vw / W, vh / H);
      final dispW = W * coverScale;
      final dispH = H * coverScale;
      final offX = (vw - dispW) / 2;
      final offY = (vh - dispH) / 2;

      final inv = Matrix4.inverted(_ctrl.value);
      final tl = MatrixUtils.transformPoint(inv, const Offset(0, 0));
      final br = MatrixUtils.transformPoint(inv, Offset(vw, vh));

      double px0 = ((tl.dx - offX) / coverScale).clamp(0, W);
      double py0 = ((tl.dy - offY) / coverScale).clamp(0, H);
      double px1 = ((br.dx - offX) / coverScale).clamp(0, W);
      double py1 = ((br.dy - offY) / coverScale).clamp(0, H);

      final cropW = math.max(1, (px1 - px0).round());
      final cropH = math.max(1, (py1 - py0).round());

      final cropped = img.copyCrop(
        src,
        x: px0.round(),
        y: py0.round(),
        width: cropW,
        height: cropH,
      );

      final outBytes = img.encodeJpg(cropped, quality: 88);
      final tmp = await File(
        '${Directory.systemTemp.path}/ifriends_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ).writeAsBytes(outBytes, flush: true);

      if (mounted) Navigator.of(context).pop<File>(tmp);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop gagal: $e')),
        );
      }
    }
  }

  void _changeAspect(CropAspect a) {
    if (a == _aspect) return;
    setState(() {
      _aspect = a;
      _ctrl.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vp = _viewport(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: vp.width,
                  height: vp.height,
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _ctrl,
                      minScale: 1,
                      maxScale: 5,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: vp.width,
                        height: vp.height,
                        child: Image.file(
                          widget.file,
                          fit: BoxFit.cover,
                          width: vp.width,
                          height: vp.height,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.aspects.length > 1) _aspectBar(),
            _confirmBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(widget.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _aspectBar() {
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final a in widget.aspects)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => _changeAspect(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: a == _aspect ? AppColors.vibrant : null,
                    color: a == _aspect ? null : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(a.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _confirmBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: GestureDetector(
        onTap: _busy ? null : _confirm,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.vibrant,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Text('Use photo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
