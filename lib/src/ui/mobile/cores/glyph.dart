/// 参照：D:/project/html/my-ui/packages/core/my-ui.js:13-59、1377-1394；my-ui.css:154-163、3771-3780。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// SVG 的绘制读取最近 ElView 已提交的文字色，主题和颜色动画不会重建图标。
class Glyph extends LeafRenderObjectWidget {
  /// 内置图标或加载圆弧。
  const Glyph({super.key, this.name = '', this.spinner = false, this.size = 24});

  /// 与Web相同的图标名称。
  final String name;

  /// 是否绘制加载圆弧。
  final bool spinner;

  /// 目标边长（逻辑像素），实际尺寸仍受父约束限制。
  final double size;

  @override
  RenderObject createRenderObject(BuildContext context) => _GlyphRender(name, spinner, size);

  @override
  void updateRenderObject(BuildContext context, covariant RenderBox renderObject) =>
      (renderObject as _GlyphRender).configure(name, spinner, size);
}

class _GlyphRender extends RenderBox {
  _GlyphRender(this._name, this._spinner, this._extent);
  String _name;
  bool _spinner;
  double _extent;

  void configure(String name, bool spinner, double extent) {
    if (_extent != extent) {
      _extent = extent;
      markNeedsLayout();
    }
    if (_name == name && _spinner == spinner) return;
    _name = name;
    _spinner = spinner;
    markNeedsPaint();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size.square(_extent));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    var ancestor = parent;
    var color = const Color(0xff17191e);
    while (ancestor != null) {
      if (ancestor is ElRenderView && ancestor.currentColorForBuild != null) {
        color = ancestor.currentColorForBuild!;
        break;
      }
      ancestor = ancestor.parent;
    }
    final canvas = context.canvas;
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = _spinner ? 2.5 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (_spinner) {
      // 原版 circle r=9、dasharray=42 16，首段从圆的右侧开始。
      canvas.drawArc(const Rect.fromLTWH(3, 3, 18, 18), 0, 42 / 9, false, paint);
    } else {
      final name = _iconMarkup.containsKey(_name) ? _name : 'sun';
      for (final path in _iconPaths.putIfAbsent(name, () => _compileIcon(_iconMarkup[name]!))) {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }
}

final _iconPaths = <String, List<Path>>{};

List<Path> _compileIcon(String markup) {
  final result = <Path>[];
  for (final element in RegExp(r'<(path|circle|rect)\b([^>]*)/?>').allMatches(markup)) {
    final attrs = <String, String>{
      for (final attr in RegExp(r'([\w-]+)="([^"]*)"').allMatches(element[2]!)) attr[1]!: attr[2]!,
    };
    double number(String name, [double fallback = 0]) => double.tryParse(attrs[name] ?? '') ?? fallback;
    switch (element[1]) {
      case 'path':
        result.add(_svgPath(attrs['d']!));
      case 'circle':
        result.add(Path()..addOval(Rect.fromCircle(center: Offset(number('cx'), number('cy')), radius: number('r'))));
      case 'rect':
        result.add(
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(number('x'), number('y'), number('width'), number('height')),
              Radius.circular(number('rx')),
            ),
          ),
        );
    }
  }
  return result;
}

