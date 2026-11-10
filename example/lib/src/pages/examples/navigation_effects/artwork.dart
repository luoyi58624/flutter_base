import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 离线矢量风景，用于封面和视差图层，不依赖网络图片加载。
class LandscapeArtwork extends StatelessWidget {
  /// 创建指定配色的风景插画。
  const LandscapeArtwork({super.key, this.variant = 0});

  /// 日出、海岸、暮色、山林四种配色。
  final int variant;

  @override
  Widget build(BuildContext context) => HookBuilder(
    builder: (context) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
      final painter = useMemoized(() => _LandscapePainter(variant, dpr), [variant, dpr]);
      useEffect(() => painter.dispose, [painter]);
      useReassemble(painter.dispose);
      return RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: painter),
      );
    },
  );
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter(this.variant, this.dpr);
  final int variant;
  final double dpr;
  ui.Image? _image;
  Size? _imageSize;
  final Paint _imagePaint = Paint()..filterQuality = .low;

  void dispose() {
    _image?.dispose();
    _image = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_image == null || _imageSize != size) {
      // 保留绘图指令仍会重放曲线；按实际物理尺寸一次光栅化，滚动只采样同一纹理。
      final recorder = ui.PictureRecorder();
      _paintVector(Canvas(recorder)..scale(dpr), size);
      final picture = recorder.endRecording();
      try {
        final image = picture.toImageSync((size.width * dpr).ceil(), (size.height * dpr).ceil());
        _image?.dispose();
        _image = image;
        _imageSize = size;
      } finally {
        picture.dispose();
      }
    }
    canvas.drawImageRect(
      _image!,
      Rect.fromLTWH(0, 0, size.width * dpr, size.height * dpr),
      Offset.zero & size,
      _imagePaint,
    );
  }

  void _paintVector(Canvas canvas, Size size) {
    final palettes = [
      [Color(0xffe7c5a8), Color(0xfff7e8d3), Color(0xffb9a28d), Color(0xff7c8e86), Color(0xff365d58)],
      [Color(0xff8cb2c4), Color(0xffd8e4df), Color(0xffacc7c6), Color(0xff5c929c), Color(0xff2e606d)],
      [Color(0xffbca5b5), Color(0xfff1d5c4), Color(0xffb6a1a3), Color(0xff7c788b), Color(0xff494c69)],
      [Color(0xffcad0b7), Color(0xffeee6cc), Color(0xffaab795), Color(0xff748d77), Color(0xff3e6255)],
    ];
    final colors = palettes[variant % palettes.length];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: colors.take(2).toList(),
        ).createShader(rect),
    );
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * .73, h * .27), h * .1, Paint()..color = Color(0xfffff2d7));
    for (var layer = 0; layer < 3; layer++) {
      final y = h * (.48 + layer * .14);
      final path = Path()..moveTo(0, y + h * .08);
      path.cubicTo(w * .19, y - h * .28, w * .27, y - h * .15, w * .44, y + h * .04);
      path.cubicTo(w * .66, y + h * .23, w * .77, y - h * .25, w, y - h * .02);
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      canvas.drawPath(path, Paint()..color = colors[layer + 2]);
    }
    // 同一图层中的细线让视差有可辨认的参照物。
    final line = Paint()
      ..color = colors[1].withValues(alpha: .22)
      ..style = .stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final y = h * (.81 + i * .027);
      canvas.drawPath(
        Path()
          ..moveTo(w * .08, y)
          ..quadraticBezierTo(w * .35, y - h * .06, w * .58, y),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) => oldDelegate.variant != variant || oldDelegate.dpr != dpr;
}