/// 只解析原图标使用的 SVG 指令，曲线与椭圆弧直接交给 Canvas，避免字体轮廓采样误差。
Path _svgPath(String source) {
  final tokens = RegExp(r'[a-zA-Z]|[-+]?(?:\d*\.?\d+)(?:[eE][-+]?\d+)?')
      .allMatches(source)
      .map((match) => match[0]!)
      .toList();
  final path = Path();
  var index = 0, command = '';
  var current = Offset.zero, start = Offset.zero;
  Offset? cubic;
  String previous = '';
  double read() => double.parse(tokens[index++]);
  bool isCommand(String value) => RegExp(r'^[a-zA-Z]$').hasMatch(value);
  while (index < tokens.length) {
    if (isCommand(tokens[index])) command = tokens[index++];
    final relative = command == command.toLowerCase();
    final op = command.toUpperCase();
    Offset point() {
      final value = Offset(read(), read());
      return relative ? current + value : value;
    }

    switch (op) {
      case 'M':
        current = point();
        start = current;
        path.moveTo(current.dx, current.dy);
        command = relative ? 'l' : 'L';
      case 'L':
        current = point();
        path.lineTo(current.dx, current.dy);
      case 'H':
        current = Offset((relative ? current.dx : 0) + read(), current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        current = Offset(current.dx, (relative ? current.dy : 0) + read());
        path.lineTo(current.dx, current.dy);
      case 'C':
        final first = point(), second = point(), end = point();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        cubic = second;
        current = end;
      case 'S':
        final first = (previous == 'C' || previous == 'S') && cubic != null ? current * 2 - cubic : current;
        final second = point(), end = point();
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        cubic = second;
        current = end;
      case 'A':
        final radius = Radius.elliptical(read(), read()), rotation = read();
        final large = read() != 0, clockwise = read() != 0;
        current = point();
        path.arcToPoint(current, radius: radius, rotation: rotation, largeArc: large, clockwise: clockwise);
      case 'Z':
        path.close();
        current = start;
        command = '';
      default:
        throw FormatException('不支持的原图标路径指令：$command', source);
    }
    if (op != 'C' && op != 'S') cubic = null;
    previous = op;
  }
  return path;
}

// 图形来自当前 Web 核心的同名 SVG；只解析这些静态路径。
const _iconMarkup = <String, String>{
  'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  'eye': '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  'eye-off': '<path d="m3 3 18 18M10.6 5.1A11 11 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3 3.9M6.1 6.1A19 19 0 0 0 2 12s3.5 7 10 7a12 12 0 0 0 5.9-1.9M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  'arrow-right': '<path d="M5 12h14m-6-6 6 6-6 6"/>',
  'chevron-right': '<path d="m9 5 7 7-7 7"/>',
  'chevrons-up-down': '<path d="m8 8 4-4 4 4m-8 8 4 4 4-4"/>',
  'check': '<path d="m5 12 4.5 4.5L19 7"/>',
  'bell': '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9ZM10 21h4"/>',
  'cloud':
      '<path d="M7 17a5 5 0 1 1 1.3-9.8A7 7 0 0 1 21 11.5 4 4 0 0 1 19 19H7a4 4 0 0 1 0-8"/><path d="m9 14 3 3 4-5"/>',
  'spark': '<path d="m12 2 2.2 7.8L22 12l-7.8 2.2L12 22l-2.2-7.8L2 12l7.8-2.2z"/>',
  'search': '<circle cx="10.8" cy="10.8" r="7"/><path d="m16 16 5 5"/>',
  'x': '<path d="M6 6 18 18M18 6 6 18"/>',
  'heart': '<path d="M20.8 8.5c0 5-8.8 11-8.8 11s-8.8-6-8.8-11a4.6 4.6 0 0 1 8.8-1.7 4.6 4.6 0 0 1 8.8 1.7Z"/>',
  'share': '<path d="M12 16V3m-5 5 5-5 5 5M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5"/>',
  'add': '<path d="M12 5v14M5 12h14"/>',
  'moon': '<path d="M20 15.5A8.4 8.4 0 0 1 8.5 4 8.5 8.5 0 1 0 20 15.5Z"/>',
  'shield': '<path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/><path d="m9 12 2 2 4-4"/>',
  'wifi': '<path d="M2 8c6-5 14-5 20 0M5 12c4-3 10-3 14 0M9 16a5 5 0 0 1 6 0M12 20h.01"/>',
  'sliders': '<path d="M4 7h9m4 0h3M4 17h3m4 0h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
  'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'briefcase':
      '<rect x="3" y="7" width="18" height="14" rx="3"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 12h18"/>',
  'grid': '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  'home': '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M9 21v-7h6v7"/>',
  'user': '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
  'message': '<path d="M20 16a3 3 0 0 1-3 3H8l-5 3V6a3 3 0 0 1 3-3h11a3 3 0 0 1 3 3Z"/><path d="M8 10h8m-8 4h5"/>',
  'layer': '<path d="m12 3 10 6-10 6L2 9l10-6Zm-9 11 9 5 9-5M3 18l9 5 9-5"/>',
  'inbox': '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="m3 13 5 0 2 3h4l2-3h5"/>',
  'image': '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m3 17 6-6 4 4 3-3 5 5"/>',
  'trash': '<path d="M4 7h16M10 3h4m-8 4 1 14h10l1-14M10 11v6m4-6v6"/>',
  'copy': '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
  'file': '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9zM14 3v6h6M8 13h8m-8 4h5"/>',
  'info': '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>',
  'alert-circle': '<circle cx="12" cy="12" r="9"/><path d="M12 7v6m0 4h.01"/>',
  'alert-triangle': '<path d="m10.3 4.8-8 14A1.5 1.5 0 0 0 3.6 21h16.8a1.5 1.5 0 0 0 1.3-2.2l-8-14a2 2 0 0 0-3.4 0ZM12 9v5m0 3h.01"/>',
};
